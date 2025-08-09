#!/bin/bash

# SSL证书申请修复脚本
# 解决Certbot无法验证域名的问题

echo "🔧 开始修复SSL证书申请问题..."

# 检查是否在正确的目录
if [ ! -f "deploy-https-auto.sh" ]; then
    echo "❌ 错误：请在包含 deploy-https-auto.sh 的目录中运行此脚本"
    exit 1
fi

# 备份原文件
cp deploy-https-auto.sh deploy-https-auto.sh.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ 已备份原文件"

# 创建修复后的脚本
cat > deploy-https-auto.sh << 'EOF'
#!/bin/bash

# Timeline Notebook HTTPS 自动部署脚本
# 支持自动申请和配置 SSL 证书

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

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 用户运行此脚本"
    exit 1
fi

# 获取用户输入
read -p "请输入您的域名: " DOMAIN
read -p "请输入您的邮箱 (用于SSL证书): " EMAIL

# 验证输入
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    log_error "域名和邮箱不能为空"
    exit 1
fi

log_info "域名: $DOMAIN"
log_info "邮箱: $EMAIL"

# 确认继续
read -p "确认以上信息正确吗? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    log_warning "操作已取消"
    exit 0
fi

# 检查域名解析
log_info "检查域名解析..."
if ! nslookup $DOMAIN > /dev/null 2>&1; then
    log_warning "域名解析检查失败，请确保域名已正确解析到此服务器"
    read -p "是否继续? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查必要的端口
log_info "检查端口占用..."
if netstat -tuln | grep -q ":80 "; then
    log_warning "端口 80 已被占用，请先停止占用该端口的服务"
    netstat -tuln | grep ":80 "
fi

if netstat -tuln | grep -q ":443 "; then
    log_warning "端口 443 已被占用，请先停止占用该端口的服务"
    netstat -tuln | grep ":443 "
fi

# 安装必要的软件
log_info "安装必要的软件..."
apt-get update
apt-get install -y docker.io docker-compose-plugin certbot

# 启动 Docker 服务
systemctl start docker
systemctl enable docker

# 创建项目目录
PROJECT_DIR="/opt/timeline-notebook"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 下载项目文件（如果不存在）
if [ ! -d ".git" ]; then
    log_info "下载项目文件..."
    git clone https://github.com/z1159998925/timeline-notebook.git .
fi

# 创建必要的目录
mkdir -p nginx/conf.d
mkdir -p certbot/conf
mkdir -p certbot/www
mkdir -p data/db

# 创建临时的 HTTP-only Nginx 配置（用于证书申请）
log_info "创建临时 HTTP-only Nginx 配置..."
cat > nginx/conf.d/default.conf << NGINX_EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Let's Encrypt 验证路径
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # 其他请求返回简单响应
    location / {
        return 200 'Certificate verification in progress...';
        add_header Content-Type text/plain;
    }
}
NGINX_EOF

# 创建临时的 Docker Compose 配置（HTTP-only）
log_info "创建临时 Docker Compose 配置..."
cat > docker-compose-temp.yml << COMPOSE_EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - certbot-www:/var/www/certbot
    networks:
      - timeline-network

volumes:
  certbot-www:

networks:
  timeline-network:
    driver: bridge
COMPOSE_EOF

# 启动临时 HTTP 服务
log_info "启动临时 HTTP 服务..."
docker compose -f docker-compose-temp.yml up -d

# 等待 Nginx 启动
log_info "等待 Nginx 启动..."
sleep 10

# 检查 Nginx 状态
if ! docker compose -f docker-compose-temp.yml ps | grep -q "Up"; then
    log_error "Nginx 启动失败"
    docker compose -f docker-compose-temp.yml logs
    exit 1
fi

# 测试 HTTP 访问
log_info "测试 HTTP 访问..."
if curl -f http://localhost/ > /dev/null 2>&1; then
    log_success "HTTP 服务正常"
else
    log_warning "HTTP 服务测试失败，但继续尝试申请证书"
fi

