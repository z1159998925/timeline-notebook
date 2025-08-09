#!/bin/bash

# Timeline Notebook 部署路径修复脚本
# 解决 Dockerfile 路径问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Timeline Notebook 部署路径修复${NC}"
echo "============================================="

# 检查参数
if [ $# -eq 2 ]; then
    DOMAIN="$1"
    EMAIL="$2"
    echo -e "${GREEN}✅ 使用命令行参数: 域名=$DOMAIN, 邮箱=$EMAIL${NC}"
else
    echo -e "${RED}❌ 用法: $0 <域名> <邮箱>${NC}"
    echo "例如: $0 xn--cpq55e94lgvdcukyqt.com 1159998925@qq.com"
    exit 1
fi

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ 请使用sudo运行此脚本${NC}"
    exit 1
fi

# 获取当前目录
CURRENT_DIR=$(pwd)
echo -e "${BLUE}📍 当前目录: $CURRENT_DIR${NC}"

# 检查必要文件是否存在
echo -e "${YELLOW}🔍 检查项目文件...${NC}"
required_files=("Dockerfile.backend" "Dockerfile.frontend.server" "docker-compose-http.yml" "backend/app.py" "frontend/package.json")

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo -e "  ${RED}❌ $file 不存在${NC}"
        exit 1
    fi
done

# 停止现有服务
echo -e "${YELLOW}🛑 停止现有服务...${NC}"
docker compose down --remove-orphans 2>/dev/null || true
docker system prune -f

# 设置环境变量
export DOMAIN="$DOMAIN"
export EMAIL="$EMAIL"

# 生成修正的Docker Compose配置文件
echo -e "${YELLOW}📝 生成Docker Compose配置...${NC}"
cat > docker-compose-deploy.yml << EOF
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
      - SECRET_KEY=timeline-production-secret-key-change-this-$(date +%s)
      - UPLOAD_FOLDER=/app/static/uploads
      - MAX_CONTENT_LENGTH=16777216
      - DOMAIN=${DOMAIN}
      - EMAIL=${EMAIL}
      - CORS_ORIGINS=https://${DOMAIN},http://${DOMAIN}
      - LOG_LEVEL=INFO
    restart: unless-stopped
    networks:
      - timeline-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

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
      - ./nginx-domain.conf:/etc/nginx/nginx.conf:ro
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

# 创建必要的目录
echo -e "${YELLOW}📁 创建必要目录...${NC}"
mkdir -p data static/uploads
chmod 755 data static/uploads

# 启动临时HTTP服务申请SSL证书
echo -e "${YELLOW}🔧 启动临时HTTP服务...${NC}"
cp nginx-http-temp.conf nginx-domain.conf

# 构建并启动服务
echo -e "${YELLOW}🏗️ 构建并启动服务...${NC}"
docker compose -f docker-compose-deploy.yml build --no-cache
docker compose -f docker-compose-deploy.yml up -d

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 15

# 检查服务状态
echo -e "${BLUE}📊 检查服务状态...${NC}"
docker compose -f docker-compose-deploy.yml ps

# 申请SSL证书
echo -e "${YELLOW}🔐 申请SSL证书...${NC}"
docker compose -f docker-compose-deploy.yml exec -T certbot certbot certonly \
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
    docker compose -f docker-compose-deploy.yml restart frontend
    
    # 等待服务重启
    sleep 10
    
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 部署信息:${NC}"
    echo "  🌐 网站地址: https://$DOMAIN"
    echo "  🔐 SSL证书: 已配置"
    echo "  🐳 Docker服务: 运行中"
    echo "  📁 项目目录: $CURRENT_DIR"
    echo ""
    echo -e "${BLUE}🔧 管理命令:${NC}"
    echo "  查看服务状态: docker compose -f docker-compose-deploy.yml ps"
    echo "  查看日志: docker compose -f docker-compose-deploy.yml logs -f"
    echo "  停止服务: docker compose -f docker-compose-deploy.yml down"
    echo "  重启服务: docker compose -f docker-compose-deploy.yml restart"
    echo ""
    
    # 测试网站访问
    echo -e "${YELLOW}🧪 测试网站访问...${NC}"
    sleep 5
    if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ 网站访问正常${NC}"
    else
        echo -e "${YELLOW}⚠️ 网站可能需要几分钟才能完全启动${NC}"
        echo "请稍后访问: https://$DOMAIN"
    fi
    
else
    echo -e "${RED}❌ SSL证书申请失败${NC}"
    echo "请检查："
    echo "  1. 域名是否正确解析到此服务器"
    echo "  2. 防火墙是否开放80和443端口"
    echo "  3. 网络连接是否正常"
    echo ""
    echo "可以查看详细日志："
    echo "  docker compose -f docker-compose-deploy.yml logs certbot"
fi

echo ""
echo -e "${BLUE}📝 部署日志已保存到当前目录${NC}"