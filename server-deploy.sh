#!/bin/bash

# 🚀 Timeline Notebook 服务器快速部署脚本
# 专注功能运行，无安全检查

echo "=== Timeline Notebook 服务器快速部署 ==="
echo "开始时间: $(date)"

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi

echo "✅ Docker环境检查通过"

# 停止并清理旧容器
echo "🧹 清理旧容器和镜像..."
docker-compose down --remove-orphans 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# 创建必要目录
echo "📁 创建必要目录..."
mkdir -p backend/static/uploads
mkdir -p data
mkdir -p logs

# 生成简化的生产环境配置
echo "⚙️ 生成生产环境配置..."
cat > .env.production << EOF
# Timeline Notebook 生产环境配置
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=timeline-notebook-production-key-$(date +%s)
DATABASE_URL=sqlite:///data/timeline_notebook.db
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=16777216
CORS_ORIGINS=*
PORT=5000
HOST=0.0.0.0
EOF

echo "✅ 环境配置生成完成"

# 构建并启动服务
echo "🔨 构建并启动服务..."
docker-compose up --build -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "🔍 检查服务状态..."
docker-compose ps

# 简单的健康检查
echo "🏥 进行健康检查..."
for i in {1..5}; do
    if curl -f http://localhost:5000/health 2>/dev/null; then
        echo "✅ 后端服务运行正常"
        break
    else
        echo "⏳ 等待后端服务启动... ($i/5)"
        sleep 5
    fi
done

for i in {1..5}; do
    if curl -f http://localhost:80 2>/dev/null; then
        echo "✅ 前端服务运行正常"
        break
    else
        echo "⏳ 等待前端服务启动... ($i/5)"
        sleep 5
    fi
done

echo ""
echo "🎉 部署完成！"
echo "📱 前端访问地址: http://$(hostname -I | awk '{print $1}'):80"
echo "🔧 后端API地址: http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "📋 常用命令:"
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
echo "  查看状态: docker-compose ps"
echo ""
echo "完成时间: $(date)"