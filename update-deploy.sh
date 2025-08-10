#!/bin/bash

# Timeline Notebook 更新部署脚本
# 用于更新应用到最新版本

set -e

echo "🚀 开始更新 Timeline Notebook..."
echo "更新时间: $(date)"

# 1. 检查Docker和Docker Compose
echo "🔍 检查环境..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装"
    exit 1
fi

echo "✅ 环境检查通过"

# 2. 创建备份
echo "💾 创建更新前备份..."
if [ -f "./backup.sh" ]; then
    chmod +x ./backup.sh
    ./backup.sh
    echo "✅ 备份完成"
else
    echo "⚠️ 备份脚本不存在，跳过备份"
fi

# 3. 拉取最新代码（如果是Git仓库）
if [ -d ".git" ]; then
    echo "📥 拉取最新代码..."
    git stash push -m "Update deployment stash $(date)"
    git pull origin main || git pull origin master
    echo "✅ 代码更新完成"
else
    echo "⚠️ 非Git仓库，跳过代码拉取"
fi

# 4. 停止现有服务
echo "⏹️ 停止现有服务..."
docker-compose down --remove-orphans
echo "✅ 服务已停止"

# 5. 清理旧镜像（可选）
echo "🧹 清理旧Docker镜像..."
docker system prune -f
echo "✅ 清理完成"

# 6. 重新构建镜像
echo "🔨 重新构建镜像..."
docker-compose build --no-cache
echo "✅ 镜像构建完成"

# 7. 启动服务
echo "▶️ 启动更新后的服务..."
docker-compose up -d
echo "✅ 服务启动完成"

# 8. 等待服务就绪
echo "⏳ 等待服务就绪..."
sleep 30

# 9. 健康检查
echo "🔍 执行健康检查..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f -s http://localhost/api/health > /dev/null 2>&1; then
        echo "✅ 健康检查通过"
        break
    else
        echo "⏳ 等待服务启动... ($((RETRY_COUNT + 1))/$MAX_RETRIES)"
        sleep 10
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ 健康检查失败，服务可能未正常启动"
    echo "📋 查看服务状态:"
    docker-compose ps
    echo "📋 查看日志:"
    docker-compose logs --tail=50
    exit 1
fi

# 10. 验证关键功能
echo "🧪 验证关键功能..."

# 检查前端
if curl -f -s http://localhost/ > /dev/null 2>&1; then
    echo "✅ 前端服务正常"
else
    echo "❌ 前端服务异常"
fi

# 检查API
if curl -f -s http://localhost/api/timeline > /dev/null 2>&1; then
    echo "✅ API服务正常"
else
    echo "❌ API服务异常"
fi

# 11. 显示服务状态
echo "📊 服务状态:"
docker-compose ps

echo "📋 服务日志 (最近20行):"
docker-compose logs --tail=20

# 12. 更新完成
echo "🎉 更新部署完成！"
echo "📱 应用访问地址:"
echo "  - 前端: http://localhost/"
echo "  - API健康检查: http://localhost/api/health"
echo "  - 管理面板: http://localhost/admin"

echo "💡 如果遇到问题，可以使用以下命令:"
echo "  - 查看日志: docker-compose logs -f"
echo "  - 重启服务: docker-compose restart"
echo "  - 回滚: 恢复备份并重新部署"

echo "✨ 更新流程完成！"