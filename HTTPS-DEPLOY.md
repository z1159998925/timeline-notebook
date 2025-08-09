# Timeline Notebook HTTPS自动化部署指南

## 🚀 一键HTTPS部署

### 前提条件
1. **域名准备**: 确保您有一个域名，并已将域名解析到服务器IP
2. **服务器要求**: Ubuntu 18.04+ 或 CentOS 7+
3. **端口开放**: 确保80和443端口可访问

### 🌟 一键部署命令

```bash
curl -fsSL https://raw.githubusercontent.com/z1159998925/timeline-notebook/main/deploy-https-auto.sh | sudo bash
```

### 📋 部署过程

脚本会自动完成以下步骤：

1. ✅ **系统更新** - 更新包管理器
2. ✅ **安装依赖** - Docker, Docker Compose, 基础工具
3. ✅ **获取代码** - 从GitHub克隆最新代码
4. ✅ **配置收集** - 交互式收集域名和邮箱
5. ✅ **HTTPS配置** - 使用模板自动生成nginx和Docker配置
6. ✅ **SSL证书申请** - 使用Let's Encrypt自动申请证书
7. ✅ **服务启动** - 启动完整的HTTPS服务
8. ✅ **自动更新设置** - 配置证书自动更新
9. ✅ **防火墙配置** - 开放必要端口

### 🔧 配置模板系统

部署脚本使用模板系统确保配置一致性：
- `nginx-https-template.conf` - Nginx HTTPS配置模板
- `docker-compose-https-template.yml` - Docker Compose配置模板
- 自动替换 `{{DOMAIN}}` 和 `{{EMAIL}}` 占位符

### 🔧 部署后管理

#### 创建管理员账户
```bash
docker exec -it timeline-backend python create_admin.py
```

#### 查看服务状态
```bash
cd /opt/timeline-notebook
docker-compose -f docker-compose-https.yml ps
```

#### 查看日志
```bash
# 查看所有服务日志
docker-compose -f docker-compose-https.yml logs

# 查看特定服务日志
docker-compose -f docker-compose-https.yml logs backend
docker-compose -f docker-compose-https.yml logs frontend
```

#### 重启服务
```bash
cd /opt/timeline-notebook
docker-compose -f docker-compose-https.yml restart
```

#### 停止服务
```bash
cd /opt/timeline-notebook
docker-compose -f docker-compose-https.yml down
```

#### 更新代码
```bash
cd /opt/timeline-notebook
git pull origin main
docker-compose -f docker-compose-https.yml up --build -d
```

### 🔐 SSL证书管理

#### 证书自动更新
- 系统已自动配置每日检查证书更新
- 无需手动干预，证书会在到期前自动更新

#### 手动更新证书
```bash
cd /opt/timeline-notebook
docker-compose -f docker-compose-https.yml run --rm certbot renew
docker-compose -f docker-compose-https.yml restart frontend
```

#### 查看证书状态
```bash
docker-compose -f docker-compose-https.yml run --rm certbot certificates
```

### 🛠️ 故障排除

#### 1. 域名解析问题
```bash
# 检查域名解析
nslookup your-domain.com
dig your-domain.com

# 确保域名指向服务器IP
```

#### 2. 证书申请失败
```bash
# 检查nginx配置
docker exec timeline-frontend nginx -t

# 查看certbot日志
docker-compose -f docker-compose-https.yml logs certbot
```

#### 3. 服务无法访问
```bash
# 检查防火墙
ufw status

# 检查端口占用
netstat -tlnp | grep :80
netstat -tlnp | grep :443

# 检查服务状态
docker-compose -f docker-compose-https.yml ps
```

#### 4. 重新申请证书
```bash
cd /opt/timeline-notebook
docker-compose -f docker-compose-https.yml run --rm certbot \
    certonly --webroot \
    -w /var/www/certbot \
    --email your-email@example.com \
    -d your-domain.com \
    --agree-tos \
    --force-renewal
```

### 📊 监控和维护

#### 系统资源监控
```bash
# 查看Docker资源使用
docker stats

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```

#### 日志管理
```bash
# 清理Docker日志
docker system prune -f

# 查看日志大小
du -sh /var/lib/docker/containers/*/*-json.log
```

### 🔄 备份和恢复

#### 备份数据
```bash
cd /opt/timeline-notebook
tar -czf backup-$(date +%Y%m%d).tar.gz data static/uploads
```

#### 恢复数据
```bash
cd /opt/timeline-notebook
tar -xzf backup-YYYYMMDD.tar.gz
docker-compose -f docker-compose-https.yml restart
```

### 📞 技术支持

如果遇到问题，请：

1. 查看部署日志
2. 检查服务状态
3. 确认域名解析
4. 验证防火墙设置

---

## 🎉 享受您的HTTPS Timeline Notebook！

部署完成后，您将拥有：
- ✅ 完全自动化的HTTPS网站
- ✅ 自动申请和更新的SSL证书
- ✅ 安全的数据传输
- ✅ 现代化的Web应用体验