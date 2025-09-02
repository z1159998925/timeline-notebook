#!/bin/bash

# 时光轴笔记项目 - 服务器部署脚本
# 自动化Docker容器部署流程

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="timeline-notebook"
DOCKER_COMPOSE_FILE="docker-compose.yml"
HTTP_COMPOSE_FILE="docker-compose-http.yml"
ENV_FILE=".env.production"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "================================================"
    echo "    时光轴笔记项目 - 服务器部署脚本"
    echo "================================================"
    echo -e "${NC}"
}

# 检查系统要求
check_requirements() {
    log_step "检查系统要求..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        echo "安装命令：curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    # 检查权限
    if ! docker ps &> /dev/null; then
        log_error "当前用户无Docker权限，请将用户添加到docker组或使用sudo运行"
        echo "添加用户到docker组：sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    log_info "系统要求检查通过"
}

# 创建必要目录
create_directories() {
    log_step "创建必要目录..."
    
    # 创建数据目录
    mkdir -p data/uploads
    mkdir -p data/logs
    mkdir -p data/db
    
    # 设置权限
    chmod 755 data
    chmod 777 data/uploads
    chmod 755 data/logs
    chmod 755 data/db
    
    log_info "目录创建完成"
}

# 配置环境变量
setup_environment() {
    log_step "配置环境变量..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warn "环境配置文件不存在，创建默认配置..."
        
        # 生成随机密钥
        SECRET_KEY=$(openssl rand -hex 32)
        
        cat > "$ENV_FILE" << EOF
# 生产环境配置
FLASK_ENV=production
SECRET_KEY=$SECRET_KEY
DATABASE_URL=sqlite:///data/timeline.db
UPLOAD_FOLDER=/app/data/uploads
MAX_CONTENT_LENGTH=104857600
DOMAIN=localhost
CORS_ORIGINS=https://localhost,http://localhost
LOG_LEVEL=INFO

# 会话配置
SESSION_COOKIE_SECURE=True
SESSION_COOKIE_HTTPONLY=True
SESSION_COOKIE_SAMESITE=Lax
EOF
        log_info "默认环境配置已创建，请根据需要修改 $ENV_FILE"
    else
        log_info "环境配置文件已存在"
    fi
}

# 选择部署模式
select_deployment_mode() {
    echo
    echo "请选择部署模式："
    echo "1. HTTPS模式（推荐，需要SSL证书）"
    echo "2. HTTP模式（测试用）"
    echo
    
    while true; do
        read -p "请输入选择 (1/2): " mode
        case $mode in
            1)
                DEPLOYMENT_MODE="https"
                COMPOSE_FILE="$DOCKER_COMPOSE_FILE"
                break
                ;;
            2)
                DEPLOYMENT_MODE="http"
                COMPOSE_FILE="$HTTP_COMPOSE_FILE"
                break
                ;;
            *)
                log_error "无效选择，请输入1或2"
                ;;
        esac
    done
    
    log_info "选择了 $DEPLOYMENT_MODE 部署模式"
}

# 检查SSL证书（HTTPS模式）
check_ssl_certificates() {
    if [[ "$DEPLOYMENT_MODE" == "https" ]]; then
        log_step "检查SSL证书..."
        
        if [[ ! -f "/etc/nginx/ssl/fullchain.pem" ]] || [[ ! -f "/etc/nginx/ssl/privkey.pem" ]]; then
            log_warn "SSL证书不存在"
            echo "请先配置SSL证书："
            echo "1. 运行 ./ssl-setup.sh 自动配置"
            echo "2. 手动配置证书到 /etc/nginx/ssl/ 目录"
            echo "3. 查看 SSL-CERTIFICATE-GUIDE.md 获取详细说明"
            echo
            
            read -p "是否继续部署？(y/N): " continue_deploy
            if [[ ! "$continue_deploy" =~ ^[Yy]$ ]]; then
                log_info "部署已取消"
                exit 0
            fi
        else
            log_info "SSL证书检查通过"
        fi
    fi
}

# 构建镜像
build_images() {
    log_step "构建Docker镜像..."
    
    # 构建后端镜像
    log_info "构建后端镜像..."
    docker build -f Dockerfile.backend -t timeline-backend:latest .
    
    # 构建前端镜像
    log_info "构建前端镜像..."
    if [[ "$DEPLOYMENT_MODE" == "https" ]]; then
        docker build -f Dockerfile.frontend.production -t timeline-frontend:latest .
    else
        docker build -f Dockerfile.frontend.server -t timeline-frontend:latest .
    fi
    
    log_info "镜像构建完成"
}

