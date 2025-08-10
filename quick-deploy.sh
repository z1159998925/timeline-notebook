#!/bin/bash

# 🚀 Timeline Notebook 快速部署脚本
# 适用于 Ubuntu/Debian 系统

set -e

echo "🚀 Timeline Notebook 快速部署开始..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本"
        exit 1
    fi
}

# 检查系统
check_system() {
    log_info "检查系统环境..."
    
    if ! command -v curl &> /dev/null; then
        log_info "安装 curl..."
        sudo apt update
        sudo apt install -y curl
    fi
    
    if ! command -v git &> /dev/null; then
        log_info "安装 git..."
        sudo apt install -y git
    fi
    
    log_success "系统环境检查完成"
}

# 安装 Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker 已安装"
        return
    fi
    
    log_info "安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    
    log_success "Docker 安装完成"
}

# 安装 Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose 已安装"
        return
    fi
    
    log_info "安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose 安装完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow 22/tcp
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        echo "y" | sudo ufw enable
        log_success "UFW 防火墙配置完成"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
        log_success "Firewalld 防火墙配置完成"
    else
        log_warning "未检测到防火墙，请手动配置开放 80 和 443 端口"
    fi
}

# 获取用户输入
get_user_input() {
    echo ""
    echo "📝 请提供以下信息:"
    
    # 域名
    while true; do
        read -p "🌐 请输入你的域名 (例: example.com): " DOMAIN
        if [[ -n "$DOMAIN" ]]; then
            break
        fi
        log_error "域名不能为空"
    done
    
    # 邮箱
    while true; do
        read -p "📧 请输入邮箱地址 (用于SSL证书): " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        fi
        log_error "请输入有效的邮箱地址"
    done
    
    # SSL选择
    echo ""
    echo "🔒 SSL证书选项:"
    echo "1) Let's Encrypt (免费，推荐用于生产环境)"
    echo "2) 自签名证书 (仅用于测试)"
    echo "3) 跳过SSL配置"
    
    while true; do
        read -p "请选择 SSL 选项 (1-3): " SSL_OPTION
        case $SSL_OPTION in
            1|2|3) break ;;
            *) log_error "请输入 1、2 或 3" ;;
        esac
    done
}

# 生成配置文件
generate_config() {
    log_info "生成配置文件..."
    
    # 生成安全密钥
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)
    
    # 创建 .env.production
    cat > .env.production << EOF
# Flask配置
FLASK_ENV=production
SECRET_KEY=$SECRET_KEY
DATABASE_URL=sqlite:///data/timeline.db

# 文件上传配置
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=104857600

# 域名和CORS配置
DOMAIN=$DOMAIN
CORS_ORIGINS=https://$DOMAIN,http://$DOMAIN

# 日志配置
LOG_LEVEL=INFO

# Session配置
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_SAMESITE=Lax
EOF
    
    log_success "配置文件生成完成"
}

# 构建和启动服务
deploy_application() {
    log_info "构建和启动应用..."
    
    # 构建镜像
    docker-compose build
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "应用启动成功"
    else
        log_error "应用启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 配置SSL
setup_ssl() {
    case $SSL_OPTION in
        1)
            log_info "配置 Let's Encrypt SSL..."
            
            # 安装 Certbot
            sudo apt update
            sudo apt install -y certbot python3-certbot-nginx
            
            # 停止nginx容器以释放80端口
            docker-compose stop nginx
            
            # 申请证书
            sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
            
            # 重启nginx
            docker-compose start nginx
            
            # 设置自动续期
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            
            log_success "Let's Encrypt SSL 配置完成"
            ;;
        2)
            log_info "生成自签名证书..."
            ./generate-ssl.sh
            log_success "自签名证书生成完成"
            ;;
        3)
            log_warning "跳过SSL配置"
            ;;
    esac
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查HTTP
    if curl -s http://localhost/health > /dev/null; then
        log_success "HTTP 健康检查通过"
    else
        log_error "HTTP 健康检查失败"
    fi
    
    # 检查API
    if curl -s http://localhost/api/health > /dev/null; then
        log_success "API 健康检查通过"
    else
        log_error "API 健康检查失败"
    fi
    
    # 显示容器状态
    echo ""
    log_info "容器状态:"
    docker-compose ps
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 创建备份脚本
    cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/timeline-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

echo "📦 开始备份..."

# 备份数据库
docker-compose exec -T backend sqlite3 /app/data/timeline.db ".backup /app/data/backup.db"
docker cp timeline-backend:/app/data/backup.db $BACKUP_DIR/

# 备份上传文件
docker cp timeline-backend:/app/static/uploads $BACKUP_DIR/

# 备份配置文件
cp .env.production $BACKUP_DIR/
cp docker-compose.yml $BACKUP_DIR/

echo "✅ 备份完成: $BACKUP_DIR"
EOF
    
    # 创建更新脚本
    cat > update.sh << 'EOF'
#!/bin/bash
echo "🔄 更新 Timeline Notebook..."

# 备份当前版本
./backup.sh

# 拉取最新代码
git pull origin main

# 重新构建和部署
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "✅ 更新完成"
EOF
    
    # 设置执行权限
    chmod +x backup.sh update.sh
    
    log_success "管理脚本创建完成"
}

# 显示部署结果
show_result() {
    echo ""
    echo "🎉 部署完成！"
    echo ""
    echo "📊 部署信息:"
    echo "  域名: $DOMAIN"
    echo "  HTTP: http://$DOMAIN"
    if [[ $SSL_OPTION -eq 1 ]]; then
        echo "  HTTPS: https://$DOMAIN"
    fi
    echo ""
    echo "🔧 管理命令:"
    echo "  查看日志: docker-compose logs"
    echo "  重启服务: docker-compose restart"
    echo "  停止服务: docker-compose down"
    echo "  备份数据: ./backup.sh"
    echo "  更新应用: ./update.sh"
    echo ""
    echo "📁 重要文件:"
    echo "  配置文件: .env.production"
    echo "  部署指南: SERVER-DEPLOYMENT-GUIDE.md"
    echo ""
    
    if [[ $SSL_OPTION -eq 2 ]]; then
        log_warning "使用的是自签名证书，浏览器会显示安全警告"
    fi
    
    log_success "Timeline Notebook 部署成功！"
}

# 主函数
main() {
    echo "🚀 Timeline Notebook 快速部署脚本"
    echo "=================================="
    
    check_root
    check_system
    install_docker
    install_docker_compose
    setup_firewall
    get_user_input
    generate_config
    deploy_application
    setup_ssl
    health_check
    create_management_scripts
    show_result
    
    echo ""
    log_info "如需重新登录以应用Docker用户组更改，请执行: newgrp docker"
}

# 运行主函数
main "$@"