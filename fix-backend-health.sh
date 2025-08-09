#!/bin/bash

# 修复后端容器健康检查和启动问题
# 用法: ./fix-backend-health.sh <域名> <邮箱>

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查参数
if [ $# -ne 2 ]; then
    log_error "用法: $0 <域名> <邮箱>"
    log_info "示例: $0 xn--cpq55e94lgvdcukyqt.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

log_info "诊断并修复后端容器健康检查问题..."

# 停止当前服务
log_info "停止当前服务..."
docker compose -f docker-compose-https.yml down 2>/dev/null || true

# 检查后端容器日志
log_info "检查后端容器日志..."
if docker ps -a | grep -q timeline-backend; then
    log_info "后端容器日志："
    docker logs timeline-backend 2>/dev/null || log_warning "无法获取后端容器日志"
fi

# 创建必要的目录
log_info "创建必要的目录..."
mkdir -p ./data
mkdir -p ./static/uploads
chmod 755 ./data
chmod 755 ./static/uploads

# 检查后端依赖文件
log_info "检查后端依赖文件..."
if [ ! -f "backend/requirements.txt" ]; then
    log_error "backend/requirements.txt 文件不存在"
    exit 1
fi

if [ ! -f "backend/app.py" ]; then
    log_error "backend/app.py 文件不存在"
    exit 1
fi

# 生成优化的HTTPS Docker Compose配置（移除健康检查依赖）
log_info "生成优化的HTTPS Docker Compose配置..."
cat > docker-compose-https.yml << EOF
services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    container_name: timeline-backend
    environment:
      - FLASK_ENV=production
      - DATABASE_URL=sqlite:///data/timeline.db
      - DOMAIN=$DOMAIN
      - EMAIL=$EMAIL
    volumes:
      - ./data:/app/data
      - ./static/uploads:/app/static/uploads
    networks:
      - timeline-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: unless-stopped

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend.server
    container_name: timeline-frontend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-https.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - ./static/uploads:/var/www/html/uploads:ro
    depends_on:
      - backend
    networks:
      - timeline-network
    restart: unless-stopped

networks:
  timeline-network:
    driver: bridge
EOF

# 检查Dockerfile.backend是否存在
log_info "检查Dockerfile.backend..."
if [ ! -f "Dockerfile.backend" ]; then
    log_warning "Dockerfile.backend 不存在，创建基础版本..."
    cat > Dockerfile.backend << EOF
FROM python:3.9-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# 复制后端代码
COPY backend/ .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 创建数据目录
RUN mkdir -p /app/data /app/static/uploads

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \\
    CMD curl -f http://localhost:5000/health || exit 1

# 启动应用
CMD ["python", "app.py"]
EOF
fi

# 检查Dockerfile.frontend.server是否存在
log_info "检查Dockerfile.frontend.server..."
if [ ! -f "Dockerfile.frontend.server" ]; then
    log_warning "Dockerfile.frontend.server 不存在，创建基础版本..."
    cat > Dockerfile.frontend.server << EOF
# 构建阶段
FROM node:18-alpine as build-stage

WORKDIR /app

# 复制前端代码
COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ .
RUN npm run build

# 生产阶段
FROM nginx:alpine

# 复制构建结果
COPY --from=build-stage /app/dist /var/www/html

# 暴露端口
EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
EOF
fi

# 先单独启动后端容器进行测试
log_info "先单独启动后端容器进行测试..."
docker compose -f docker-compose-https.yml up -d backend

# 等待后端启动
log_info "等待后端容器启动..."
sleep 30

# 检查后端容器状态
log_info "检查后端容器状态..."
if docker ps | grep -q timeline-backend; then
    log_success "后端容器正在运行"
    
    # 检查后端健康状态
    log_info "检查后端健康状态..."
    for i in {1..10}; do
        if docker exec timeline-backend curl -f http://localhost:5000/health 2>/dev/null; then
            log_success "后端健康检查通过"
            break
        else
            log_warning "后端健康检查失败，等待重试... ($i/10)"
            sleep 10
        fi
        
        if [ $i -eq 10 ]; then
            log_error "后端健康检查持续失败"
            log_info "后端容器日志："
            docker logs timeline-backend
            exit 1
        fi
    done
    
    # 启动前端容器
    log_info "启动前端容器..."
    docker compose -f docker-compose-https.yml up -d frontend
    
    # 等待前端启动
    log_info "等待前端容器启动..."
    sleep 20
    
    # 检查所有服务状态
    log_info "检查所有服务状态..."
    docker compose -f docker-compose-https.yml ps
    
    # 测试HTTPS访问
    log_info "测试HTTPS访问..."
    if curl -f -s -k "https://$DOMAIN" > /dev/null; then
        log_success "HTTPS服务可访问！"
    else
        log_warning "HTTPS服务可能需要更多时间启动"
        log_info "检查前端容器日志："
        docker logs timeline-frontend
    fi
    
    # 测试API访问
    log_info "测试API访问..."
    if curl -f -s -k "https://$DOMAIN/api/health" > /dev/null; then
        log_success "API服务可访问！"
    else
        log_warning "API服务可能需要更多时间启动"
    fi
    
    log_success "服务启动完成！"
    log_info "您现在可以通过以下方式访问网站："
    log_info "🌐 HTTPS: https://$DOMAIN"
    log_info "🔗 API: https://$DOMAIN/api/"
    log_info ""
    log_info "如果仍有问题，请检查："
    log_info "1. 后端日志: docker logs timeline-backend"
    log_info "2. 前端日志: docker logs timeline-frontend"
    log_info "3. 网络连接: docker network ls"
    
else
    log_error "后端容器启动失败"
    log_info "后端容器日志："
    docker logs timeline-backend 2>/dev/null || log_error "无法获取后端容器日志"
    
    log_info "尝试手动构建后端镜像..."
    docker build -f Dockerfile.backend -t timeline-backend .
    
    log_info "尝试直接运行后端容器..."
    docker run -d --name timeline-backend-test \
        -e FLASK_ENV=production \
        -e DATABASE_URL=sqlite:///data/timeline.db \
        -v "$(pwd)/data:/app/data" \
        -v "$(pwd)/static/uploads:/app/static/uploads" \
        -p 5000:5000 \
        timeline-backend
    
    sleep 10
    log_info "测试后端容器日志："
    docker logs timeline-backend-test
    
    # 清理测试容器
    docker stop timeline-backend-test 2>/dev/null || true
    docker rm timeline-backend-test 2>/dev/null || true
    
    exit 1
fi