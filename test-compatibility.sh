#!/bin/bash

# Timeline Notebook 兼容性测试脚本
# 用于验证项目在不同环境下的兼容性

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Timeline Notebook 兼容性测试${NC}"
echo "============================================="

# 检查系统信息
echo -e "${BLUE}📊 系统信息${NC}"
echo "操作系统: $(uname -s)"
echo "架构: $(uname -m)"
if command -v lsb_release &> /dev/null; then
    echo "发行版: $(lsb_release -d | cut -f2)"
fi
echo ""

# 检查 Node.js 版本
echo -e "${YELLOW}🟢 Node.js 兼容性检查${NC}"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    echo "✅ Node.js 版本: $NODE_VERSION"
    
    # 检查版本是否满足要求 (>= 16.0.0)
    if [ "$(printf '%s\n' "16.0.0" "$NODE_VERSION" | sort -V | head -n1)" = "16.0.0" ]; then
        echo "✅ Node.js 版本兼容"
    else
        echo -e "${RED}❌ Node.js 版本过低，需要 >= 16.0.0${NC}"
    fi
else
    echo -e "${RED}❌ Node.js 未安装${NC}"
fi

if command -v npm &> /dev/null; then
    echo "✅ npm 版本: $(npm --version)"
else
    echo -e "${RED}❌ npm 未安装${NC}"
fi
echo ""

# 检查 Python 版本
echo -e "${YELLOW}🐍 Python 兼容性检查${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "✅ Python 版本: $PYTHON_VERSION"
    
    # 检查版本是否满足要求 (>= 3.8.0)
    if [ "$(printf '%s\n' "3.8.0" "$PYTHON_VERSION" | sort -V | head -n1)" = "3.8.0" ]; then
        echo "✅ Python 版本兼容"
    else
        echo -e "${RED}❌ Python 版本过低，需要 >= 3.8.0${NC}"
    fi
else
    echo -e "${RED}❌ Python3 未安装${NC}"
fi

if command -v pip3 &> /dev/null; then
    echo "✅ pip3 版本: $(pip3 --version | cut -d' ' -f2)"
else
    echo -e "${RED}❌ pip3 未安装${NC}"
fi
echo ""

# 检查 Docker 版本
echo -e "${YELLOW}🐳 Docker 兼容性检查${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    echo "✅ Docker 版本: $DOCKER_VERSION"
    
    # 检查版本是否满足要求 (>= 20.10.0)
    if [ "$(printf '%s\n' "20.10.0" "$DOCKER_VERSION" | sort -V | head -n1)" = "20.10.0" ]; then
        echo "✅ Docker 版本兼容"
    else
        echo -e "${RED}❌ Docker 版本过低，需要 >= 20.10.0${NC}"
    fi
    
    # 检查 Docker Compose
    if docker compose version &> /dev/null; then
        echo "✅ Docker Compose V2: $(docker compose version --short)"
    else
        echo -e "${RED}❌ Docker Compose V2 未安装${NC}"
    fi
    
    # 检查 Docker 服务状态
    if docker info &> /dev/null; then
        echo "✅ Docker 服务运行正常"
    else
        echo -e "${RED}❌ Docker 服务未运行${NC}"
    fi
else
    echo -e "${RED}❌ Docker 未安装${NC}"
fi
echo ""

# 检查端口可用性
echo -e "${YELLOW}🔌 端口兼容性检查${NC}"
check_port() {
    local port=$1
    local name=$2
    
    if command -v ss &> /dev/null; then
        if ss -tuln | grep ":$port " > /dev/null; then
            echo "⚠️ 端口 $port ($name): 已被占用"
        else
            echo "✅ 端口 $port ($name): 可用"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep ":$port " > /dev/null; then
            echo "⚠️ 端口 $port ($name): 已被占用"
        else
            echo "✅ 端口 $port ($name): 可用"
        fi
    else
        echo "⚠️ 无法检查端口状态 (ss/netstat 未安装)"
    fi
}

check_port 5000 "后端API"
check_port 5173 "前端开发"
check_port 80 "HTTP"
check_port 443 "HTTPS"
echo ""

# 检查磁盘空间
echo -e "${YELLOW}💾 磁盘空间检查${NC}"
if command -v df &> /dev/null; then
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    DISK_AVAIL=$(df -h . | awk 'NR==2 {print $4}')
    
    echo "磁盘使用率: ${DISK_USAGE}%"
    echo "可用空间: $DISK_AVAIL"
    
    if [ "$DISK_USAGE" -lt 80 ]; then
        echo "✅ 磁盘空间充足"
    else
        echo -e "${YELLOW}⚠️ 磁盘空间不足，建议清理${NC}"
    fi
