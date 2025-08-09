#!/bin/bash

# 修复 deploy-https-auto.sh 中的 YAML 控制字符问题
# 在服务器上运行此脚本来应用修复

echo "🔧 修复 deploy-https-auto.sh 中的 YAML 控制字符问题..."

# 备份原文件
cp deploy-https-auto.sh deploy-https-auto.sh.backup

# 创建修复后的脚本
cat > deploy-https-auto.sh << 'SCRIPT_EOF'
#!/bin/bash

# Timeline Notebook HTTPS自动化部署脚本
# 支持自动申请Let's Encrypt SSL证书

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    print_error "请使用sudo运行此脚本"
    exit 1
fi

# 获取用户输入
read -p "请输入您的域名 (例如: example.com): " DOMAIN
read -p "请输入您的邮箱 (用于SSL证书申请): " EMAIL

# 验证输入
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    print_error "域名和邮箱不能为空"
    exit 1
fi

# 验证邮箱格式
if ! echo "$EMAIL" | grep -E "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$" > /dev/null; then
    print_error "邮箱格式不正确"
    exit 1
fi

print_message "开始HTTPS自动化部署..."
print_message "域名: $DOMAIN"
print_message "邮箱: $EMAIL"

# 设置项目目录
PROJECT_DIR="/opt/timeline-notebook"

# 更新系统和安装依赖
print_message "更新系统并安装依赖..."
apt update
apt install -y docker.io docker-compose git ufw curl

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 切换到项目目录
cd $PROJECT_DIR

# 更新代码
print_message "更新代码..."
git pull origin main

# 停止现有服务
print_message "停止现有服务..."
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose-https.yml down 2>/dev/null || true

# 清理旧的容器和镜像
print_message "清理旧的容器和镜像..."
docker system prune -f

# 创建Nginx HTTPS配置
print_message "生成Nginx HTTPS配置..."
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
    error_log /var/log/nginx/error.log;
    
    # 基本设置
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # 上游后端服务
    upstream backend {
        server timeline-backend:5000;
    }

    # HTTP服务器 - 重定向到HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        
        # Let's Encrypt验证
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
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
        
        # 安全头
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;

        # 前端静态文件
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files \$uri \$uri/ /index.html;
        }

        # API代理到后端
        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # 静态文件服务
        location /static/ {
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # 文件上传大小限制
        client_max_body_size 100M;
    }
}
EOF

# 创建Docker Compose HTTPS配置
print_message "生成Docker Compose HTTPS配置..."
# 先删除可能存在的文件
rm -f docker-compose-https.yml

# 使用 echo 逐行生成配置文件
echo "version: '3.8'" > docker-compose-https.yml
echo "" >> docker-compose-https.yml
echo "services:" >> docker-compose-https.yml
echo "  backend:" >> docker-compose-https.yml
echo "    build:" >> docker-compose-https.yml
echo "      context: ." >> docker-compose-https.yml
echo "      dockerfile: Dockerfile.backend" >> docker-compose-https.yml
echo "    container_name: timeline-backend" >> docker-compose-https.yml
echo "    ports:" >> docker-compose-https.yml
echo "      - \"5000:5000\"" >> docker-compose-https.yml
echo "    volumes:" >> docker-compose-https.yml
echo "      - ./data:/app/data" >> docker-compose-https.yml
echo "      - ./static/uploads:/app/static/uploads" >> docker-compose-https.yml
echo "    environment:" >> docker-compose-https.yml
echo "      - FLASK_ENV=production" >> docker-compose-https.yml
echo "      - DATABASE_URL=sqlite:///data/timeline.db" >> docker-compose-https.yml
echo "      - SECRET_KEY=timeline-production-secret-key-change-this" >> docker-compose-https.yml
echo "      - UPLOAD_FOLDER=/app/static/uploads" >> docker-compose-https.yml
echo "      - MAX_CONTENT_LENGTH=16777216" >> docker-compose-https.yml
echo "      - DOMAIN=${DOMAIN}" >> docker-compose-https.yml
echo "      - EMAIL=${EMAIL}" >> docker-compose-https.yml
echo "      - CORS_ORIGINS=https://${DOMAIN},http://${DOMAIN}" >> docker-compose-https.yml
echo "      - LOG_LEVEL=INFO" >> docker-compose-https.yml
echo "    restart: unless-stopped" >> docker-compose-https.yml
echo "    networks:" >> docker-compose-https.yml
echo "      - timeline-network" >> docker-compose-https.yml
echo "" >> docker-compose-https.yml
echo "  frontend:" >> docker-compose-https.yml
echo "    build:" >> docker-compose-https.yml
echo "      context: ." >> docker-compose-https.yml
echo "      dockerfile: Dockerfile.frontend.server" >> docker-compose-https.yml
echo "    container_name: timeline-frontend" >> docker-compose-https.yml
echo "    ports:" >> docker-compose-https.yml
echo "      - \"80:80\"" >> docker-compose-https.yml
echo "      - \"443:443\"" >> docker-compose-https.yml
echo "    volumes:" >> docker-compose-https.yml
echo "      - ./nginx-https.conf:/etc/nginx/nginx.conf" >> docker-compose-https.yml
echo "      - certbot-certs:/etc/letsencrypt" >> docker-compose-https.yml
echo "      - certbot-www:/var/www/certbot" >> docker-compose-https.yml
echo "    depends_on:" >> docker-compose-https.yml
echo "      - backend" >> docker-compose-https.yml
echo "    restart: unless-stopped" >> docker-compose-https.yml
echo "    networks:" >> docker-compose-https.yml
echo "      - timeline-network" >> docker-compose-https.yml
echo "" >> docker-compose-https.yml
echo "  certbot:" >> docker-compose-https.yml
echo "    image: certbot/certbot" >> docker-compose-https.yml
echo "    container_name: timeline-certbot" >> docker-compose-https.yml
echo "    volumes:" >> docker-compose-https.yml
echo "      - certbot-certs:/etc/letsencrypt" >> docker-compose-https.yml
echo "      - certbot-www:/var/www/certbot" >> docker-compose-https.yml
echo "    command: echo \"Certbot container ready\"" >> docker-compose-https.yml
echo "    restart: \"no\"" >> docker-compose-https.yml
echo "" >> docker-compose-https.yml
echo "networks:" >> docker-compose-https.yml
echo "  timeline-network:" >> docker-compose-https.yml
echo "    driver: bridge" >> docker-compose-https.yml
echo "" >> docker-compose-https.yml
echo "volumes:" >> docker-compose-https.yml
echo "  certbot-certs:" >> docker-compose-https.yml
echo "  certbot-www:" >> docker-compose-https.yml

