#!/bin/bash

echo "🔧 修复数据库权限问题..."

# 停止所有服务
echo "1. 停止现有服务..."
docker compose -f docker-compose-http.yml down --remove-orphans 2>/dev/null || true

# 清理Docker系统
echo "2. 清理Docker系统..."
docker system prune -f

# 检查并创建数据目录
echo "3. 检查并创建数据目录..."
sudo mkdir -p /opt/timeline-notebook/data
sudo chmod 755 /opt/timeline-notebook/data

# 创建修复后的docker-compose配置
echo "4. 创建修复后的docker-compose配置..."
cat > docker-compose-http.yml << 'EOF'
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
      - UPLOAD_FOLDER=/app/static/uploads
    volumes:
      - /opt/timeline-notebook/data:/app/data
      - ./static/uploads:/app/static/uploads
    networks:
      - timeline-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
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
    volumes:
      - ./nginx-http.conf:/etc/nginx/conf.d/default.conf
      - ./static/uploads:/usr/share/nginx/html/uploads
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - timeline-network
    restart: unless-stopped

networks:
  timeline-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

# 创建nginx配置
echo "5. 创建nginx配置..."
cat > nginx-http.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Gzip压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # 后端API代理
    location /api/ {
        proxy_pass http://timeline-backend:5000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
    
    # 文件上传代理
    location /uploads/ {
        proxy_pass http://timeline-backend:5000/uploads/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 健康检查
    location /health {
        proxy_pass http://timeline-backend:5000/api/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 前端静态文件
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        
        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

# 设置数据库文件权限
echo "6. 初始化数据库..."
sudo touch /opt/timeline-notebook/data/timeline.db
sudo chmod 666 /opt/timeline-notebook/data/timeline.db
sudo chown -R 1000:1000 /opt/timeline-notebook/data

# 创建uploads目录
echo "7. 创建uploads目录..."
mkdir -p static/uploads
chmod 755 static/uploads

# 重新构建并启动服务
echo "8. 重新构建并启动服务..."
docker compose -f docker-compose-http.yml build --no-cache
docker compose -f docker-compose-http.yml up -d

# 等待服务启动
echo "9. 等待服务启动..."
sleep 30

# 检查服务状态
echo "10. 检查服务状态..."
docker compose -f docker-compose-http.yml ps

# 检查网络连接
echo "11. 检查网络连接..."
docker network ls | grep timeline

# 初始化数据库表
echo "12. 初始化数据库表..."
docker compose -f docker-compose-http.yml exec backend python -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('数据库表创建成功')
" 2>/dev/null || echo "数据库初始化可能需要手动执行"

# 测试服务连接
echo ""
echo "🧪 测试服务连接:"

# 测试后端内部访问
echo " 测试后端内部访问:"
if docker compose -f docker-compose-http.yml exec backend curl -f http://localhost:5000/api/health 2>/dev/null; then
    echo " ✅ 后端内部访问成功"
else
    echo " ❌ 后端内部访问失败"
fi

# 测试前端到后端连接
echo " 测试前端到后端连接:"
if docker compose -f docker-compose-http.yml exec frontend ping -c 1 timeline-backend >/dev/null 2>&1; then
    echo " ✅ 前端可以ping通后端"
else
    echo " ❌ 前端无法ping通后端"
fi

# 获取服务器IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# 测试外部访问
echo " 🌍 测试外部访问:"
if curl -f http://$SERVER_IP >/dev/null 2>&1; then
    echo " ✅ 前端访问成功"
else
    echo " ❌ 前端访问失败"
    curl -I http://$SERVER_IP 2>&1 | head -3
fi

if curl -f http://$SERVER_IP/api/health >/dev/null 2>&1; then
    echo " ✅ API访问成功"
else
    echo " ❌ API访问失败"
    curl -I http://$SERVER_IP/api/health 2>&1 | head -3
fi

echo ""
echo "🎉 数据库修复完成！"
echo ""
echo "📋 管理命令:"
echo "  查看服务状态: docker compose -f docker-compose-http.yml ps"
echo "  查看日志: docker compose -f docker-compose-http.yml logs -f"
echo "  查看后端日志: docker compose -f docker-compose-http.yml logs backend"
echo "  重启服务: docker compose -f docker-compose-http.yml restart"
echo "  停止服务: docker compose -f docker-compose-http.yml down"
echo ""
echo "🌍 访问地址:"
echo "  网站首页: http://$SERVER_IP"
echo "  后端API: http://$SERVER_IP/api/"
echo "  健康检查: http://$SERVER_IP/health"
echo ""

# 如果API访问失败，显示日志
if ! curl -f http://$SERVER_IP/api/health >/dev/null 2>&1; then
    echo "⚠️  API访问失败，显示最近日志:"
    echo "--- 后端日志 ---"
    docker compose -f docker-compose-http.yml logs --tail=20 backend
    echo ""
    echo "--- 前端日志 ---"
    docker compose -f docker-compose-http.yml logs --tail=10 frontend
fi