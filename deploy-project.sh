#!/bin/bash

# Timeline Notebook 项目部署脚本
# 在已配置好环境的服务器上运行

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Timeline Notebook 项目部署${NC}"
echo "============================================="

# 检查参数
if [ $# -eq 2 ]; then
    DOMAIN="$1"
    EMAIL="$2"
    echo -e "${GREEN}✅ 使用命令行参数: 域名=$DOMAIN, 邮箱=$EMAIL${NC}"
elif [ -n "$DOMAIN" ] && [ -n "$EMAIL" ]; then
    echo -e "${GREEN}✅ 使用环境变量: 域名=$DOMAIN, 邮箱=$EMAIL${NC}"
else
    echo -e "${YELLOW}📝 请输入部署信息:${NC}"
    read -p "请输入域名 (例如: example.com): " DOMAIN
    read -p "请输入邮箱 (用于SSL证书): " EMAIL
fi

# 验证输入
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ 域名和邮箱不能为空${NC}"
    exit 1
fi

# 验证邮箱格式
if ! echo "$EMAIL" | grep -E "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$" > /dev/null; then
    echo -e "${RED}❌ 邮箱格式不正确${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 部署配置:${NC}"
echo "  域名: $DOMAIN"
echo "  邮箱: $EMAIL"
echo "  项目目录: /opt/timeline-notebook"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ 请使用sudo运行此脚本${NC}"
    exit 1
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装，请先运行 setup-server-environment.sh${NC}"
    exit 1
fi

# 进入项目目录
cd /opt/timeline-notebook

# 停止现有服务
echo -e "${YELLOW}🛑 停止现有服务...${NC}"
docker compose down --remove-orphans 2>/dev/null || true
docker system prune -f

# 设置环境变量
export DOMAIN="$DOMAIN"
export EMAIL="$EMAIL"

# 生成Docker Compose配置文件
echo -e "${YELLOW}📝 生成Docker Compose配置...${NC}"
cat > docker-compose-https.yml << EOF
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    container_name: timeline-backend
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
      - ./static/uploads:/app/static/uploads
    environment:
      - FLASK_ENV=production
      - DATABASE_URL=sqlite:///data/timeline.db
      - SECRET_KEY=timeline-production-secret-key-change-this
      - UPLOAD_FOLDER=/app/static/uploads
      - MAX_CONTENT_LENGTH=16777216
      - DOMAIN=${DOMAIN}
      - EMAIL=${EMAIL}
      - CORS_ORIGINS=https://${DOMAIN},http://${DOMAIN}
      - LOG_LEVEL=INFO
    restart: unless-stopped
    networks:
      - timeline-network

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend.server
    container_name: timeline-frontend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - certbot-certs:/etc/letsencrypt
      - certbot-www:/var/www/certbot
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - timeline-network

  certbot:
    image: certbot/certbot
    container_name: timeline-certbot
    volumes:
      - certbot-certs:/etc/letsencrypt
      - certbot-www:/var/www/certbot
    command: echo "Certbot container ready"
    restart: "no"

networks:
  timeline-network:
    driver: bridge

volumes:
  certbot-certs:
  certbot-www:
EOF

# 生成临时HTTP Nginx配置
echo -e "${YELLOW}📝 生成临时HTTP配置...${NC}"
cat > nginx-http-temp.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile        on;
    keepalive_timeout  65;
    
    # 临时HTTP服务器，用于SSL证书申请
    server {
        listen 80;
        server_name ${DOMAIN};
        
        # Let's Encrypt验证路径
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # 临时显示维护页面
        location / {
            return 200 'Timeline Notebook is being deployed...';
            add_header Content-Type text/plain;
        }
    }
}
EOF

# 生成HTTPS Nginx配置
echo -e "${YELLOW}📝 生成HTTPS配置...${NC}"
cat > nginx-https.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile        on;
    keepalive_timeout  65;
    client_max_body_size 16M;
    
    # HTTP重定向到HTTPS
    server {
        listen 80;
        server_name ${DOMAIN};
        
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
        server_name ${DOMAIN};
        
        # SSL证书配置
        ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
        
        # SSL安全配置
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        
        # 安全头
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        
        # 静态文件
        location / {
            root /usr/share/nginx/html;
            try_files \$uri \$uri/ /index.html;
            
            # 缓存静态资源
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }
        }
        
        # API代理
        location /api/ {
            proxy_pass http://timeline-backend:5000/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Let's Encrypt验证路径
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }
}
EOF

# 验证YAML格式
echo -e "${YELLOW}🔍 验证配置文件格式...${NC}"
if command -v python3 &> /dev/null; then
    python3 -c "
import yaml
import sys
try:
    with open('docker-compose-https.yml', 'r') as f:
        yaml.safe_load(f)
    print('✅ YAML格式验证通过')
except Exception as e:
    print(f'❌ YAML格式错误: {e}')
    sys.exit(1)
"
fi

# 检查文件编码
echo -e "${YELLOW}🔍 检查文件编码...${NC}"
for file in docker-compose-https.yml nginx-http-temp.conf nginx-https.conf; do
    if file "$file" | grep -q "UTF-8"; then
        echo "✅ $file: UTF-8编码"
    else
        echo "⚠️ $file: $(file "$file")"
    fi
done

# 启动临时HTTP服务申请SSL证书
echo -e "${YELLOW}🔧 启动临时HTTP服务...${NC}"
cp nginx-http-temp.conf nginx-domain.conf

# 构建并启动服务
echo -e "${YELLOW}🏗️ 构建并启动服务...${NC}"
docker compose -f docker-compose-https.yml build
docker compose -f docker-compose-https.yml up -d

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 10

# 检查服务状态
echo -e "${BLUE}📊 检查服务状态...${NC}"
docker compose -f docker-compose-https.yml ps

# 申请SSL证书
echo -e "${YELLOW}🔐 申请SSL证书...${NC}"
docker compose -f docker-compose-https.yml exec -T certbot certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL证书申请成功${NC}"
    
    # 切换到HTTPS配置
    echo -e "${YELLOW}🔄 切换到HTTPS配置...${NC}"
    cp nginx-https.conf nginx-domain.conf
    
    # 重启前端服务以加载新配置
    docker compose -f docker-compose-https.yml restart frontend
    
    # 等待服务重启
    sleep 5
    
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 部署信息:${NC}"
    echo "  🌐 网站地址: https://$DOMAIN"
    echo "  🔐 SSL证书: 已配置"
    echo "  🐳 Docker服务: 运行中"
    echo ""
    echo -e "${BLUE}🔧 管理命令:${NC}"
    echo "  查看服务状态: docker compose -f docker-compose-https.yml ps"
    echo "  查看日志: docker compose -f docker-compose-https.yml logs -f"
    echo "  停止服务: docker compose -f docker-compose-https.yml down"
    echo "  重启服务: docker compose -f docker-compose-https.yml restart"
    echo ""
    
    # 测试网站访问
    echo -e "${YELLOW}🧪 测试网站访问...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ 网站访问正常${NC}"
    else
        echo -e "${YELLOW}⚠️ 网站可能需要几分钟才能完全启动${NC}"
    fi
    
else
    echo -e "${RED}❌ SSL证书申请失败${NC}"
    echo "请检查："
    echo "  1. 域名是否正确解析到此服务器"
    echo "  2. 防火墙是否开放80端口"
    echo "  3. 邮箱地址是否正确"
    exit 1
fi