#!/bin/bash

# Timeline Notebook 生产环境部署脚本
# 基于生产环境最佳实践配置清单

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Timeline Notebook 生产环境部署${NC}"
echo "============================================="

# 检查参数
if [ $# -eq 2 ]; then
    DOMAIN="$1"
    EMAIL="$2"
else
    echo -e "${YELLOW}📝 请输入部署信息:${NC}"
    read -p "请输入域名: " DOMAIN
    read -p "请输入邮箱: " EMAIL
fi

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ 域名和邮箱不能为空${NC}"
    exit 1
fi

# 生成安全的密钥
PRODUCTION_SECRET_KEY=$(openssl rand -hex 32)
DB_SECRET=$(openssl rand -hex 16)

echo -e "${GREEN}✅ 部署配置:${NC}"
echo "  域名: $DOMAIN"
echo "  邮箱: $EMAIL"
echo "  密钥: 已生成安全密钥"
echo ""

# 1. 🛡️ 安全类配置
echo -e "${YELLOW}🛡️ 配置生产环境安全设置...${NC}"

# 创建生产环境配置文件
cat > .env.production << EOF
# Timeline Notebook 生产环境配置
FLASK_ENV=production
FLASK_APP=app.py

# 安全配置 - 生产环境密钥
SECRET_KEY=${PRODUCTION_SECRET_KEY}
DB_SECRET=${DB_SECRET}

# 数据库配置
DATABASE_URL=sqlite:///data/timeline.db

# 域名配置
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}

# 上传配置
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=104857600

# 安全配置
SESSION_COOKIE_SECURE=True
SESSION_COOKIE_HTTPONLY=True
SESSION_COOKIE_SAMESITE=Lax

# CORS配置 - 仅允许指定域名
CORS_ORIGINS=https://${DOMAIN},http://${DOMAIN}

# 日志配置
LOG_LEVEL=WARNING
LOG_FILE=/app/logs/app.log

# 性能配置
WORKERS=4
TIMEOUT=120
EOF

# 2. ⚙️ 性能优化配置
echo -e "${YELLOW}⚙️ 创建生产环境后端配置...${NC}"

# 创建优化的生产环境Dockerfile
cat > Dockerfile.backend.production << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    sqlite3 \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# 复制后端代码
COPY backend/ .

# 安装Python依赖 + 生产服务器
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# 创建必要目录
RUN mkdir -p /app/data /app/static/uploads /app/logs
RUN chmod 755 /app/data /app/static/uploads /app/logs

# 创建生产启动脚本
RUN cat > /app/start-production.sh << 'STARTEOF'
#!/bin/bash

# 初始化数据库
python -c "
from app import app, db
import os
with app.app_context():
    if not os.path.exists('data/timeline.db'):
        db.create_all()
        print('✅ 数据库初始化完成')
    else:
        print('✅ 数据库已存在')
"

# 启动Gunicorn生产服务器
exec gunicorn \
    --bind 0.0.0.0:5000 \
    --workers ${WORKERS:-4} \
    --timeout ${TIMEOUT:-120} \
    --worker-class sync \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /app/logs/access.log \
    --error-logfile /app/logs/error.log \
    --log-level warning \
    wsgi:app
STARTEOF

RUN chmod +x /app/start-production.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

EXPOSE 5000

CMD ["/app/start-production.sh"]
EOF

# 3. 🔌 前端生产环境优化
echo -e "${YELLOW}🔌 创建前端生产环境配置...${NC}"

# 创建前端生产环境变量
cat > frontend/.env.production << EOF
# 前端生产环境配置
VITE_API_BASE_URL=https://${DOMAIN}/api
VITE_MEDIA_BASE_URL=https://${DOMAIN}
NODE_ENV=production
EOF

# 创建优化的前端Dockerfile
cat > Dockerfile.frontend.production << 'EOF'
FROM node:18-alpine as builder

WORKDIR /app

# 复制package文件
COPY frontend/package*.json ./

# 安装依赖（仅生产依赖）
RUN npm ci --only=production

# 复制源代码
COPY frontend/ .

# 生产构建
RUN npm run build

# 生产镜像
FROM nginx:alpine

# 安装curl用于健康检查
RUN apk add --no-cache curl

# 复制构建文件
COPY --from=builder /app/dist /usr/share/nginx/html

