# 🚀 Timeline Notebook 服务器部署指南

## 📋 部署前准备

### 1. 服务器要求
- **操作系统**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **内存**: 最少 2GB RAM (推荐 4GB+)
- **存储**: 最少 20GB 可用空间
- **网络**: 公网IP地址，开放 80 和 443 端口

### 2. 必需软件安装

#### 安装 Docker 和 Docker Compose
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用用户组更改
exit
```

#### 安装其他必需工具
```bash
sudo apt update
sudo apt install -y git curl wget nano
```

## 📁 代码部署

### 1. 上传代码到服务器
```bash
# 方法1: 使用 Git (推荐)
git clone <你的仓库地址>
cd timeline-notebook

# 方法2: 使用 SCP 上传
# 在本地执行:
scp -r timeline-notebook/ user@your-server-ip:/home/user/
```

### 2. 设置文件权限
```bash
chmod +x production-deploy.sh
chmod +x generate-ssl.sh
```

## ⚙️ 配置部署

### 1. 运行自动部署脚本
```bash
./production-deploy.sh
```

脚本会提示你输入:
- **域名**: 你的服务器域名 (如: example.com)
- **邮箱**: 用于SSL证书申请的邮箱

### 2. 手动配置 (可选)

如果自动脚本失败，可以手动配置:

#### 创建 .env.production 文件
```bash
cat > .env.production << 'EOF'
# Flask配置
FLASK_ENV=production
SECRET_KEY=your-super-secret-key-here
DATABASE_URL=sqlite:///data/timeline.db

# 文件上传配置
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=104857600

# 域名和CORS配置
DOMAIN=your-domain.com
CORS_ORIGINS=https://your-domain.com,http://your-domain.com

# 日志配置
LOG_LEVEL=INFO

# Session配置
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_SAMESITE=Lax
EOF
```

#### 生成安全密钥
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
# 将生成的密钥替换 .env.production 中的 SECRET_KEY
```

## 🚀 启动服务

### 1. 构建和启动容器
```bash
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 2. 验证部署
```bash
# 检查容器状态
docker-compose logs

# 检查健康状态
curl http://localhost/health
curl http://localhost/api/health

# 检查前端
curl http://localhost/
```

## 🔒 SSL证书配置

### 方法1: 使用 Let's Encrypt (推荐)
```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 申请证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo crontab -e
# 添加以下行:
0 12 * * * /usr/bin/certbot renew --quiet
```

### 方法2: 使用自签名证书 (仅测试)
```bash
./generate-ssl.sh
```

## 🔧 生产环境优化

### 1. 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65536" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 2. 防火墙配置
```bash
# Ubuntu UFW
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# CentOS Firewalld
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 3. 监控和日志
```bash
# 查看应用日志
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f nginx

# 设置日志轮转
sudo nano /etc/logrotate.d/docker-compose
```

## 📊 监控和维护

### 1. 健康检查
```bash
# 创建健康检查脚本
cat > health-check.sh << 'EOF'
#!/bin/bash
echo "=== Timeline Notebook 健康检查 ==="
echo "时间: $(date)"

# 检查容器状态
echo "--- 容器状态 ---"
docker-compose ps

# 检查健康端点
echo "--- 健康端点 ---"
curl -s http://localhost/health || echo "❌ 前端健康检查失败"
curl -s http://localhost/api/health || echo "❌ 后端健康检查失败"

# 检查磁盘空间
echo "--- 磁盘空间 ---"
df -h

# 检查内存使用
echo "--- 内存使用 ---"
free -h
EOF

chmod +x health-check.sh
```

### 2. 备份脚本
```bash
# 创建备份脚本
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/timeline-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# 备份数据库
docker-compose exec -T backend sqlite3 /app/data/timeline.db ".backup /app/data/backup.db"
docker cp timeline-backend:/app/data/backup.db $BACKUP_DIR/

# 备份上传文件
docker cp timeline-backend:/app/static/uploads $BACKUP_DIR/

# 备份配置文件
cp .env.production $BACKUP_DIR/
cp docker-compose.yml $BACKUP_DIR/

echo "备份完成: $BACKUP_DIR"
EOF

chmod +x backup.sh
```

### 3. 自动更新脚本
```bash
# 创建更新脚本
cat > update.sh << 'EOF'
#!/bin/bash
echo "🔄 更新 Timeline Notebook..."

# 备份当前版本
./backup.sh

# 拉取最新代码
git pull origin main

# 重新构建和部署
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "✅ 更新完成"
EOF

chmod +x update.sh
```

## 🔍 故障排除

### 常见问题

1. **容器启动失败**
```bash
# 查看详细日志
docker-compose logs backend
docker-compose logs frontend

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

2. **数据库连接失败**
```bash
# 检查数据库文件权限
docker-compose exec backend ls -la /app/data/

# 重新创建数据库
docker-compose exec backend python init_db.py
```

3. **静态文件无法访问**
```bash
# 检查文件权限
docker-compose exec backend ls -la /app/static/

# 重新设置权限
docker-compose exec backend chmod -R 755 /app/static/
```

4. **CORS 错误**
```bash
# 检查 CORS 配置
docker-compose exec backend cat cors_config.py

# 更新域名配置
nano .env.production
# 修改 CORS_ORIGINS 和 DOMAIN
docker-compose restart
```

## 📞 技术支持

如果遇到问题:
1. 查看日志: `docker-compose logs`
2. 检查配置: `cat .env.production`
3. 运行健康检查: `./health-check.sh`
4. 查看系统资源: `htop` 或 `top`

## 🎉 部署完成

部署成功后，你可以通过以下方式访问应用:
- **HTTP**: http://your-domain.com
- **HTTPS**: https://your-domain.com (如果配置了SSL)

记得定期运行备份和健康检查脚本！