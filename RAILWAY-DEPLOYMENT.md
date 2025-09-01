# Railway 后端部署指南

## 1. 准备工作

### 1.1 注册Railway账号
1. 访问 [Railway官网](https://railway.app)
2. 使用GitHub账号注册登录
3. 验证邮箱地址

### 1.2 准备代码
确保以下文件已创建并提交到Git仓库：
- `railway.json` - Railway配置文件
- `Procfile` - 进程配置文件
- `requirements.txt` - Python依赖文件
- `.env.example` - 环境变量示例

## 2. 部署步骤

### 2.1 创建新项目
1. 登录Railway控制台
2. 点击 "New Project"
3. 选择 "Deploy from GitHub repo"
4. 选择你的时光轴笔记本仓库

### 2.2 配置环境变量
在Railway项目设置中添加以下环境变量：

```
FLASK_ENV=production
FLASK_DEBUG=False
PORT=5000
DATABASE_URL=sqlite:///data/timeline.db
UPLOAD_FOLDER=static/uploads
MAX_CONTENT_LENGTH=16777216
CORS_ORIGINS=*
```

### 2.3 部署配置
1. Railway会自动检测到Python项目
2. 使用 `requirements.txt` 安装依赖
3. 使用 `Procfile` 或 `railway.json` 中的启动命令
4. 自动分配域名和端口

### 2.4 等待部署完成
1. 查看部署日志
2. 确认服务启动成功
3. 记录分配的域名（格式：`https://your-app-name.railway.app`）

## 3. 验证部署

### 3.1 健康检查
访问以下URL验证服务状态：
```
https://your-app-name.railway.app/health
```

应该返回：
```json
{
  "status": "healthy",
  "message": "Timeline Notebook API is running"
}
```

### 3.2 API测试
测试主要API端点：
```bash
# 获取时间轴数据
curl https://your-app-name.railway.app/api/timeline

# 获取时光胶囊数据
curl https://your-app-name.railway.app/api/capsules

# 登录状态检查
curl https://your-app-name.railway.app/api/login-status
```

## 4. 常见问题

### 4.1 部署失败
- 检查 `requirements.txt` 是否包含所有依赖
- 确认 `railway.json` 配置正确
- 查看部署日志中的错误信息

### 4.2 数据库问题
- SQLite文件会在首次运行时自动创建
- 确保 `data` 目录有写入权限
- 检查数据库初始化是否成功

### 4.3 CORS错误
- 确认 `CORS_ORIGINS` 环境变量设置正确
- 在前端配置中使用正确的后端域名

## 5. 监控和维护

### 5.1 查看日志
在Railway控制台中可以实时查看应用日志

### 5.2 重新部署
- 推送新代码到GitHub会自动触发重新部署
- 也可以在Railway控制台手动触发部署

### 5.3 环境变量更新
在Railway控制台的Variables标签页中可以更新环境变量

## 6. 下一步

部署成功后，记录Railway分配的域名，然后：
1. 更新前端API配置
2. 重新部署前端到Vercel
3. 验证完整功能

---

**重要提示**：
- Railway提供免费额度，超出后需要付费
- 建议设置使用限制避免意外费用
- 定期备份数据库文件