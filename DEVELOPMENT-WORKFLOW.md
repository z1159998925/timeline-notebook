# 开发工作流程指南

## 🔄 本地开发到生产部署完整流程

### 1. 本地开发环境设置

```bash
# 启动本地开发环境
start-dev.bat

# 访问地址
前端: http://localhost
后端: http://localhost:5000
```

### 2. 代码修改和测试

#### 后端代码修改
- 修改 `backend/` 目录下的任何文件
- 容器会自动重载，立即生效
- 在 http://localhost:5000 测试API

#### 前端代码修改  
- 修改 `frontend/` 目录下的任何文件
- Vite会自动热重载
- 在 http://localhost 查看效果

#### 配置修改
- 开发环境配置: 修改 `.env.dev`
- 生产环境配置: 修改 `.env.server`

### 3. 代码同步到生产环境

#### 方法一: 使用上传脚本（推荐）
```bash
# 停止本地开发环境（可选）
stop-dev.bat

# 上传代码到服务器
upload-to-server.bat

# 在服务器执行部署
ssh user@your-server
cd /path/to/timeline-notebook
./deploy-server.sh
```

#### 方法二: 手动上传
```bash
# 使用scp上传修改的文件
scp -r backend/ user@server:/path/to/timeline-notebook/
scp -r frontend/ user@server:/path/to/timeline-notebook/

# 在服务器重新部署
ssh user@server
cd /path/to/timeline-notebook
docker-compose -f docker-compose-server.yml up --build -d
```

### 4. 验证部署结果

```bash
# 检查服务状态
docker-compose -f docker-compose-server.yml ps

# 查看日志
docker-compose -f docker-compose-server.yml logs -f

# 访问生产环境
https://your-domain.com
```

## 🎯 开发最佳实践

### 代码修改流程
1. **本地开发** → 修改代码
2. **本地测试** → 验证功能
3. **上传代码** → 同步到服务器
4. **生产部署** → 重新构建容器
5. **验证结果** → 确认部署成功

### 环境配置管理
- **开发环境**: 使用 `.env.dev` 和 `docker-compose.dev.yml`
- **生产环境**: 使用 `.env.server` 和 `docker-compose-server.yml`
- **配置隔离**: 两个环境完全独立，互不影响

### 常用命令

#### 本地开发
```bash
# 启动开发环境
start-dev.bat

# 停止开发环境
stop-dev.bat

# 查看开发环境日志
docker-compose -f docker-compose.dev.yml logs -f

# 重建开发环境
docker-compose -f docker-compose.dev.yml up --build --force-recreate
```

#### 生产部署
```bash
# 上传代码
upload-to-server.bat

# 服务器部署（在服务器上执行）
./deploy-server.sh

# 查看生产环境状态（在服务器上执行）
docker-compose -f docker-compose-server.yml ps
docker-compose -f docker-compose-server.yml logs -f
```

## 🔧 故障排除

### 本地开发问题
```bash
# 端口被占用
netstat -ano | findstr :5000
taskkill /PID <PID> /F

# 容器启动失败
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml up --build --force-recreate
```

### 生产部署问题
```bash
# 检查服务器磁盘空间
df -h

# 清理Docker缓存
docker system prune -f

# 重新部署
./deploy-server.sh
```

## 📝 注意事项

1. **代码同步**: 本地修改的代码需要手动上传到服务器
2. **环境配置**: 开发和生产环境使用不同的配置文件
3. **数据库**: 开发和生产环境使用独立的数据库文件
4. **SSL证书**: 只有生产环境配置了HTTPS
5. **域名访问**: 生产环境需要正确配置域名解析

## 🚀 快速参考

| 操作 | 本地开发 | 生产环境 |
|------|----------|----------|
| 启动 | `start-dev.bat` | `./deploy-server.sh` |
| 停止 | `stop-dev.bat` | `docker-compose -f docker-compose-server.yml down` |
| 日志 | `docker-compose -f docker-compose.dev.yml logs -f` | `docker-compose -f docker-compose-server.yml logs -f` |
| 访问 | http://localhost | https://your-domain.com |
| 配置 | `.env.dev` | `.env.server` |