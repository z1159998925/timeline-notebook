#!/bin/bash

# 修复YAML控制字符问题的脚本
# 解决 "yaml: control characters are not allowed" 错误

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 修复YAML控制字符问题${NC}"
echo "=================================="

# 检查必要的环境变量
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ 错误: 请设置环境变量 DOMAIN 和 EMAIL${NC}"
    echo "示例:"
    echo "export DOMAIN=张伟爱刘新宇.com"
    echo "export EMAIL=1159998925@qq.com"
    exit 1
fi

echo -e "${GREEN}✅ 域名: $DOMAIN${NC}"
echo -e "${GREEN}✅ 邮箱: $EMAIL${NC}"
echo ""

# 停止现有服务
echo -e "${YELLOW}🛑 停止现有服务...${NC}"
docker-compose -f docker-compose-https.yml down 2>/dev/null || true
docker stop $(docker ps -q) 2>/dev/null || true

# 清理旧文件
echo -e "${YELLOW}🧹 清理旧的配置文件...${NC}"
rm -f docker-compose-https.yml nginx-https.conf nginx-http-temp.conf

# 使用cat而不是echo来创建YAML文件，避免控制字符问题
echo -e "${YELLOW}📝 创建干净的Docker Compose配置...${NC}"
cat > docker-compose-https.yml << 'COMPOSE_EOF'
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
      - ./nginx-https.conf:/etc/nginx/nginx.conf
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
COMPOSE_EOF

# 使用环境变量替换
echo -e "${YELLOW}🔄 配置环境变量...${NC}"
sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" docker-compose-https.yml
sed -i "s/EMAIL_PLACEHOLDER/${EMAIL}/g" docker-compose-https.yml

# 添加环境变量到backend服务
sed -i "/MAX_CONTENT_LENGTH=16777216/a\\      - DOMAIN=${DOMAIN}" docker-compose-https.yml
sed -i "/DOMAIN=${DOMAIN}/a\\      - EMAIL=${EMAIL}" docker-compose-https.yml
sed -i "/EMAIL=${EMAIL}/a\\      - CORS_ORIGINS=https://${DOMAIN},http://${DOMAIN}" docker-compose-https.yml
sed -i "/CORS_ORIGINS=https:\/\/${DOMAIN},http:\/\/${DOMAIN}/a\\      - LOG_LEVEL=INFO" docker-compose-https.yml

# 创建HTTPS Nginx配置
echo -e "${YELLOW}📝 创建HTTPS Nginx配置...${NC}"
cat > nginx-https.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 16M;

    # 上游后端服务
    upstream backend {
        server timeline-backend:5000;
    }

    # HTTP服务器 - 重定向到HTTPS
    server {
        listen 80;
        server_name _;
        
        # Let's Encrypt验证
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # 其他请求重定向到HTTPS
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS服务器
    server {
        listen 443 ssl http2;
        server_name _;

        # SSL证书配置
        ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
        
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
        location /static/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # API路由
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
        }

        # 前端路由
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
        }
    }
}
NGINX_EOF

# 替换域名占位符
sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" nginx-https.conf

# 创建临时HTTP配置
echo -e "${YELLOW}📝 创建临时HTTP配置...${NC}"
cat > nginx-http-temp.conf << 'HTTP_EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;

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
HTTP_EOF

# 验证YAML文件格式
echo -e "${BLUE}🔍 验证YAML文件格式...${NC}"
if command -v python3 &> /dev/null; then
    python3 -c "
import yaml
import sys
try:
    with open('docker-compose-https.yml', 'r') as f:
        yaml.safe_load(f)
    print('✅ YAML格式验证通过')
except yaml.YAMLError as e:
    print(f'❌ YAML格式错误: {e}')
    sys.exit(1)
"
else
    echo "⚠️ 无法验证YAML格式（python3未安装）"
fi

# 检查文件编码
echo -e "${BLUE}🔍 检查文件编码...${NC}"
file docker-compose-https.yml
file nginx-https.conf

# 启动临时HTTP服务进行证书申请
echo -e "${YELLOW}🌐 使用临时HTTP配置启动服务...${NC}"
# 临时修改配置使用HTTP-only
cp docker-compose-https.yml docker-compose-https.yml.backup
sed -i 's|./nginx-https.conf:/etc/nginx/nginx.conf|./nginx-http-temp.conf:/etc/nginx/nginx.conf|' docker-compose-https.yml

# 启动服务
docker-compose -f docker-compose-https.yml up -d frontend

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 15

# 检查服务状态
echo -e "${BLUE}🔍 检查服务状态...${NC}"
docker-compose -f docker-compose-https.yml ps

# 测试HTTP访问
echo -e "${BLUE}🧪 测试HTTP访问...${NC}"
curl -s http://localhost/health || echo "❌ HTTP访问失败"

# 申请SSL证书
echo -e "${GREEN}🔐 申请SSL证书...${NC}"
docker-compose -f docker-compose-https.yml run --rm certbot \
    certonly --webroot \
    -w /var/www/certbot \
    --email $EMAIL \
    -d $DOMAIN \
    --agree-tos \
    --no-eff-email \
    --force-renewal

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL证书申请成功！${NC}"
    
    # 恢复HTTPS配置
    echo -e "${YELLOW}🔄 恢复HTTPS配置...${NC}"
    cp docker-compose-https.yml.backup docker-compose-https.yml
    
    # 重启服务以加载证书
    echo -e "${YELLOW}🔄 重启服务以加载SSL证书...${NC}"
    docker-compose -f docker-compose-https.yml restart frontend
    
    # 启动完整服务
    echo -e "${GREEN}🚀 启动完整HTTPS服务...${NC}"
    docker-compose -f docker-compose-https.yml up -d
    
    # 等待服务启动
    sleep 20
    
    # 检查最终状态
    echo -e "${BLUE}📊 检查服务状态...${NC}"
    docker-compose -f docker-compose-https.yml ps
    
    # 测试HTTPS连接
    echo -e "${BLUE}🧪 测试HTTPS连接...${NC}"
    if curl -k -s https://$DOMAIN > /dev/null; then
        echo -e "${GREEN}✅ HTTPS连接测试成功！${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS连接测试失败，请检查域名DNS设置${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 HTTPS部署完成！${NC}"
    echo -e "${BLUE}🌐 网站地址: https://$DOMAIN${NC}"
    
else
    echo -e "${RED}❌ SSL证书申请失败${NC}"
    echo "请检查域名DNS设置和网络连接"
fi

# 清理临时文件
rm -f docker-compose-https.yml.backup nginx-http-temp.conf

echo ""
echo -e "${BLUE}📋 管理命令:${NC}"
echo "   查看日志: docker-compose -f docker-compose-https.yml logs"
echo "   重启服务: docker-compose -f docker-compose-https.yml restart"
echo "   停止服务: docker-compose -f docker-compose-https.yml down"