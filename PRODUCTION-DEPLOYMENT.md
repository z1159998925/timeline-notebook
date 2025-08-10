# Timeline Notebook 生产环境部署指南

## 🎯 部署前检查清单

### ✅ 配置验证
- [x] Nginx配置完整性检查
- [x] 后端路由匹配验证
- [x] 静态文件服务配置
- [x] Docker Compose配置
- [x] CORS安全策略
- [x] 环境变量配置

### ✅ 安全配置
- [x] HTTPS强制重定向
- [x] 安全HTTP头设置
- [x] CORS严格策略
- [x] 文件上传限制
- [x] 路径遍历防护
- [x] 环境变量验证

## 🚀 部署步骤

### 1. 环境准备

```bash
# 克隆项目
git clone <your-repository>
cd timeline-notebook

# 确保Docker和Docker Compose已安装
docker --version
docker-compose --version
```

### 2. 环境变量配置

编辑 `.env.production` 文件：

```bash
# 生产环境配置
FLASK_ENV=production
SECRET_KEY=your-super-secret-key-change-this-immediately
DATABASE_URL=sqlite:///data/timeline.db
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=104857600

# 域名配置（必须设置）
DOMAIN=yourdomain.com

# CORS配置
CORS_ORIGINS=https://yourdomain.com

# 日志配置
LOG_LEVEL=WARNING

# 安全配置
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_SAMESITE=Lax
```

**重要提醒：**
- 必须更改 `SECRET_KEY` 为强密码
- 必须设置正确的 `DOMAIN`
- 必须配置 `CORS_ORIGINS` 为实际域名

### 3. 运行配置验证

```bash
# 运行生产环境验证脚本
python production-validation.py

# 运行nginx和后端匹配性检查
python nginx-backend-check.py
```

确保所有检查都通过（100%）。

### 4. 构建和启动服务

```bash
# 构建Docker镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 5. 验证部署

```bash
# 检查健康状态
curl http://localhost/health

# 检查API响应
curl http://localhost/api/timeline

# 检查静态文件服务
curl http://localhost/static/uploads/
```

## 🔧 配置详解

### Nginx配置特性

- **反向代理**: 前端静态文件 + 后端API代理
- **缓存策略**: 静态资源1年缓存，API无缓存
- **安全头**: X-Frame-Options, X-Content-Type-Options等
- **Gzip压缩**: 减少传输大小
- **健康检查**: 后端服务健康监控
- **文件上传**: 支持100MB文件上传

### 后端配置特性

- **生产环境优化**: 强制生产模式，禁用调试
- **安全配置**: 环境变量验证，路径遍历防护
- **CORS管理**: 动态CORS策略，域名验证
- **文件处理**: 安全的文件上传和访问
- **健康检查**: 数据库连接监控
- **日志管理**: 生产环境日志配置

### Docker配置特性

- **多阶段构建**: 优化镜像大小
- **健康检查**: 容器健康监控
- **卷挂载**: 数据持久化
- **网络隔离**: 服务间安全通信
- **重启策略**: 自动故障恢复

## 🛡️ 安全最佳实践

### 1. 密钥管理
- 使用强随机SECRET_KEY
- 定期轮换密钥
- 不要在代码中硬编码密钥

### 2. 域名配置
- 配置正确的DOMAIN环境变量
- 使用HTTPS（推荐配置SSL证书）
- 配置严格的CORS策略

### 3. 文件安全
- 限制上传文件类型和大小
- 使用UUID重命名上传文件
- 防止路径遍历攻击

### 4. 网络安全
- 使用Docker网络隔离
- 配置防火墙规则
- 定期更新依赖包

## 📊 监控和维护

### 健康检查端点

- **前端**: `GET /` - 返回200表示正常
- **后端**: `GET /health` - 检查数据库连接
- **API**: `GET /api/timeline` - 检查API服务

### 日志管理

```bash
# 查看实时日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs backend
docker-compose logs frontend

# 日志文件位置
./logs/app.log
```

### 数据备份

```bash
# 备份数据库
docker-compose exec backend python -c "
from backend.routes import create_backup
create_backup()
"

# 备份上传文件
tar -czf uploads-backup.tar.gz ./uploads/
```

## 🔄 更新部署

```bash
# 拉取最新代码
git pull

# 重新构建镜像
docker-compose build

# 重启服务
docker-compose down
docker-compose up -d

# 验证更新
python nginx-backend-check.py
```

## 🚨 故障排除

### 常见问题

1. **CORS错误**
   - 检查DOMAIN和CORS_ORIGINS配置
   - 确保域名匹配

2. **文件上传失败**
   - 检查MAX_CONTENT_LENGTH设置
   - 确保uploads目录权限正确

3. **数据库连接失败**
   - 检查DATABASE_URL配置
   - 确保data目录存在且可写

4. **静态文件404**
   - 检查nginx配置
   - 确保Flask静态文件路由正确

### 调试命令

```bash
# 进入容器调试
docker-compose exec backend bash
docker-compose exec frontend bash

# 检查容器状态
docker-compose ps
docker stats

# 重置服务
docker-compose down -v
docker-compose up -d
```

## 📞 支持

如果遇到问题，请：

1. 运行 `nginx-backend-check.py` 检查配置
2. 运行 `production-validation.py` 验证环境
3. 查看日志文件排查错误
4. 检查环境变量配置

---

**部署成功标志**: 所有检查脚本返回100%通过率，服务正常响应健康检查。