# 申请 SSL 证书
log_info "申请 SSL 证书..."
certbot certonly \
    --webroot \
    --webroot-path=/var/lib/docker/volumes/timeline-notebook_certbot-www/_data \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d $DOMAIN

if [ $? -ne 0 ]; then
    log_error "SSL 证书申请失败"
    log_info "请检查："
    log_info "1. 域名是否正确解析到此服务器"
    log_info "2. 防火墙是否开放了 80 和 443 端口"
    log_info "3. 服务器是否可以从外网访问"
    
    # 停止临时服务
    docker compose -f docker-compose-temp.yml down
    exit 1
fi

log_success "SSL 证书申请成功！"

# 停止临时服务
log_info "停止临时服务..."
docker compose -f docker-compose-temp.yml down

# 创建正式的 Nginx 配置
log_info "创建正式的 Nginx 配置..."
cat > nginx/conf.d/default.conf << NGINX_EOF
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name $DOMAIN;

    # Let's Encrypt 验证路径
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # 其他请求重定向到 HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL 证书配置
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 前端静态文件
    location / {
        proxy_pass http://frontend:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API 代理
    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Let's Encrypt 验证路径
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
NGINX_EOF

# 创建正式的 Docker Compose 配置
log_info "创建正式的 Docker Compose 配置..."
cat > docker-compose-https.yml << COMPOSE_EOF
services:
  backend:
    build: ./backend
    environment:
      - DATABASE_URL=sqlite:///app/data/timeline.db
      - CORS_ORIGINS=https://$DOMAIN
    volumes:
      - ./data:/app/data
    networks:
      - timeline-network
    restart: unless-stopped

  frontend:
    build: ./frontend
    environment:
      - REACT_APP_API_URL=https://$DOMAIN/api
    networks:
      - timeline-network
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - /etc/letsencrypt:/etc/letsencrypt
      - certbot-www:/var/www/certbot
    depends_on:
      - backend
      - frontend
    networks:
      - timeline-network
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - certbot-www:/var/www/certbot
    command: certonly --webroot --webroot-path=/var/www/certbot --email $EMAIL --agree-tos --no-eff-email --keep-until-expiring -d $DOMAIN

volumes:
  certbot-www:

networks:
  timeline-network:
    driver: bridge
COMPOSE_EOF

# 启动服务
log_info "启动 HTTPS 服务..."
docker compose -f docker-compose-https.yml up -d --build

# 等待服务启动
log_info "等待服务启动..."
sleep 30

# 检查服务状态
log_info "检查服务状态..."
docker compose -f docker-compose-https.yml ps

# 创建证书自动更新脚本
log_info "创建证书自动更新脚本..."
cat > /etc/cron.d/certbot-renew << CRON_EOF
0 12 * * * root certbot renew --quiet && docker compose -f $PROJECT_DIR/docker-compose-https.yml restart nginx
CRON_EOF

# 配置防火墙
log_info "配置防火墙..."
if command -v ufw > /dev/null; then
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    log_success "防火墙配置完成"
fi

# 清理临时文件
rm -f docker-compose-temp.yml

log_success "🎉 HTTPS 部署完成！"
log_info "您的应用现在可以通过以下地址访问："
log_info "https://$DOMAIN"
log_info ""
log_info "证书将自动更新，无需手动干预。"
log_info ""
log_info "如果遇到问题，请检查："
log_info "1. 域名解析是否正确"
log_info "2. 防火墙设置"
log_info "3. Docker 服务状态: docker compose -f docker-compose-https.yml ps"
log_info "4. 服务日志: docker compose -f docker-compose-https.yml logs"
EOF

chmod +x deploy-https-auto.sh

echo "✅ SSL证书申请修复完成！"
echo ""
echo "主要修复内容："
echo "1. 在证书申请前创建临时的 HTTP-only Nginx 配置"
echo "2. 使用临时 Docker Compose 配置启动 HTTP 服务"
echo "3. 等待服务启动后再申请证书"
echo "4. 证书申请成功后创建正式的 HTTPS 配置"
echo "5. 改进了错误处理和状态检查"
echo ""
echo "现在可以运行修复后的脚本："
echo "sudo ./deploy-https-auto.sh"