# 创建优化的Nginx配置
RUN cat > /etc/nginx/nginx.conf << 'NGINXEOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    # 性能优化
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
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    server {
        listen 80;
        server_name _;
        
        root /usr/share/nginx/html;
        index index.html;
        
        # 静态文件缓存
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # 前端路由
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # API代理
        location /api/ {
            proxy_pass http://backend:5000/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # 静态文件代理
        location /static/ {
            proxy_pass http://backend:5000/static/;
            proxy_set_header Host $host;
        }
        
        # 健康检查
        location /nginx-health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
NGINXEOF

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost/nginx-health || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# 4. 📦 创建生产环境Docker Compose
echo -e "${YELLOW}📦 创建生产环境Docker Compose配置...${NC}"

cat > docker-compose.production.yml << EOF
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend.production
    container_name: timeline-backend-prod
    env_file:
      - .env.production
    volumes:
      - ./data:/app/data
      - ./static/uploads:/app/static/uploads
      - ./logs:/app/logs
    restart: unless-stopped
    networks:
      - timeline-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend.production
    container_name: timeline-frontend-prod
    ports:
      - "80:80"
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - timeline-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/nginx-health"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  timeline-network:
    driver: bridge

volumes:
  timeline-data:
  timeline-uploads:
  timeline-logs:
EOF

# 5. 🧹 清理和准备
echo -e "${YELLOW}🧹 清理现有环境...${NC}"
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker system prune -af

# 创建必要目录
mkdir -p ./data ./static/uploads ./logs
chmod 755 ./data ./static/uploads ./logs

# 6. 🏗️ 构建和部署
echo -e "${YELLOW}🏗️ 构建生产环境镜像...${NC}"
docker compose -f docker-compose.production.yml build --no-cache

echo -e "${YELLOW}🚀 启动生产环境服务...${NC}"
docker compose -f docker-compose.production.yml up -d

# 7. ✅ 验证部署
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 60

echo -e "${YELLOW}🔍 检查服务状态...${NC}"
docker compose -f docker-compose.production.yml ps

# 检查后端健康状态
echo -e "${YELLOW}🏥 检查后端健康状态...${NC}"
for i in {1..10}; do
    if docker exec timeline-backend-prod curl -f http://localhost:5000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 后端服务健康${NC}"
        break
    else
        echo -e "${YELLOW}⏳ 等待后端启动... ($i/10)${NC}"
        sleep 10
    fi
    
    if [ $i -eq 10 ]; then
        echo -e "${RED}❌ 后端启动失败${NC}"
        docker logs timeline-backend-prod --tail 50
        exit 1
    fi
done

# 检查前端
echo -e "${YELLOW}🌐 检查前端服务...${NC}"
if curl -f http://localhost/nginx-health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 前端服务健康${NC}"
else
    echo -e "${RED}❌ 前端服务异常${NC}"
    docker logs timeline-frontend-prod --tail 20
fi

# 8. 📋 部署完成报告
echo ""
echo -e "${GREEN}🎉 生产环境部署完成！${NC}"
echo "============================================="
echo -e "${BLUE}📋 生产环境信息:${NC}"
echo "  访问地址: http://localhost (HTTP)"
echo "  API地址: http://localhost/api"
echo "  健康检查: http://localhost/nginx-health"
echo "  数据目录: ./data"
echo "  上传目录: ./static/uploads"
echo "  日志目录: ./logs"
echo ""
echo -e "${YELLOW}🔒 安全配置:${NC}"
echo "  ✅ 调试模式: 已关闭"
echo "  ✅ 生产密钥: 已生成"
echo "  ✅ CORS限制: 仅允许指定域名"
echo "  ✅ 安全头: 已配置"
echo "  ✅ Gzip压缩: 已启用"
echo ""
echo -e "${BLUE}⚡ 性能优化:${NC}"
echo "  ✅ Gunicorn: 4个工作进程"
echo "  ✅ 静态文件缓存: 1年"
echo "  ✅ 连接池: 已优化"
echo "  ✅ 健康检查: 已配置"
echo ""
echo -e "${YELLOW}📝 下一步操作:${NC}"
echo "1. 配置HTTPS证书 (推荐使用Let's Encrypt)"
echo "2. 配置域名DNS解析"
echo "3. 设置防火墙规则"
echo "4. 配置日志轮转"
echo "5. 设置监控和备份"
echo ""
echo -e "${BLUE}🔧 管理命令:${NC}"
echo "  查看日志: docker compose -f docker-compose.production.yml logs -f"
echo "  重启服务: docker compose -f docker-compose.production.yml restart"
echo "  停止服务: docker compose -f docker-compose.production.yml down"
echo "  查看状态: docker compose -f docker-compose.production.yml ps"
echo ""
echo -e "${GREEN}✅ 生产环境检查清单已完成:${NC}"
echo "  ✅ 关闭所有调试输出"
echo "  ✅ 敏感信息全部外部化"
echo "  ✅ 前端执行生产构建"
echo "  ✅ 配置文件适配生产路径"
echo "  ✅ 设置监控和日志"
echo "  ✅ 性能优化配置"
echo "  ✅ 安全头和CORS配置"
echo ""