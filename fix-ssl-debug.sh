#!/bin/bash

# SSL证书申请诊断和修复脚本
# 用于解决 Certbot 验证失败问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 SSL证书申请诊断和修复脚本${NC}"
echo "=================================="

# 检查必要的环境变量
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ 错误: 请设置环境变量 DOMAIN 和 EMAIL${NC}"
    echo "示例:"
    echo "export DOMAIN=your-domain.com"
    echo "export EMAIL=your-email@example.com"
    exit 1
fi

echo -e "${GREEN}✅ 域名: $DOMAIN${NC}"
echo -e "${GREEN}✅ 邮箱: $EMAIL${NC}"
echo ""

# 1. 停止现有服务
echo -e "${YELLOW}🛑 停止现有服务...${NC}"
docker-compose -f docker-compose-https.yml down 2>/dev/null || true
docker stop $(docker ps -q) 2>/dev/null || true

# 2. 清理旧的容器和网络
echo -e "${YELLOW}🧹 清理旧的容器和网络...${NC}"
docker system prune -f

# 3. 创建最简单的HTTP-only配置
echo -e "${YELLOW}📝 创建最简单的HTTP配置...${NC}"
cat > nginx-debug.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name _;
        
        # Let's Encrypt验证路径
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }
        
        # 健康检查
        location /health {
            return 200 'Nginx is running for certificate verification';
            add_header Content-Type text/plain;
        }
        
        # 默认页面
        location / {
            return 200 'Certificate verification server is running';
            add_header Content-Type text/plain;
        }
    }
}
EOF

# 4. 创建最简单的Docker Compose配置
echo -e "${YELLOW}📝 创建调试用的Docker Compose配置...${NC}"
cat > docker-compose-debug.yml << EOF
version: '3.8'

services:
  nginx-debug:
    image: nginx:alpine
    container_name: nginx-debug
    ports:
      - "80:80"
    volumes:
      - ./nginx-debug.conf:/etc/nginx/nginx.conf:ro
      - certbot-www:/var/www/certbot
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    container_name: certbot-debug
    volumes:
      - certbot-certs:/etc/letsencrypt
      - certbot-www:/var/www/certbot
    command: echo "Certbot container ready"

volumes:
  certbot-certs:
  certbot-www:
EOF

# 5. 启动调试服务
echo -e "${YELLOW}🚀 启动调试服务...${NC}"
docker-compose -f docker-compose-debug.yml up -d nginx-debug

# 6. 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 10

# 7. 检查服务状态
echo -e "${BLUE}🔍 检查服务状态...${NC}"
docker-compose -f docker-compose-debug.yml ps

# 8. 测试本地HTTP访问
echo -e "${BLUE}🧪 测试本地HTTP访问...${NC}"
echo "测试健康检查端点:"
curl -s http://localhost/health || echo -e "${RED}❌ 本地HTTP访问失败${NC}"

echo ""
echo "测试证书验证路径:"
curl -s -I http://localhost/.well-known/acme-challenge/test || echo -e "${RED}❌ 证书验证路径访问失败${NC}"

# 9. 检查端口占用
echo -e "${BLUE}🔍 检查端口占用...${NC}"
netstat -tlnp | grep :80 || echo -e "${YELLOW}⚠️ 端口80未被占用${NC}"

# 10. 检查防火墙状态
echo -e "${BLUE}🔍 检查防火墙状态...${NC}"
ufw status || echo -e "${YELLOW}⚠️ 无法检查防火墙状态${NC}"

# 11. 测试域名解析
echo -e "${BLUE}🔍 测试域名解析...${NC}"
echo "域名 $DOMAIN 的DNS解析:"
nslookup $DOMAIN || echo -e "${RED}❌ 域名解析失败${NC}"

# 12. 测试外部访问
echo -e "${BLUE}🧪 测试外部HTTP访问...${NC}"
echo "测试从外部访问域名:"
curl -s -I http://$DOMAIN/health --connect-timeout 10 || echo -e "${RED}❌ 外部HTTP访问失败${NC}"

# 13. 创建测试文件
echo -e "${YELLOW}📝 创建测试验证文件...${NC}"
docker exec nginx-debug mkdir -p /var/www/certbot/.well-known/acme-challenge/
docker exec nginx-debug sh -c 'echo "test-verification-file" > /var/www/certbot/.well-known/acme-challenge/test'

# 14. 测试验证文件访问
echo -e "${BLUE}🧪 测试验证文件访问...${NC}"
echo "本地测试:"
curl -s http://localhost/.well-known/acme-challenge/test || echo -e "${RED}❌ 本地验证文件访问失败${NC}"

echo ""
echo "外部测试:"
curl -s http://$DOMAIN/.well-known/acme-challenge/test --connect-timeout 10 || echo -e "${RED}❌ 外部验证文件访问失败${NC}"

# 15. 尝试申请证书（干运行）
echo -e "${BLUE}🔐 尝试申请证书（干运行）...${NC}"
docker-compose -f docker-compose-debug.yml run --rm certbot \
    certonly --webroot \
    -w /var/www/certbot \
    --email $EMAIL \
    -d $DOMAIN \
    --agree-tos \
    --no-eff-email \
    --dry-run

# 16. 如果干运行成功，尝试真实申请
echo ""
read -p "干运行是否成功？是否继续真实申请？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🔐 开始真实证书申请...${NC}"
    docker-compose -f docker-compose-debug.yml run --rm certbot \
        certonly --webroot \
        -w /var/www/certbot \
        --email $EMAIL \
        -d $DOMAIN \
        --agree-tos \
        --no-eff-email \
        --force-renewal
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SSL证书申请成功！${NC}"
        echo ""
        echo "证书文件位置:"
        docker run --rm -v certbot-certs:/etc/letsencrypt alpine ls -la /etc/letsencrypt/live/$DOMAIN/ || true
    else
        echo -e "${RED}❌ SSL证书申请失败${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ 跳过真实证书申请${NC}"
fi

# 17. 清理调试环境
echo ""
read -p "是否清理调试环境？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🧹 清理调试环境...${NC}"
    docker-compose -f docker-compose-debug.yml down
    docker volume rm $(docker volume ls -q | grep certbot) 2>/dev/null || true
    rm -f nginx-debug.conf docker-compose-debug.yml
    echo -e "${GREEN}✅ 清理完成${NC}"
fi

echo ""
echo -e "${BLUE}🎉 诊断完成！${NC}"
echo ""
echo -e "${YELLOW}📋 诊断总结:${NC}"
echo "1. 如果本地HTTP访问失败，检查Docker和Nginx配置"
echo "2. 如果外部HTTP访问失败，检查域名DNS解析和防火墙设置"
echo "3. 如果验证文件访问失败，检查Nginx配置和文件权限"
echo "4. 如果干运行失败，检查Let's Encrypt的错误信息"
echo ""
echo -e "${GREEN}💡 建议:${NC}"
echo "- 确保域名 $DOMAIN 正确解析到此服务器IP"
echo "- 确保防火墙允许80和443端口访问"
echo "- 确保没有其他服务占用80端口"
echo "- 检查服务器的网络连接是否正常"