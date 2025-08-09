# 中文域名配置指南

## 🌐 域名信息

**你的中文域名**: `张伟爱刘新宇.com`  
**Punycode格式**: `xn--cpq55e94lgvdcukyqt.com`

## 🔧 配置说明

### 1. 域名解析配置
在你的域名注册商（如阿里云、腾讯云等）配置DNS解析：

```
类型: A记录
主机记录: @
记录值: 你的服务器IP地址
TTL: 600

类型: A记录  
主机记录: www
记录值: 你的服务器IP地址
TTL: 600
```

### 2. 服务器配置文件

#### `.env.server` 配置
```bash
# 域名配置（使用Punycode格式）
DOMAIN=xn--cpq55e94lgvdcukyqt.com
EMAIL=1159998925@qq.com
```

#### Docker Compose CORS配置
```yaml
environment:
  - CORS_ORIGINS=http://xn--cpq55e94lgvdcukyqt.com,http://张伟爱刘新宇.com,https://xn--cpq55e94lgvdcukyqt.com,https://张伟爱刘新宇.com
```

### 3. 部署命令

#### 使用自动化脚本部署
```bash
# 在服务器上运行
sudo ./deploy-project.sh xn--cpq55e94lgvdcukyqt.com 1159998925@qq.com
```

#### 使用Ansible部署
```bash
ansible-playbook -i inventory.yml ansible-deploy.yml \
  -e ansible_domain=xn--cpq55e94lgvdcukyqt.com \
  -e ansible_email=1159998925@qq.com
```

### 4. SSL证书配置

Let's Encrypt会自动为Punycode域名申请证书：
```bash
# 证书申请命令（自动执行）
certbot certonly --webroot \
  -w /var/www/certbot \
  -d xn--cpq55e94lgvdcukyqt.com \
  --email 1159998925@qq.com \
  --agree-tos \
  --no-eff-email
```

### 5. Nginx配置示例

```nginx
server {
    listen 80;
    server_name xn--cpq55e94lgvdcukyqt.com 张伟爱刘新宇.com;
    
    # 重定向到HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name xn--cpq55e94lgvdcukyqt.com 张伟爱刘新宇.com;
    
    # SSL证书配置
    ssl_certificate /etc/letsencrypt/live/xn--cpq55e94lgvdcukyqt.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/xn--cpq55e94lgvdcukyqt.com/privkey.pem;
    
    # 其他配置...
}
```

## 🔍 验证配置

### 1. 域名解析验证
```bash
# 检查域名解析
nslookup xn--cpq55e94lgvdcukyqt.com
dig xn--cpq55e94lgvdcukyqt.com

# 检查中文域名解析
nslookup 张伟爱刘新宇.com
```

### 2. 服务访问验证
```bash
# HTTP访问测试
curl -I http://xn--cpq55e94lgvdcukyqt.com
curl -I http://张伟爱刘新宇.com

# HTTPS访问测试（部署SSL后）
curl -I https://xn--cpq55e94lgvdcukyqt.com
curl -I https://张伟爱刘新宇.com
```

### 3. API测试
```bash
# 健康检查
curl http://xn--cpq55e94lgvdcukyqt.com/api/health

# 获取笔记列表
curl http://xn--cpq55e94lgvdcukyqt.com/api/notes
```

## ⚠️ 注意事项

1. **浏览器兼容性**: 现代浏览器都支持中文域名，会自动转换为Punycode
2. **服务器配置**: 服务器配置文件中统一使用Punycode格式
3. **SSL证书**: Let's Encrypt支持中文域名，但内部使用Punycode
4. **CORS配置**: 需要同时配置中文域名和Punycode格式
5. **DNS解析**: 域名注册商可能显示为Punycode格式

## 🚀 快速部署

1. **确保域名解析正确指向服务器IP**
2. **上传项目到服务器**:
   ```bash
   git clone https://github.com/z1159998925/timeline-notebook.git
   cd timeline-notebook
   ```

3. **运行环境配置**:
   ```bash
   sudo ./setup-server-environment.sh
   ```

4. **部署应用**:
   ```bash
   sudo ./deploy-project.sh xn--cpq55e94lgvdcukyqt.com 1159998925@qq.com
   ```

5. **访问应用**:
   - HTTP: http://张伟爱刘新宇.com
   - HTTPS: https://张伟爱刘新宇.com (SSL配置后)

## 📞 问题排查

如果遇到问题，请检查：
1. 域名解析是否正确
2. 服务器防火墙设置
3. Docker服务状态
4. 日志文件内容

```bash
# 查看服务状态
docker ps
docker logs timeline-backend
docker logs timeline-frontend

# 查看系统日志
journalctl -u docker
```