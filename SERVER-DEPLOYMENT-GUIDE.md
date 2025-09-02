# 时光轴笔记本 - 服务器容器化部署指南

## 概述

本指南将帮助您在自己的服务器上使用Docker容器化部署时光轴笔记本项目。支持HTTP和HTTPS两种部署方式。

## 系统要求

### 最低配置
- **CPU**: 1核心
- **内存**: 2GB RAM
- **存储**: 10GB 可用空间
- **操作系统**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+

### 推荐配置
- **CPU**: 2核心或更多
- **内存**: 4GB RAM 或更多
- **存储**: 20GB 可用空间或更多
- **网络**: 稳定的互联网连接

## 前置条件

### 1. 安装Docker

#### Ubuntu/Debian
```bash
# 更新包索引
sudo apt update

# 安装必要的包
sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release

# 添加Docker官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置稳定版仓库
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装Docker Engine
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker
```

#### CentOS/RHEL
```bash
# 安装必要的包
sudo yum install -y yum-utils

# 设置Docker仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker Engine
sudo yum install docker-ce docker-ce-cli containerd.io

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker
```

### 2. 安装Docker Compose

```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### 3. 配置防火墙

#### Ubuntu/Debian (UFW)
```bash
# 允许HTTP和HTTPS流量
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp  # SSH访问
sudo ufw enable
```

#### CentOS/RHEL (firewalld)
```bash
# 允许HTTP和HTTPS流量
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

## 部署步骤

### 1. 获取项目代码

```bash
# 克隆项目
git clone <your-repository-url>
cd timeline-notebook

# 或者上传项目文件到服务器
```

### 2. 环境配置

#### 复制并编辑环境配置文件
```bash
cp .env.production .env.production.local
```

#### 编辑配置文件
```bash
nano .env.production.local
```

**重要配置项**:
```env
# 生产环境配置
FLASK_ENV=production
SECRET_KEY=your-very-secure-secret-key-here
DATABASE_URL=sqlite:///data/timeline.db
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=104857600

# 域名配置（必须设置为您的实际域名）
DOMAIN=yourdomain.com

# CORS配置
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# 日志配置
LOG_LEVEL=WARNING

# 安全配置
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_SAMESITE=Lax
```

### 3. 创建必要的目录

```bash
# 创建数据目录
mkdir -p data static/uploads logs ssl

# 设置权限
sudo chown -R $USER:$USER data static/uploads logs
chmod -R 755 data static/uploads logs
```

### 4. 选择部署方式

#### 方式一：HTTP部署（快速开始）

适用于测试环境或内网部署：

```bash
# 使用HTTP版本的docker-compose
docker-compose -f docker-compose-http.yml up -d
```

#### 方式二：HTTPS部署（生产环境推荐）

需要先配置SSL证书（见下文SSL配置部分）：

```bash
# 使用完整版本的docker-compose
docker-compose up -d
```

### 5. 验证部署

#### 检查容器状态
```bash
# 查看容器状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

#### 健康检查
```bash
# 检查后端健康状态
curl http://localhost:5000/health

# 检查前端访问
curl http://localhost/health
```

#### 访问应用
- HTTP访问: `http://your-server-ip`
- HTTPS访问: `https://your-domain.com`

## SSL证书配置

### 方式一：Let's Encrypt（推荐）

#### 1. 安装Certbot
```bash
# Ubuntu/Debian
sudo apt install certbot

# CentOS/RHEL
sudo yum install certbot
```

#### 2. 获取SSL证书
```bash
# 停止现有服务（如果正在运行）
docker-compose down

# 获取证书
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./ssl/
sudo chown $USER:$USER ./ssl/*
```

#### 3. 设置自动续期
```bash
# 添加crontab任务
sudo crontab -e

# 添加以下行（每月1号凌晨2点检查续期）
0 2 1 * * /usr/bin/certbot renew --quiet && docker-compose restart nginx
```

### 方式二：自签名证书（测试用）

```bash
# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./ssl/privkey.pem \
  -out ./ssl/fullchain.pem \
  -subj "/C=CN/ST=State/L=City/O=Organization/CN=yourdomain.com"
```

## 监控和维护

### 日志管理

```bash
# 查看实时日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f nginx

# 清理日志
docker system prune -f
```

### 备份数据

```bash
# 创建备份脚本
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/timeline-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# 备份数据库
cp -r ./data $BACKUP_DIR/

# 备份上传文件
cp -r ./static/uploads $BACKUP_DIR/

# 备份配置文件
cp .env.production.local $BACKUP_DIR/

echo "备份完成: $BACKUP_DIR"
EOF

chmod +x backup.sh

# 设置定期备份
(crontab -l 2>/dev/null; echo "0 2 * * * /path/to/your/project/backup.sh") | crontab -
```

### 更新应用

```bash
# 拉取最新代码
git pull origin main

# 重新构建并启动
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# 清理旧镜像
docker image prune -f
```

### 性能优化

#### 1. 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

#### 2. Docker优化
```bash
# 配置Docker日志轮转
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

## 故障排除

### 常见问题

#### 1. 容器启动失败
```bash
# 查看详细错误信息
docker-compose logs

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

#### 2. 数据库连接问题
```bash
# 检查数据目录权限
ls -la data/

# 重新初始化数据库
docker-compose exec backend python init_db.py
```

#### 3. 文件上传问题
```bash
# 检查上传目录权限
ls -la static/uploads/

# 修复权限
sudo chown -R 1000:1000 static/uploads/
chmod -R 755 static/uploads/
```

#### 4. SSL证书问题
```bash
# 检查证书文件
ls -la ssl/

# 验证证书
openssl x509 -in ssl/fullchain.pem -text -noout
```

### 性能监控

```bash
# 监控容器资源使用
docker stats

# 监控系统资源
htop
df -h
free -h
```

## 安全建议

1. **定期更新系统和Docker**
2. **使用强密码和密钥**
3. **配置防火墙规则**
4. **定期备份数据**
5. **监控系统日志**
6. **使用HTTPS加密**
7. **限制SSH访问**

## 支持

如果遇到问题，请检查：
1. 系统日志: `journalctl -u docker`
2. 容器日志: `docker-compose logs`
3. 应用日志: `./logs/`目录下的文件

---

**部署完成后，您的时光轴笔记本应用就可以通过您的域名访问了！**