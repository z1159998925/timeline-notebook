#!/bin/bash

echo "🔧 修复 Timeline Notebook Docker 网络问题"
echo "========================================"

# 1. 停止所有服务
echo "📦 停止现有服务..."
docker compose -f docker-compose-http.yml down 2>/dev/null || echo "没有运行的服务"

# 2. 清理系统
echo "🧹 清理 Docker 系统..."
docker system prune -f

# 3. 检查并删除可能存在的孤立容器
echo "🔍 检查孤立容器..."
docker ps -a | grep timeline | awk '{print $1}' | xargs -r docker rm -f

# 4. 重新创建网络
echo "🌐 重新创建网络..."
docker network rm timeline-notebook_timeline-network 2>/dev/null || echo "网络不存在"

# 5. 重新构建和启动服务
echo "🚀 重新构建和启动服务..."
docker compose -f docker-compose-http.yml build --no-cache
docker compose -f docker-compose-http.yml up -d

# 6. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 7. 检查服务状态
echo "📊 检查服务状态..."
docker compose -f docker-compose-http.yml ps

echo ""
echo "🌐 检查网络连接..."
docker network inspect timeline-notebook_timeline-network | grep -A 10 "Containers"

echo ""
echo "🧪 测试服务连接..."

# 测试后端健康检查
echo "测试后端健康检查:"
docker compose -f docker-compose-http.yml exec backend curl -f http://localhost:5000/api/ && echo "✅ 后端内部访问正常" || echo "❌ 后端内部访问失败"

# 测试前端到后端的连接
echo ""
echo "测试前端到后端连接:"
docker compose -f docker-compose-http.yml exec frontend ping -c 3 timeline-backend && echo "✅ 前端可以ping通后端" || echo "❌ 前端无法ping通后端"

# 测试外部访问
echo ""
echo "测试外部访问:"
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