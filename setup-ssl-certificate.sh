#!/bin/bash

# SSL证书申请和HTTPS配置脚本
# 用法: ./setup-ssl-certificate.sh <domain> <email>

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
    log_error "用法: $0 <domain> <email>"
    log_info "示例: $0 xn--cpq55e94lgvdcukyqt.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

log_info "开始为域名 $DOMAIN 申请SSL证书..."

# 检查域名格式
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ ! "$DOMAIN" =~ ^xn--[a-zA-Z0-9.-]+$ ]]; then
    log_warning "域名格式可能不正确: $DOMAIN"
    log_info "如果是中文域名，请确保使用Punycode格式"
fi

# 检查邮箱格式
if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "邮箱格式不正确: $EMAIL"
    exit 1
fi

# 检查当前目录
if [ ! -f "docker-compose-http.yml" ]; then
    log_error "请在项目根目录下运行此脚本"
    exit 1
fi

# 检查服务状态
log_info "检查当前服务状态..."
docker compose ps

# 检查HTTP服务是否可访问
log_info "检查HTTP服务是否可访问..."
if curl -f -s "http://$DOMAIN" > /dev/null; then
    log_success "HTTP服务可访问"
else
    log_warning "HTTP服务可能不可访问，但继续尝试申请证书"
fi

# 创建必要的目录
log_info "创建SSL证书目录..."
sudo mkdir -p /etc/letsencrypt/live/$DOMAIN
sudo mkdir -p /etc/letsencrypt/archive/$DOMAIN
sudo mkdir -p /var/lib/letsencrypt
sudo mkdir -p /var/log/letsencrypt

# 停止可能冲突的服务
log_info "停止可能冲突的服务..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# 使用certbot申请证书
log_info "使用certbot申请SSL证书..."
docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v /var/lib/letsencrypt:/var/lib/letsencrypt \
    -v /var/log/letsencrypt:/var/log/letsencrypt \
    -v "$(pwd)/static/uploads:/var/www/html" \
    -p 80:80 \
    certbot/certbot certonly \
    --standalone \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --domains "$DOMAIN" \
    --non-interactive \
    --verbose

# 检查证书是否申请成功
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    log_success "SSL证书申请成功！"
else
    log_error "SSL证书申请失败"
    log_info "尝试使用webroot方式申请证书..."
    
    # 确保webroot目录存在
    mkdir -p ./static/uploads/.well-known/acme-challenge
    
    # 使用webroot方式申请证书
    docker run --rm \
        -v /etc/letsencrypt:/etc/letsencrypt \
        -v /var/lib/letsencrypt:/var/lib/letsencrypt \
        -v /var/log/letsencrypt:/var/log/letsencrypt \
        -v "$(pwd)/static/uploads:/var/www/html" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/html \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --domains "$DOMAIN" \
        --non-interactive \
        --verbose
    
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        log_success "SSL证书申请成功（webroot方式）！"
    else
        log_error "SSL证书申请失败，请检查域名DNS解析和防火墙设置"
        exit 1
    fi
fi

# 生成HTTPS Docker Compose配置
log_info "生成HTTPS Docker Compose配置..."
cat > docker-compose-https.yml << EOF
version: '3.8'

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
      retries: 3
      start_period: 40s
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
      backend:
        condition: service_healthy
    networks:
      - timeline-network
    restart: unless-stopped

networks:
  timeline-network:
    driver: bridge

volumes:
  certbot-certs:
  certbot-www:
EOF

# 生成HTTPS Nginx配置
log_info "生成HTTPS Nginx配置..."
cat > nginx-https.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # 日志格式
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # 基本设置
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # HTTP重定向到HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        
        # Let's Encrypt验证
        location /.well-known/acme-challenge/ {
            root /var/www/html;
        }
        
        # 其他请求重定向到HTTPS
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }
    
    # HTTPS服务器
    server {
        listen 443 ssl http2;
        server_name $DOMAIN;
        
        # SSL证书配置
        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
        
        # SSL安全配置
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        
        # 根目录
        root /var/www/html;
        index index.html index.htm;
        
        # 静态文件上传
        location /uploads/ {
            alias /var/www/html/uploads/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # API代理
        location /api/ {
            proxy_pass http://timeline-backend:5000/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # 健康检查
        location /health {
            proxy_pass http://timeline-backend:5000/health;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        # 前端路由
        location / {
            try_files \$uri \$uri/ /index.html;
        }
        
        # 安全配置
        location ~ /\. {
            deny all;
        }
    }
}
EOF

# 停止当前服务
log_info "停止当前HTTP服务..."
docker compose -f docker-compose-http.yml down

# 启动HTTPS服务
log_info "启动HTTPS服务..."
docker compose -f docker-compose-https.yml up -d

# 等待服务启动
log_info "等待服务启动..."
sleep 10

# 检查服务状态
log_info "检查服务状态..."
docker compose -f docker-compose-https.yml ps

# 测试HTTPS访问
log_info "测试HTTPS访问..."
if curl -f -s -k "https://$DOMAIN" > /dev/null; then
    log_success "HTTPS服务可访问！"
else
    log_warning "HTTPS服务可能需要更多时间启动"
fi

# 设置证书自动续期
log_info "设置证书自动续期..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/docker run --rm -v /etc/letsencrypt:/etc/letsencrypt -v /var/lib/letsencrypt:/var/lib/letsencrypt certbot/certbot renew --quiet && docker compose -f $(pwd)/docker-compose-https.yml restart frontend") | crontab -

log_success "SSL证书申请和HTTPS配置完成！"
log_info "您现在可以通过以下方式访问网站："
log_info "🌐 HTTPS: https://$DOMAIN"
log_info "🔒 HTTP会自动重定向到HTTPS"
log_info ""
log_info "证书信息："
log_info "📁 证书位置: /etc/letsencrypt/live/$DOMAIN/"
log_info "📅 证书有效期: 90天"
log_info "🔄 自动续期: 已设置每日检查"
log_info ""
log_info "如果遇到问题，请检查："
log_info "1. 域名DNS解析是否正确指向服务器IP"
log_info "2. 防火墙是否开放80和443端口"
log_info "3. 服务器时间是否正确"