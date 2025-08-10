#!/bin/bash

# Timeline Notebook 生产环境检查脚本
# 验证是否符合生产环境最佳实践

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Timeline Notebook 生产环境检查${NC}"
echo "============================================="

# 检查计数器
PASS=0
FAIL=0
WARN=0

# 检查函数
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASS++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAIL++))
}

check_warn() {
    echo -e "${YELLOW}⚠️ $1${NC}"
    ((WARN++))
}

echo -e "${YELLOW}🛡️ 一、安全类配置检查${NC}"
echo "-----------------------------------"

# 1. 检查调试模式
if grep -q "debug=False" backend/app_production.py; then
    check_pass "调试模式已关闭"
else
    check_fail "调试模式未正确关闭"
fi

# 2. 检查密钥配置
if [ -f ".env.production" ]; then
    if grep -q "SECRET_KEY=" .env.production && ! grep -q "your-production-secret-key-here-change-this" .env.production; then
        check_pass "生产环境密钥已配置"
    else
        check_fail "生产环境密钥未正确配置"
    fi
else
    check_fail "缺少 .env.production 文件"
fi

# 3. 检查CORS配置
if grep -q "cors_origins.*DOMAIN" backend/app_production.py; then
    check_pass "CORS配置已限制到指定域名"
else
    check_warn "CORS配置可能过于宽松"
fi

# 4. 检查敏感信息
if grep -rq "localhost:5000" frontend/src/ --exclude-dir=node_modules; then
    check_warn "前端代码中仍有硬编码的localhost地址"
else
    check_pass "前端代码中无硬编码地址"
fi

echo ""
echo -e "${YELLOW}⚙️ 二、性能优化检查${NC}"
echo "-----------------------------------"

# 1. 检查前端构建配置
if [ -f "frontend/vite.config.production.js" ]; then
    if grep -q "sourcemap: false" frontend/vite.config.production.js; then
        check_pass "生产环境已关闭sourcemap"
    else
        check_warn "建议在生产环境关闭sourcemap"
    fi
    
    if grep -q "drop_console: true" frontend/vite.config.production.js; then
        check_pass "生产环境已移除console.log"
    else
        check_warn "建议在生产环境移除console.log"
    fi
else
    check_warn "缺少生产环境前端配置文件"
fi

# 2. 检查后端服务器配置
if [ -f "backend/wsgi_production.py" ]; then
    check_pass "已配置生产环境WSGI入口"
else
    check_fail "缺少生产环境WSGI配置"
fi

# 3. 检查Gunicorn配置
if grep -q "gunicorn" Dockerfile.backend.production 2>/dev/null; then
    check_pass "已配置Gunicorn生产服务器"
else
    check_warn "建议使用Gunicorn作为生产服务器"
fi

echo ""
echo -e "${YELLOW}🔌 三、环境适配检查${NC}"
echo "-----------------------------------"

# 1. 检查环境变量配置
if [ -f "frontend/.env.production" ]; then
    check_pass "前端生产环境变量已配置"
else
    check_warn "缺少前端生产环境变量文件"
fi

# 2. 检查API地址配置
if grep -q "import.meta.env.MODE" frontend/src/axios.js 2>/dev/null; then
    check_pass "API地址已配置环境自适应"
else
    check_warn "API地址配置可能需要优化"
fi

# 3. 检查静态文件路径
if grep -q "getMediaUrl" frontend/src/ -r 2>/dev/null; then
    check_pass "媒体文件URL已配置动态生成"
else
    check_warn "媒体文件URL可能需要优化"
fi

echo ""
echo -e "${YELLOW}📦 四、部署相关检查${NC}"
echo "-----------------------------------"

# 1. 检查依赖文件
if [ -f "backend/requirements.txt" ]; then
    check_pass "后端依赖文件存在"
else
    check_fail "缺少后端依赖文件"
fi

if [ -f "frontend/package.json" ]; then
    check_pass "前端依赖文件存在"
else
    check_fail "缺少前端依赖文件"
fi

# 2. 检查Docker配置
if [ -f "Dockerfile.backend.production" ]; then
    check_pass "生产环境后端Dockerfile已配置"
else
    check_warn "缺少生产环境后端Dockerfile"
fi

if [ -f "Dockerfile.frontend.production" ]; then
    check_pass "生产环境前端Dockerfile已配置"
else
    check_warn "缺少生产环境前端Dockerfile"
fi

# 3. 检查Docker Compose
if [ -f "docker-compose.production.yml" ]; then
    check_pass "生产环境Docker Compose已配置"
else
    check_warn "缺少生产环境Docker Compose配置"
fi

# 4. 检查日志配置
if grep -q "RotatingFileHandler" backend/app_production.py 2>/dev/null; then
    check_pass "已配置日志轮转"
else
    check_warn "建议配置日志轮转"
fi

echo ""
echo -e "${YELLOW}🔄 五、自动化配置检查${NC}"
echo "-----------------------------------"

# 1. 检查部署脚本
if [ -f "production-deploy.sh" ]; then
    check_pass "生产环境部署脚本已准备"
else
    check_warn "缺少生产环境部署脚本"
fi

# 2. 检查环境切换
if [ -f ".env.production" ] && [ -f ".env.server" ]; then
    check_pass "环境配置文件已分离"
else
    check_warn "建议分离不同环境的配置文件"
fi

echo ""
echo -e "${YELLOW}📝 六、文件结构检查${NC}"
echo "-----------------------------------"

# 检查必要目录
for dir in "data" "static/uploads" "logs"; do
    if [ -d "$dir" ]; then
        check_pass "目录 $dir 已存在"
    else
        check_warn "目录 $dir 不存在，部署时会自动创建"
    fi
done

# 检查权限（如果在Linux环境）
if [ "$(uname)" = "Linux" ]; then
    if [ -d "data" ] && [ "$(stat -c %a data)" = "755" ]; then
        check_pass "数据目录权限正确"
    else
        check_warn "数据目录权限可能需要调整"
    fi
fi

echo ""
echo "============================================="
echo -e "${BLUE}📊 检查结果汇总${NC}"
echo "-----------------------------------"
echo -e "${GREEN}✅ 通过: $PASS 项${NC}"
echo -e "${YELLOW}⚠️ 警告: $WARN 项${NC}"
echo -e "${RED}❌ 失败: $FAIL 项${NC}"

echo ""
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 恭喜！您的应用已准备好部署到生产环境！${NC}"
    echo ""
    echo -e "${BLUE}📋 建议的部署步骤：${NC}"
    echo "1. 运行: chmod +x production-deploy.sh"
    echo "2. 执行: ./production-deploy.sh your-domain.com your-email@example.com"
    echo "3. 配置HTTPS证书"
    echo "4. 设置域名DNS解析"
    echo "5. 配置防火墙和监控"
else
    echo -e "${RED}⚠️ 发现 $FAIL 个严重问题，建议修复后再部署${NC}"
    echo ""
    echo -e "${YELLOW}📝 修复建议：${NC}"
    echo "1. 检查上述失败项目"
    echo "2. 确保所有必要文件存在"
    echo "3. 验证配置文件正确性"
    echo "4. 重新运行此检查脚本"
fi

if [ $WARN -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}💡 优化建议：${NC}"
    echo "虽然有 $WARN 个警告项，但不影响基本部署"
    echo "建议在部署后逐步优化这些项目"
fi

echo ""