else
    echo "⚠️ 无法检查磁盘空间"
fi
echo ""

# 检查内存
echo -e "${YELLOW}🧠 内存检查${NC}"
if command -v free &> /dev/null; then
    MEMORY_TOTAL=$(free -h | awk 'NR==2{print $2}')
    MEMORY_AVAIL=$(free -h | awk 'NR==2{print $7}')
    
    echo "总内存: $MEMORY_TOTAL"
    echo "可用内存: $MEMORY_AVAIL"
    
    # 简单检查是否有足够内存 (至少1GB)
    MEMORY_AVAIL_MB=$(free -m | awk 'NR==2{print $7}')
    if [ "$MEMORY_AVAIL_MB" -gt 1024 ]; then
        echo "✅ 内存充足"
    else
        echo -e "${YELLOW}⚠️ 可用内存较少，可能影响性能${NC}"
    fi
else
    echo "⚠️ 无法检查内存状态"
fi
echo ""

# 检查网络连接
echo -e "${YELLOW}🌐 网络连接检查${NC}"
if command -v curl &> /dev/null; then
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
        echo "✅ 互联网连接正常"
    else
        echo -e "${YELLOW}⚠️ 互联网连接异常${NC}"
    fi
    
    # 检查 Docker Hub 连接
    if curl -s --connect-timeout 5 https://hub.docker.com > /dev/null; then
        echo "✅ Docker Hub 连接正常"
    else
        echo -e "${YELLOW}⚠️ Docker Hub 连接异常${NC}"
    fi
else
    echo "⚠️ curl 未安装，无法检查网络连接"
fi
echo ""

# 前端依赖检查
echo -e "${YELLOW}📦 前端依赖兼容性检查${NC}"
if [ -f "frontend/package.json" ]; then
    echo "✅ package.json 存在"
    
    cd frontend
    if [ -f "package-lock.json" ]; then
        echo "✅ package-lock.json 存在"
    else
        echo "⚠️ package-lock.json 不存在"
    fi
    
    # 检查关键依赖
    if command -v node &> /dev/null && [ -f "package.json" ]; then
        echo "检查关键依赖版本:"
        node -e "
        const pkg = require('./package.json');
        const deps = pkg.dependencies || {};
        const devDeps = pkg.devDependencies || {};
        
        console.log('  Vue.js:', deps.vue || 'Not found');
        console.log('  Vue Router:', deps['vue-router'] || 'Not found');
        console.log('  Axios:', deps.axios || 'Not found');
        console.log('  Vite:', devDeps.vite || 'Not found');
        "
    fi
    cd ..
else
    echo -e "${RED}❌ frontend/package.json 不存在${NC}"
fi
echo ""

# 后端依赖检查
echo -e "${YELLOW}🐍 后端依赖兼容性检查${NC}"
if [ -f "backend/requirements.txt" ]; then
    echo "✅ requirements.txt 存在"
    echo "关键依赖版本:"
    grep -E "^(Flask|Flask-SQLAlchemy|Flask-CORS|gunicorn)" backend/requirements.txt || echo "  未找到关键依赖"
else
    echo -e "${RED}❌ backend/requirements.txt 不存在${NC}"
fi
echo ""

# 配置文件检查
echo -e "${YELLOW}⚙️ 配置文件检查${NC}"
config_files=(
    ".env.dev"
    ".env.production" 
    ".env.server"
    "docker-compose-http.yml"
    "nginx-http.conf"
    "nginx-domain.conf"
)

for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file 存在"
    else
        echo "⚠️ $file 不存在"
    fi
done
echo ""

# 部署脚本检查
echo -e "${YELLOW}🚀 部署脚本检查${NC}"
deploy_scripts=(
    "setup-server-environment.sh"
    "deploy-project.sh"
)

for script in "${deploy_scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "✅ $script 存在且可执行"
        else
            echo "⚠️ $script 存在但不可执行"
        fi
    else
        echo "❌ $script 不存在"
    fi
done
echo ""

# 总结
echo -e "${BLUE}📋 兼容性检查总结${NC}"
echo "============================================="
echo "✅ 表示通过检查"
echo "⚠️ 表示需要注意"
echo "❌ 表示需要修复"
echo ""
echo "详细兼容性信息请查看: COMPATIBILITY-REPORT.md"
echo ""
echo -e "${GREEN}🎉 兼容性检查完成！${NC}"