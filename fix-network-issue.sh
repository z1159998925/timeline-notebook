#!/bin/bash

echo "🔧 Timeline Notebook 网络问题一键修复脚本"
echo "============================================"

# 1. 停止现有服务
echo "📦 停止现有服务..."
docker compose -f docker-compose-http.yml down 2>/dev/null || echo "没有运行的服务"

# 2. 清理系统
echo "🧹 清理 Docker 系统..."
docker system prune -f
docker ps -a | grep timeline | awk '{print $1}' | xargs -r docker rm -f
docker network rm timeline-notebook_timeline-network 2>/dev/null || echo "网络不存在"

# 3. 创建正确的 docker-compose-http.yml
echo "📝 创建 Docker Compose 配置..."
cat > docker-compose-http.yml << 'EOF'
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
      - CORS_ORIGINS=http://xn--fiq64bn65b9gd1xa.com,http://张伟爱刘新宇.com,http://192.3.98.137
      - LOG_LEVEL=INFO
    restart: unless-stopped
    networks:
      - timeline-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend.server
    container_name: timeline-frontend
    ports:
      - "80:80"
    volumes:
      - ./nginx-http.conf:/etc/nginx/nginx.conf
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - timeline-network

networks:
  timeline-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  timeline-data:
    driver: local
EOF

# 4. 创建正确的 nginx-http.conf
echo "📝 创建 Nginx 配置..."
cat > nginx-http.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    upstream backend {
        server timeline-backend:5000;
        keepalive 32;
    }
    
    server {
        listen 80;
        server_name _;
        
        root /usr/share/nginx/html;
        index index.html;
        
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            try_files $uri =404;
        }
        
        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
            
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        }
        
        location /uploads/ {
            proxy_pass http://backend/uploads/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location / {
            try_files $uri $uri/ /index.html;
            
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-Content-Type-Options "nosniff" always;
            add_header X-XSS-Protection "1; mode=block" always;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        server_tokens off;
    }
}
EOF

# 5. 重新构建并启动服务
echo "🚀 重新构建并启动服务..."
docker compose -f docker-compose-http.yml build --no-cache
docker compose -f docker-compose-http.yml up -d

# 6. 等待服务启动
echo "⏳ 等待服务启动（45秒）..."
sleep 45

# 7. 检查服务状态
echo ""
echo "📊 检查服务状态:"
docker compose -f docker-compose-http.yml ps

echo ""
echo "🌐 检查网络连接:"
docker network inspect timeline-notebook_timeline-network | grep -A 15 "Containers" || echo "网络检查失败"

# 8. 测试服务连接
echo ""
echo "🧪 测试服务连接:"

# 测试后端健康检查
echo "测试后端内部访问:"
docker compose -f docker-compose-http.yml exec backend curl -f http://localhost:5000/api/ && echo "✅ 后端内部访问正常" || echo "❌ 后端内部访问失败"

# 测试前端到后端的连接
echo ""
echo "测试前端到后端连接:"
docker compose -f docker-compose-http.yml exec frontend ping -c 3 timeline-backend && echo "✅ 前端可以ping通后端" || echo "❌ 前端无法ping通后端"

# 测试外部访问
echo ""
echo "🌍 测试外部访问:"
curl -I http://192.3.98.137 && echo "✅ 前端访问正常" || echo "❌ 前端访问失败"
curl -I http://192.3.98.137/api/ && echo "✅ API访问正常" || echo "❌ API访问失败"

echo ""
echo "🎉 修复完成！"
echo ""
echo "📋 管理命令:"
echo "  查看服务状态: docker compose -f docker-compose-http.yml ps"
echo "  查看日志: docker compose -f docker-compose-http.yml logs -f"
echo "  重启服务: docker compose -f docker-compose-http.yml restart"
echo "  停止服务: docker compose -f docker-compose-http.yml down"
echo ""
echo "🌍 访问地址:"
echo "  网站首页: http://192.3.98.137"
echo "  后端API: http://192.3.98.137/api/"
echo "  域名访问: http://张伟爱刘新宇.com (需要DNS解析)"

# 如果有问题，显示日志
if ! curl -s http://192.3.98.137/api/ > /dev/null; then
    echo ""
    echo "⚠️  API访问失败，显示最近日志:"
    echo "--- 后端日志 ---"
    docker compose -f docker-compose-http.yml logs --tail=10 backend
    echo ""
    echo "--- 前端日志 ---"
    docker compose -f docker-compose-http.yml logs --tail=10 frontend
fi