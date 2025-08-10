#!/bin/bash

# 简化部署脚本 - 避免 Docker bake 问题

set -e

echo "🚀 开始简化部署..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理环境
log_info "清理 Docker 环境..."
docker-compose down 2>/dev/null || true
docker system prune -f
docker builder prune -f

# 分步构建镜像
log_info "构建后端镜像..."
docker build -f Dockerfile.backend -t timeline-notebook-backend:latest . || {
    log_error "后端镜像构建失败"
    exit 1
}

log_info "构建前端镜像..."
docker build -f Dockerfile.frontend.production -t timeline-notebook-frontend:latest . || {
    log_error "前端镜像构建失败"
    exit 1
}

log_success "镜像构建完成"

# 启动服务
log_info "启动服务..."
docker-compose up -d || {
    log_error "服务启动失败"
    docker-compose logs
    exit 1
}

# 等待服务启动
log_info "等待服务启动..."
sleep 30

# 检查服务状态
log_info "检查服务状态..."
docker-compose ps

# 健康检查
log_info "执行健康检查..."
if curl -s http://localhost/health > /dev/null 2>&1; then
    log_success "健康检查通过"
else
    log_error "健康检查失败，查看日志："
    docker-compose logs --tail=50
fi

log_success "部署完成！"
echo ""
echo "🔧 管理命令:"
echo "  查看日志: docker-compose logs"
echo "  查看状态: docker-compose ps"
echo "  重启服务: docker-compose restart"
echo "  停止服务: docker-compose down"