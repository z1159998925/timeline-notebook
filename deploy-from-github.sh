#!/bin/bash
# Timeline Notebook GitHub部署脚本
# 在服务器上执行此脚本从GitHub拉取最新代码并部署

set -e

# 配置变量
REPO_URL="https://github.com/z1159998925/timeline-notebook.git"
DEPLOY_PATH="/opt/timeline-notebook"
BRANCH="main"

echo "========================================="
echo "Timeline Notebook GitHub部署脚本"
echo "========================================="
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本"
    exit 1
fi

# 安装必要工具
echo "1. 安装必要工具..."
apt-get update
apt-get install -y git curl

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，正在安装..."
    ./install-docker-ubuntu.sh
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose未安装，正在安装..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 创建部署目录
echo "2. 准备部署目录..."
mkdir -p $DEPLOY_PATH
cd $DEPLOY_PATH

# 克隆或更新代码
if [ -d ".git" ]; then
    echo "3. 更新代码..."
    git fetch origin
    git reset --hard origin/$BRANCH
    git clean -fd
else
    echo "3. 克隆代码..."
    rm -rf *
    git clone $REPO_URL .
    git checkout $BRANCH
fi

# 复制环境配置
echo "4. 配置环境..."
if [ -f ".env.server" ]; then
    cp .env.server .env
    echo "✓ 环境配置已复制"
else
    echo "⚠️  警告: .env.server 文件不存在"
fi

# 创建必要目录
echo "5. 创建必要目录..."
mkdir -p data
mkdir -p static/uploads
mkdir -p certbot-certs
mkdir -p certbot-www

# 设置权限
chown -R www-data:www-data static/uploads
chmod 755 static/uploads

# 停止现有服务
echo "6. 停止现有服务..."
docker-compose -f docker-compose-server.yml down || true

# 清理旧镜像
echo "7. 清理旧镜像..."
docker system prune -f

# 构建并启动服务
echo "8. 构建并启动服务..."
docker-compose -f docker-compose-server.yml up --build -d

# 等待服务启动
echo "9. 等待服务启动..."
sleep 20

# 健康检查
echo "10. 健康检查..."
for i in {1..10}; do
    if docker exec timeline-backend curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✓ 后端服务健康检查通过"
        break
    else
        echo "等待后端服务启动... ($i/10)"
        sleep 5
    fi
    
    if [ $i -eq 10 ]; then
        echo "❌ 后端服务启动失败"
        echo "查看日志:"
        docker-compose -f docker-compose-server.yml logs backend
        exit 1
    fi
done

# 显示服务状态
echo ""
echo "========================================="
echo "部署完成！"
echo "========================================="
echo ""
echo "服务状态:"
docker-compose -f docker-compose-server.yml ps

echo ""
echo "访问信息:"
echo "网站: https://$(grep DOMAIN .env | cut -d'=' -f2)"
echo ""
echo "管理命令:"
echo "查看日志: docker-compose -f docker-compose-server.yml logs -f"
echo "重启服务: docker-compose -f docker-compose-server.yml restart"
echo "停止服务: docker-compose -f docker-compose-server.yml down"
echo ""
echo "创建管理员账户:"
echo "docker exec -it timeline-backend python create_admin.py"
echo ""