# 创建环境配置
print_message "配置环境变量..."
cat > .env << EOF
FLASK_ENV=production
DATABASE_URL=sqlite:///data/timeline.db
SECRET_KEY=timeline-production-secret-key-change-this
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=16777216
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}
CORS_ORIGINS=https://${DOMAIN},http://${DOMAIN}
LOG_LEVEL=INFO
EOF

# 创建必要目录
print_message "创建必要目录..."
mkdir -p data static/uploads
chmod 755 data static/uploads

# 启动HTTP服务（用于证书申请）
print_message "启动HTTP服务进行证书申请..."
docker-compose -f docker-compose-https.yml up -d frontend

# 等待nginx启动
sleep 10

# 申请SSL证书
print_message "申请SSL证书..."
docker-compose -f docker-compose-https.yml run --rm certbot \
    certonly --webroot \
    -w /var/www/certbot \
    --email $EMAIL \
    -d $DOMAIN \
    --agree-tos \
    --no-eff-email \
    --force-renewal

# 重启前端服务以加载证书
print_message "重启服务以加载SSL证书..."
docker-compose -f docker-compose-https.yml restart frontend

# 启动完整服务
print_message "启动完整HTTPS服务..."
docker-compose -f docker-compose-https.yml up -d

# 等待服务启动
print_message "等待服务启动..."
sleep 30

# 创建证书自动更新脚本
print_message "设置证书自动更新..."
cat > /etc/cron.d/certbot-renew << EOF
# 每天凌晨2点检查证书更新
0 2 * * * root cd ${PROJECT_DIR} && docker-compose -f docker-compose-https.yml run --rm certbot renew --quiet && docker-compose -f docker-compose-https.yml restart frontend
EOF

# 配置防火墙
print_message "配置防火墙..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 检查服务状态
print_message "检查服务状态..."
docker-compose -f docker-compose-https.yml ps

# 测试HTTPS连接
print_message "测试HTTPS连接..."
sleep 5
if curl -k -s https://$DOMAIN > /dev/null; then
    print_message "✅ HTTPS连接测试成功！"
else
    print_warning "⚠️ HTTPS连接测试失败，请检查域名DNS设置"
fi

echo ""
print_message "🎉 HTTPS自动化部署完成！"
echo ""
echo "📋 部署信息:"
echo "   🌐 网站地址: https://$DOMAIN"
echo "   🔐 SSL证书: 已自动申请并配置"
echo "   🔄 自动更新: 已设置每日检查更新"
echo "   📁 项目目录: $PROJECT_DIR"
echo ""
echo "🔧 管理命令:"
echo "   创建管理员: docker exec -it timeline-backend python create_admin.py"
echo "   查看日志: docker-compose -f docker-compose-https.yml logs"
echo "   重启服务: docker-compose -f docker-compose-https.yml restart"
echo "   停止服务: docker-compose -f docker-compose-https.yml down"
echo ""
echo "📝 注意事项:"
echo "   1. 确保域名 $DOMAIN 已正确解析到此服务器IP"
echo "   2. SSL证书将自动更新，无需手动干预"
echo "   3. 如需修改配置，请编辑 docker-compose-https.yml"
echo ""
SCRIPT_EOF

# 设置执行权限
chmod +x deploy-https-auto.sh

echo "✅ 修复完成！"
echo ""
echo "📋 修复内容："
echo "   1. 使用 echo 逐行生成 Docker Compose 配置文件"
echo "   2. 避免了 here-document 可能导致的控制字符问题"
echo "   3. 统一使用内联方式生成所有配置文件"
echo ""
echo "🚀 现在可以运行修复后的脚本："
echo "   sudo ./deploy-https-auto.sh"