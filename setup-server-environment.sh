#!/bin/bash

# Timeline Notebook 服务器环境预配置脚本
# 在全新服务器上运行，配置所有必要的环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Timeline Notebook 服务器环境配置${NC}"
echo "============================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ 请使用sudo运行此脚本${NC}"
    exit 1
fi

# 获取系统信息
echo -e "${BLUE}📊 检查系统信息...${NC}"
echo "操作系统: $(lsb_release -d | cut -f2)"
echo "内核版本: $(uname -r)"
echo "架构: $(uname -m)"
echo ""

# 更新系统
echo -e "${YELLOW}📦 更新系统包...${NC}"
apt update && apt upgrade -y

# 安装基础工具
echo -e "${YELLOW}🛠️ 安装基础工具...${NC}"
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip

# 安装Docker
echo -e "${YELLOW}🐳 安装Docker...${NC}"
# 移除旧版本
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 添加Docker官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加Docker仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新包索引并安装Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 验证Docker安装
echo -e "${BLUE}✅ 验证Docker安装...${NC}"
docker --version
docker compose version

# 配置防火墙
echo -e "${YELLOW}🔥 配置防火墙...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "${GREEN}✅ 防火墙配置完成${NC}"
ufw status

# 创建项目目录
echo -e "${YELLOW}📁 创建项目目录...${NC}"
mkdir -p /opt/timeline-notebook
cd /opt/timeline-notebook

# 设置Git配置（可选）
echo -e "${YELLOW}⚙️ 配置Git...${NC}"
git config --global init.defaultBranch main
git config --global pull.rebase false

# 创建必要的目录结构
echo -e "${YELLOW}📂 创建目录结构...${NC}"
mkdir -p data static/uploads
chmod 755 data static/uploads

# 安装Python依赖管理工具
echo -e "${YELLOW}🐍 配置Python环境...${NC}"
pip3 install --upgrade pip
pip3 install pyyaml  # 用于YAML验证

# 创建系统服务用户（可选，增强安全性）
echo -e "${YELLOW}👤 创建服务用户...${NC}"
if ! id "timeline" &>/dev/null; then
    useradd -r -s /bin/false timeline
    usermod -aG docker timeline
fi

# 设置时区
echo -e "${YELLOW}🕐 设置时区...${NC}"
timedatectl set-timezone Asia/Shanghai

# 优化系统参数
echo -e "${YELLOW}⚡ 优化系统参数...${NC}"
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 优化内核参数
cat >> /etc/sysctl.conf << EOF
# Timeline Notebook 优化参数
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
vm.swappiness = 10
EOF

sysctl -p

# 设置自动更新（可选）
echo -e "${YELLOW}🔄 配置自动更新...${NC}"
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# 创建环境检查脚本
echo -e "${YELLOW}📋 创建环境检查脚本...${NC}"
cat > /opt/timeline-notebook/check-environment.sh << 'EOF'
#!/bin/bash

echo "=== Timeline Notebook 环境检查 ==="
echo ""

# 检查Docker
echo "🐳 Docker:"
if command -v docker &> /dev/null; then
    echo "  ✅ Docker: $(docker --version)"
    echo "  ✅ Docker Compose: $(docker compose version)"
    echo "  ✅ Docker服务状态: $(systemctl is-active docker)"
else
    echo "  ❌ Docker未安装"
fi

echo ""

# 检查端口
echo "🔌 端口检查:"
for port in 22 80 443; do
    if ss -tuln | grep ":$port " > /dev/null; then
        echo "  ✅ 端口 $port: 已开放"
    else
        echo "  ⚠️ 端口 $port: 未监听"
    fi
done

echo ""

# 检查防火墙
echo "🔥 防火墙状态:"
ufw status

echo ""

# 检查磁盘空间
echo "💾 磁盘空间:"
df -h /

echo ""

# 检查内存
echo "🧠 内存使用:"
free -h

echo ""

# 检查系统负载
echo "📊 系统负载:"
uptime

echo ""
echo "=== 环境检查完成 ==="
EOF

chmod +x /opt/timeline-notebook/check-environment.sh

# 显示完成信息
echo ""
echo -e "${GREEN}🎉 服务器环境配置完成！${NC}"
echo ""
echo -e "${BLUE}📋 配置摘要:${NC}"
echo "  ✅ 系统已更新到最新版本"
echo "  ✅ Docker 和 Docker Compose 已安装"
echo "  ✅ 防火墙已配置（开放22, 80, 443端口）"
echo "  ✅ 项目目录已创建: /opt/timeline-notebook"
echo "  ✅ 必要的系统工具已安装"
echo "  ✅ 系统参数已优化"
echo "  ✅ 时区已设置为 Asia/Shanghai"
echo ""
echo -e "${BLUE}🔧 下一步操作:${NC}"
echo "  1. 运行环境检查: /opt/timeline-notebook/check-environment.sh"
echo "  2. 克隆项目代码: cd /opt && git clone https://github.com/z1159998925/timeline-notebook.git"
echo "  3. 运行部署脚本: cd /opt/timeline-notebook && ./fix-yaml-issue.sh 域名 邮箱"
echo ""
echo -e "${YELLOW}💡 提示:${NC}"
echo "  - 确保域名已解析到此服务器IP"
echo "  - 建议重启服务器以确保所有配置生效: reboot"
echo ""

# 运行环境检查
echo -e "${BLUE}🔍 运行环境检查...${NC}"
/opt/timeline-notebook/check-environment.sh