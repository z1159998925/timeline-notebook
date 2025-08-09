#!/bin/bash

# Timeline Notebook 重新部署脚本
# 清理现有部署并重新从GitHub部署最新代码

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Timeline Notebook 重新部署脚本${NC}"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ 请使用sudo运行此脚本${NC}"
    exit 1
fi

# 获取域名和邮箱
if [ $# -eq 2 ]; then
    DOMAIN="$1"
    EMAIL="$2"
else
    echo -e "${YELLOW}📝 请输入部署信息:${NC}"
    read -p "域名 (例如: 张伟爱刘新宇.com): " DOMAIN
    read -p "邮箱 (例如: 1159998925@qq.com): " EMAIL
fi

# 验证输入
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ 域名和邮箱不能为空${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 域名: $DOMAIN${NC}"
echo -e "${GREEN}✅ 邮箱: $EMAIL${NC}"
echo ""

# 设置项目目录
PROJECT_DIR="/opt/timeline-notebook"

echo -e "${YELLOW}🛑 停止现有服务...${NC}"
# 停止所有相关服务
cd $PROJECT_DIR 2>/dev/null || true
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose-https.yml down 2>/dev/null || true
docker-compose -f docker-compose-server.yml down 2>/dev/null || true
docker stop $(docker ps -q) 2>/dev/null || true

echo -e "${YELLOW}🧹 清理现有部署...${NC}"
# 清理Docker资源
docker system prune -f
docker volume prune -f

# 备份数据（如果存在）
if [ -d "$PROJECT_DIR/data" ]; then
    echo -e "${BLUE}💾 备份现有数据...${NC}"
    cp -r $PROJECT_DIR/data /tmp/timeline-data-backup-$(date +%Y%m%d_%H%M%S) || true
fi

# 完全清理项目目录
echo -e "${YELLOW}🗑️ 清理项目目录...${NC}"
rm -rf $PROJECT_DIR
mkdir -p $PROJECT_DIR

echo -e "${BLUE}📥 克隆最新代码...${NC}"
cd /opt
git clone https://github.com/z1159998925/timeline-notebook.git
cd $PROJECT_DIR

# 恢复数据（如果有备份）
BACKUP_DIR=$(ls -t /tmp/timeline-data-backup-* 2>/dev/null | head -1)
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo -e "${BLUE}🔄 恢复数据备份...${NC}"
    cp -r $BACKUP_DIR ./data
    chown -R 1000:1000 ./data 2>/dev/null || true
fi

# 创建必要目录
echo -e "${YELLOW}📁 创建必要目录...${NC}"
mkdir -p data static/uploads
chmod 755 data static/uploads

# 更新系统和安装依赖
echo -e "${BLUE}📦 更新系统和安装依赖...${NC}"
apt update
apt install -y docker.io docker-compose git ufw curl python3 python3-pip

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 设置防火墙
echo -e "${BLUE}🔥 配置防火墙...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 运行YAML修复脚本
echo -e "${GREEN}🔧 运行SSL证书申请和HTTPS配置...${NC}"
chmod +x fix-yaml-issue.sh
./fix-yaml-issue.sh "$DOMAIN" "$EMAIL"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 重新部署完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 部署信息:${NC}"
    echo "   🌐 网站地址: https://$DOMAIN"
    echo "   📁 项目目录: $PROJECT_DIR"
    echo "   💾 数据目录: $PROJECT_DIR/data"
    echo ""
    echo -e "${BLUE}🔧 管理命令:${NC}"
    echo "   查看服务状态: docker-compose -f docker-compose-https.yml ps"
    echo "   查看日志: docker-compose -f docker-compose-https.yml logs"
    echo "   重启服务: docker-compose -f docker-compose-https.yml restart"
    echo "   停止服务: docker-compose -f docker-compose-https.yml down"
    echo "   创建管理员: docker exec -it timeline-backend python create_admin.py"
    echo ""
    echo -e "${YELLOW}📝 注意事项:${NC}"
    echo "   1. 确保域名 $DOMAIN 已正确解析到此服务器IP"
    echo "   2. SSL证书将自动更新，无需手动干预"
    echo "   3. 数据已从备份中恢复（如果存在）"
    
    # 测试服务
    echo ""
    echo -e "${BLUE}🧪 测试服务状态...${NC}"
    sleep 10
    if curl -k -s https://$DOMAIN > /dev/null; then
        echo -e "${GREEN}✅ HTTPS服务正常运行${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS服务可能需要几分钟才能完全启动${NC}"
    fi
    
else
    echo -e "${RED}❌ 部署过程中出现错误${NC}"
    echo "请检查日志并重试"
    exit 1
fi