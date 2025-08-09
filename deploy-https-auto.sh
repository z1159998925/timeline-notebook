#!/bin/bash

# HTTPS自动化部署脚本
# 功能：自动申请SSL证书、配置HTTPS、设置自动更新

set -e

echo "🚀 Timeline Notebook HTTPS自动化部署开始..."

# 配置变量
DOMAIN=""
EMAIL=""
PROJECT_DIR="/opt/timeline-notebook"

# 获取用户输入
read -p "请输入您的域名 (例如: example.com): " DOMAIN
read -p "请输入您的邮箱 (用于Let's Encrypt通知): " EMAIL

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "❌ 域名和邮箱不能为空！"
    exit 1
fi

echo "📋 配置信息:"
echo "   域名: $DOMAIN"
echo "   邮箱: $EMAIL"
echo "   部署目录: $PROJECT_DIR"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用root权限运行此脚本"
    exit 1
fi

# 更新系统
echo "📦 更新系统包..."
apt-get update

# 安装必要工具
echo "🔧 安装基础工具..."
apt-get install -y curl git wget unzip

# 检查并安装Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 安装Docker (使用官方稳定源)..."
    
    # 卸载可能存在的旧版本
    for pkg in docker.io docker-doc docker-compose containerd runc; do apt-get remove -y $pkg; done
    
    # 设置Docker的apt仓库
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
      
    apt-get update
    
    # 安装Docker引擎
    echo "📦 正在安装 Docker 引擎..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl start docker
    systemctl enable docker
fi

# 检查并安装Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 安装Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 验证Docker安装
echo "✅ 验证Docker安装..."
docker --version
docker-compose --version

# 创建项目目录
echo "📁 准备部署目录..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 克隆或更新代码
if [ -d ".git" ]; then
    echo "🔄 更新现有代码..."
    git pull origin main
else
    echo "📥 克隆代码仓库..."
    git clone https://github.com/z1159998925/timeline-notebook.git .
fi

# 停止现有服务
echo "🛑 停止现有服务..."
docker-compose -f docker-compose-server.yml down 2>/dev/null || true
docker-compose -f docker-compose-https.yml down 2>/dev/null || true

# 创建HTTPS配置文件
echo "⚙️ 创建HTTPS配置..."

# 创建Nginx HTTPS配置
echo "⚙️ 生成Nginx HTTPS配置..."
# 强制使用内联生成，避免模板文件的控制字符问题
cat > nginx-https.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    # 上游后端服务
    upstream backend {
        server timeline-backend:5000;
    }

    # HTTP服务器 - 重定向到HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        
        # Let's Encrypt验证路径
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
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
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
echo "⚙️ 生成Docker Compose HTTPS配置..."
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
echo "📝 配置环境变量..."
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
echo "📁 创建必要目录..."
mkdir -p data static/uploads
chmod 755 data static/uploads

# 创建临时HTTP-only Nginx配置（用于证书申请）
echo "🌐 创建临时HTTP配置进行证书申请..."
cat > nginx-http-temp.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;

    # HTTP服务器 - 仅用于证书申请
    server {
        listen 80;
        server_name _;
        
        # Let's Encrypt验证路径
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }
        
        # 健康检查
        location /health {
            return 200 'OK';
            add_header Content-Type text/plain;
        }
        
        # 其他请求返回简单页面
        location / {
            return 200 'Certificate verification in progress...';
            add_header Content-Type text/plain;
        }
    }
}
EOF

# 临时修改 docker-compose 配置使用 HTTP-only 配置
sed -i 's|./nginx-https.conf:/etc/nginx/nginx.conf|./nginx-http-temp.conf:/etc/nginx/nginx.conf|' docker-compose-https.yml

# 启动HTTP服务（用于证书申请）
echo "🌐 启动HTTP服务进行证书申请..."
docker-compose -f docker-compose-https.yml up -d frontend

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 20

# 检查服务状态
echo "🔍 检查服务状态..."
docker-compose -f docker-compose-https.yml ps
docker-compose -f docker-compose-https.yml logs frontend

# 测试HTTP访问
echo "🧪 测试HTTP访问..."
curl -I http://localhost/.well-known/acme-challenge/test || echo "HTTP测试失败"

# 申请SSL证书
echo "🔐 申请SSL证书..."
docker-compose -f docker-compose-https.yml run --rm certbot \
    certonly --webroot \
    -w /var/www/certbot \
    --email $EMAIL \
    -d $DOMAIN \
    --agree-tos \
    --no-eff-email \
    --force-renewal

# 恢复 HTTPS 配置
echo "🔄 恢复HTTPS配置..."
sed -i 's|./nginx-http-temp.conf:/etc/nginx/nginx.conf|./nginx-https.conf:/etc/nginx/nginx.conf|' docker-compose-https.yml

# 重启前端服务以加载证书
echo "🔄 重启服务以加载SSL证书..."
docker-compose -f docker-compose-https.yml restart frontend

# 启动完整服务
echo "🚀 启动完整HTTPS服务..."
docker-compose -f docker-compose-https.yml up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 创建证书自动更新脚本
echo "🔄 设置证书自动更新..."
cat > /etc/cron.d/certbot-renew << EOF
# 每天凌晨2点检查证书更新
0 2 * * * root cd ${PROJECT_DIR} && docker-compose -f docker-compose-https.yml run --rm certbot renew --quiet && docker-compose -f docker-compose-https.yml restart frontend
EOF

# 配置防火墙
echo "🔥 配置防火墙..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose -f docker-compose-https.yml ps

# 测试HTTPS连接
echo "🧪 测试HTTPS连接..."
sleep 5
if curl -k -s https://$DOMAIN > /dev/null; then
    echo "✅ HTTPS连接测试成功！"
else
    echo "⚠️ HTTPS连接测试失败，请检查域名DNS设置"
fi

echo ""
echo "🎉 HTTPS自动化部署完成！"
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