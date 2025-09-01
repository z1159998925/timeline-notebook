# 前端 API 配置更新指南

## 概述

本文档说明如何在 Railway 后端部署完成后，更新前端的 API 配置以连接到生产环境的后端服务。

## 配置文件说明

### 1. 环境变量文件

- **`.env`** - 开发环境配置（本地开发使用）
- **`.env.production`** - 生产环境配置（Vercel 部署使用）

### 2. 环境管理器

- **`src/utils/environment.js`** - 统一的环境配置管理
- 自动检测运行环境并加载相应配置
- 支持环境变量覆盖

## 更新步骤

### 步骤 1: 获取 Railway 应用 URL

1. 登录 Railway 控制台
2. 找到已部署的后端应用
3. 复制应用的公开 URL（格式：`https://your-app-name.railway.app`）

### 步骤 2: 更新生产环境配置

编辑 `frontend/.env.production` 文件：

```env
# 将 your-railway-app 替换为实际的 Railway 应用名称
VITE_API_BASE_URL=https://your-actual-app-name.railway.app/api
VITE_MEDIA_BASE_URL=https://your-actual-app-name.railway.app/static
VITE_WS_BASE_URL=wss://your-actual-app-name.railway.app
VITE_APP_ENV=production
VITE_DEBUG=false
```

### 步骤 3: 更新环境管理器默认配置

编辑 `frontend/src/utils/environment.js` 文件中的生产环境配置：

```javascript
production: {
  apiBaseURL: 'https://your-actual-app-name.railway.app/api',
  mediaBaseURL: 'https://your-actual-app-name.railway.app/static',
  wsBaseURL: 'wss://your-actual-app-name.railway.app',
  timeout: 5000,
  withCredentials: true,
  debug: false,
  logLevel: 'error'
}
```

### 步骤 4: 验证配置

在本地测试生产环境配置：

```bash
cd frontend
npm run build
npm run preview
```

## Vercel 环境变量配置

在 Vercel 项目设置中添加环境变量：

1. 进入 Vercel 项目控制台
2. 导航到 Settings → Environment Variables
3. 添加以下变量：

| 变量名 | 值 | 环境 |
|--------|----|---------|
| `VITE_API_BASE_URL` | `https://your-app-name.railway.app/api` | Production |
| `VITE_MEDIA_BASE_URL` | `https://your-app-name.railway.app/static` | Production |
| `VITE_WS_BASE_URL` | `wss://your-app-name.railway.app` | Production |
| `VITE_APP_ENV` | `production` | Production |
| `VITE_DEBUG` | `false` | Production |

## 测试 API 连接

### 1. 后端健康检查

```bash
curl https://your-app-name.railway.app/api/health
```

预期响应：
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "version": "1.0.0"
}
```

### 2. 前端 API 测试

在浏览器控制台中测试：

```javascript
// 检查环境配置
console.log(window.__TIMELINE_ENV__.getEnvironmentInfo());

// 测试 API 连接
fetch(window.__TIMELINE_ENV__.getFullApiURL('health'))
  .then(response => response.json())
  .then(data => console.log('API 连接成功:', data))
  .catch(error => console.error('API 连接失败:', error));
```

## 常见问题

### 1. CORS 错误

**问题**: 前端无法访问后端 API，出现 CORS 错误

**解决方案**:
- 确保后端 CORS 配置包含前端域名
- 检查 Railway 环境变量 `FRONTEND_URL` 是否正确设置

### 2. API 路径错误

**问题**: API 请求返回 404 错误

**解决方案**:
- 检查 API 基础 URL 是否正确
- 确认后端路由配置
- 验证 Railway 应用是否正常运行

### 3. 环境变量未生效

**问题**: 配置更新后仍使用旧的 API 地址

**解决方案**:
- 清除浏览器缓存
- 重新构建并部署前端
- 检查 Vercel 环境变量配置

## 部署检查清单

- [ ] Railway 后端应用已成功部署
- [ ] 获取了正确的 Railway 应用 URL
- [ ] 更新了 `.env.production` 文件
- [ ] 更新了 `environment.js` 中的生产配置
- [ ] 配置了 Vercel 环境变量
- [ ] 测试了 API 连接
- [ ] 验证了前端功能正常

## 下一步

完成前端 API 配置更新后，继续执行：

1. **重新部署前端到 Vercel**
2. **验证完整功能**

---

*注意：每次 Railway 应用 URL 发生变化时，都需要重复上述配置更新步骤。*