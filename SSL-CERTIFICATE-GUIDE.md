# SSL证书配置指南

本指南提供了为时光轴笔记项目配置SSL证书的详细说明，支持Let's Encrypt和自签名证书两种方式。

## 概述

SSL证书用于启用HTTPS，确保数据传输的安全性。本项目支持两种SSL证书配置方式：

1. **Let's Encrypt证书**（推荐）- 免费、自动续期、受浏览器信任
2. **自签名证书** - 适用于测试环境，会显示安全警告

## 前置条件

- 服务器已安装Docker和Docker Compose
- 拥有域名并已解析到服务器IP（Let's Encrypt需要）
- 服务器80和443端口已开放
- 具有root权限

## 方式一：Let's Encrypt证书（推荐）

### 1. 域名配置

确保您的域名已正确解析到服务器IP地址：

```bash
# 检查域名解析
nslookup your-domain.com
```

### 2. 使用自动化脚本

```bash
# 给脚本执行权限
chmod +x ssl-setup.sh

# 运行脚本
sudo ./ssl-setup.sh
```

选择选项1（Let's Encrypt），然后输入：
- 域名：your-domain.com
- 邮箱：your-email@example.com

### 3. 手动配置（可选）

如果不使用自动化脚本，可以手动配置：

```bash
# 安装certbot
sudo apt-get update
sudo apt-get install certbot

# 停止可能运行的web服务
sudo systemctl stop nginx apache2 2>/dev/null || true

# 生成证书
sudo certbot certonly --standalone \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  --domains your-domain.com

# 创建nginx SSL目录
sudo mkdir -p /etc/nginx/ssl

# 复制证书
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /etc/nginx/ssl/
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem /etc/nginx/ssl/

# 设置权限
sudo chmod 644 /etc/nginx/ssl/fullchain.pem
sudo chmod 600 /etc/nginx/ssl/privkey.pem
```

### 4. 自动续期设置

```bash
# 创建续期脚本
sudo tee /etc/cron.daily/certbot-renew > /dev/null << 'EOF'
#!/bin/bash
/usr/bin/certbot renew --quiet --post-hook "docker-compose -f /path/to/your/docker-compose.yml restart nginx"
EOF

# 设置执行权限
sudo chmod +x /etc/cron.daily/certbot-renew

# 测试续期
sudo certbot renew --dry-run
```

## 方式二：自签名证书

### 1. 使用自动化脚本

```bash
# 运行脚本
sudo ./ssl-setup.sh
```

选择选项2（自签名证书），然后输入域名或IP地址。

### 2. 手动生成

```bash
# 创建SSL目录
sudo mkdir -p /etc/nginx/ssl

# 生成私钥
sudo openssl genrsa -out /etc/nginx/ssl/privkey.pem 2048

# 生成证书
sudo openssl req -new -x509 -key /etc/nginx/ssl/privkey.pem \
  -out /etc/nginx/ssl/fullchain.pem -days 365 \
  -subj "/C=CN/ST=State/L=City/O=Organization/CN=your-domain.com"

# 设置权限
sudo chmod 644 /etc/nginx/ssl/fullchain.pem
sudo chmod 600 /etc/nginx/ssl/privkey.pem
```

## Docker Compose配置

### 1. 更新docker-compose.yml

确保nginx服务正确挂载SSL证书：

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"  # 添加HTTPS端口
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/nginx/ssl:/etc/nginx/ssl:ro  # 挂载SSL证书
      - nginx_cache:/var/cache/nginx
    depends_on:
      timeline-backend:
        condition: service_healthy
      timeline-frontend:
        condition: service_healthy
    networks:
      - timeline-network
```

### 2. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 检查服务状态
docker-compose ps

# 查看nginx日志
docker-compose logs nginx
```

## 验证SSL配置

### 1. 检查证书

```bash
# 检查证书信息
openssl x509 -in /etc/nginx/ssl/fullchain.pem -text -noout

# 检查证书有效期
openssl x509 -in /etc/nginx/ssl/fullchain.pem -noout -dates
```

### 2. 测试HTTPS连接

```bash
# 测试SSL连接
curl -I https://your-domain.com

# 检查SSL评级（在线工具）
# 访问：https://www.ssllabs.com/ssltest/
```

### 3. 浏览器测试

1. 访问 `https://your-domain.com`
2. 检查地址栏是否显示锁图标
3. 点击锁图标查看证书详情

## 故障排除

### 常见问题

1. **证书文件不存在**
   ```bash
   # 检查文件是否存在
   ls -la /etc/nginx/ssl/
   ```

2. **权限问题**
   ```bash
   # 修复权限
   sudo chown root:root /etc/nginx/ssl/*
   sudo chmod 644 /etc/nginx/ssl/fullchain.pem
   sudo chmod 600 /etc/nginx/ssl/privkey.pem
   ```

3. **端口被占用**
   ```bash
   # 检查端口占用
   sudo netstat -tlnp | grep :443
   
   # 停止占用端口的服务
   sudo systemctl stop nginx apache2
   ```

4. **域名解析问题**
   ```bash
   # 检查域名解析
   nslookup your-domain.com
   dig your-domain.com
   ```

### 日志检查

```bash
# 查看nginx错误日志
docker-compose logs nginx

# 查看certbot日志
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# 查看系统日志
sudo journalctl -u nginx
```

## 安全建议

### 1. SSL配置优化

- 使用强加密套件
- 启用HSTS（HTTP Strict Transport Security）
- 禁用不安全的SSL/TLS版本
- 定期更新证书

### 2. 防火墙配置

```bash
# 开放必要端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 3. 定期维护

- 监控证书到期时间
- 定期检查SSL配置
- 更新nginx和OpenSSL版本
- 备份证书文件

## 证书管理

### 备份证书

```bash
# 创建证书备份
sudo tar -czf ssl-backup-$(date +%Y%m%d).tar.gz /etc/nginx/ssl/
```

### 恢复证书

```bash
# 恢复证书备份
sudo tar -xzf ssl-backup-YYYYMMDD.tar.gz -C /
```

### 更新证书

```bash
# Let's Encrypt证书续期
sudo certbot renew

# 重启nginx
docker-compose restart nginx
```

## 总结

通过本指南，您可以为时光轴笔记项目配置安全的HTTPS访问。推荐使用Let's Encrypt证书，它免费、自动续期且受浏览器信任。配置完成后，用户可以通过HTTPS安全访问您的应用。

如果遇到问题，请参考故障排除部分或查看相关日志文件。