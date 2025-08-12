#!/bin/bash

# Timeline Notebook 简化部署脚本
# 专注于基本功能运行，移除复杂的安全配置检查

set -e

echo "🚀 开始部署 Timeline Notebook..."

# 检查必要的命令
command -v docker >/dev/null 2>&1 || { echo "❌ Docker 未安装"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose 未安装"; exit 1; }

# 创建必要的目录
mkdir -p uploads
mkdir -p data

# 创建简化的环境配置文件
echo "📝 创建环境配置文件..."
cat > .env.production << EOF
# 基本配置
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=timeline-notebook-secret-key-$(date +%s)

# 数据库配置
DATABASE_URL=sqlite:///data/timeline.db

# 文件上传配置
UPLOAD_FOLDER=uploads
MAX_CONTENT_LENGTH=16777216

# 服务端口
PORT=5000
EOF

echo "🧹 清理旧容器和镜像..."
docker-compose down --remove-orphans 2>/dev/null || true
docker system prune -f 2>/dev/null || true

echo "🔨 构建和启动服务..."
docker-compose up --build -d

echo "⏳ 等待服务启动..."
sleep 10

# 简单的服务检查
echo "🔍 检查服务状态..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ 服务启动成功！"
    echo "📱 前端访问地址: http://localhost"
    echo "🔧 后端API地址: http://localhost/api"
else
    echo "❌ 服务启动失败，请检查日志:"
    docker-compose logs
    exit 1
fi

echo "🎉 部署完成！"
echo "💡 查看日志: docker-compose logs -f"
echo "🛑 停止服务: docker-compose down"