# 启动服务
start_services() {
    log_step "启动服务..."
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # 启动新服务
    log_info "启动新服务..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    log_info "检查服务状态..."
    docker-compose -f "$COMPOSE_FILE" ps
}

# 验证部署
verify_deployment() {
    log_step "验证部署..."
    
    # 检查容器状态
    local failed_services=$(docker-compose -f "$COMPOSE_FILE" ps --services --filter "status=exited")
    
    if [[ -n "$failed_services" ]]; then
        log_error "以下服务启动失败：$failed_services"
        log_info "查看日志：docker-compose -f $COMPOSE_FILE logs"
        return 1
    fi
    
    # 测试健康检查
    log_info "测试服务健康状态..."
    
    if [[ "$DEPLOYMENT_MODE" == "https" ]]; then
        local health_url="https://localhost/health"
    else
        local health_url="http://localhost/health"
    fi
    
    # 等待服务完全启动
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -k -s "$health_url" > /dev/null 2>&1; then
            log_info "健康检查通过"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_warn "健康检查超时，但服务可能仍在启动中"
            break
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    echo
    log_info "部署验证完成"
}

# 显示部署信息
show_deployment_info() {
    log_step "部署信息"
    
    echo
    echo "=== 部署完成 ==="
    echo "部署模式：$DEPLOYMENT_MODE"
    echo "配置文件：$COMPOSE_FILE"
    echo
    
    if [[ "$DEPLOYMENT_MODE" == "https" ]]; then
        echo "访问地址：https://your-domain.com"
        echo "健康检查：https://your-domain.com/health"
    else
        echo "访问地址：http://your-server-ip"
        echo "健康检查：http://your-server-ip/health"
    fi
    
    echo
    echo "=== 常用命令 ==="
    echo "查看服务状态：docker-compose -f $COMPOSE_FILE ps"
    echo "查看日志：docker-compose -f $COMPOSE_FILE logs"
    echo "重启服务：docker-compose -f $COMPOSE_FILE restart"
    echo "停止服务：docker-compose -f $COMPOSE_FILE down"
    echo "更新服务：./deploy.sh"
    echo
    
    echo "=== 文档参考 ==="
    echo "服务器部署指南：SERVER-DEPLOYMENT-GUIDE.md"
    echo "SSL证书配置：SSL-CERTIFICATE-GUIDE.md"
    echo
}

# 清理函数
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "部署过程中发生错误"
        log_info "查看错误日志：docker-compose -f $COMPOSE_FILE logs"
    fi
}

# 主函数
main() {
    # 设置错误处理
    trap cleanup EXIT
    
    show_banner
    
    # 检查参数
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "用法：$0 [选项]"
        echo "选项："
        echo "  --help, -h     显示帮助信息"
        echo "  --http         强制使用HTTP模式"
        echo "  --https        强制使用HTTPS模式"
        echo "  --build-only   仅构建镜像，不启动服务"
        echo "  --no-build     跳过镜像构建，直接启动服务"
        exit 0
    fi
    
    # 解析参数
    BUILD_IMAGES=true
    START_SERVICES=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --http)
                DEPLOYMENT_MODE="http"
                COMPOSE_FILE="$HTTP_COMPOSE_FILE"
                shift
                ;;
            --https)
                DEPLOYMENT_MODE="https"
                COMPOSE_FILE="$DOCKER_COMPOSE_FILE"
                shift
                ;;
            --build-only)
                START_SERVICES=false
                shift
                ;;
            --no-build)
                BUILD_IMAGES=false
                shift
                ;;
            *)
                log_error "未知参数：$1"
                exit 1
                ;;
        esac
    done
    
    # 执行部署步骤
    check_requirements
    create_directories
    setup_environment
    
    # 如果没有指定模式，让用户选择
    if [[ -z "$DEPLOYMENT_MODE" ]]; then
        select_deployment_mode
    fi
    
    check_ssl_certificates
    
    if [[ "$BUILD_IMAGES" == "true" ]]; then
        build_images
    fi
    
    if [[ "$START_SERVICES" == "true" ]]; then
        start_services
        verify_deployment
        show_deployment_info
    fi
    
    log_info "部署脚本执行完成！"
}

# 运行主函数
main "$@"