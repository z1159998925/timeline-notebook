# Timeline Notebook 项目结构

## 核心文件和目录

### 应用代码
- `backend/` - 后端Flask应用
  - `app.py` - 开发环境应用入口
  - `app_production.py` - 生产环境应用入口
  - `routes.py` - API路由定义
  - `models.py` - 数据模型
  - `cors_config.py` - CORS配置
- `frontend/` - 前端Vue应用
  - `src/` - 源代码目录
  - `package.json` - 依赖配置
  - `vite.config.js` - 开发环境构建配置
  - `vite.config.production.js` - 生产环境构建配置

### Docker配置
- `docker-compose.yml` - 主要的Docker Compose配置
- `docker-compose-http.yml` - HTTP版本的Docker配置
- `Dockerfile.backend` - 后端Docker镜像
- `Dockerfile.frontend.production` - 前端生产环境Docker镜像
- `Dockerfile.frontend.server` - 前端服务器Docker镜像

### Nginx配置
- `nginx.conf` - 主要的Nginx配置
- `nginx-http.conf` - HTTP版本的Nginx配置
- `nginx-domain.conf` - 域名配置
- `nginx/ssl/` - Nginx SSL证书目录

### 环境配置
- `.env.production` - 生产环境变量
- `frontend/.env.production` - 前端生产环境变量
- `backend/.env` - 后端环境变量

### SSL证书
- `ssl/` - SSL证书目录
  - `cert.pem` - SSL证书文件
  - `key.pem` - SSL私钥文件
- `generate-ssl.sh` - SSL证书生成脚本

### 部署脚本
- `production-deploy.sh` - 生产环境部署脚本
- `production-check.sh` - 生产环境检查脚本
- `backup.sh` - 数据备份脚本
- `update-deploy.sh` - 更新部署脚本

### 检查工具
- `full-compatibility-check.py` - 综合兼容性检查脚本
- `nginx-backend-check-simple.py` - 后端配置检查脚本
- `frontend-production-check-simple.py` - 前端配置检查脚本

### 文档
- `README.md` - 项目说明文档
- `FRONTEND-BACKEND-COMPATIBILITY-SUMMARY.md` - 兼容性检查总结
- `PRODUCTION-DEPLOYMENT.md` - 生产环境部署指南
- `PROJECT-STRUCTURE.md` - 项目结构说明（本文件）

### 其他配置
- `ansible-deploy.yml` - Ansible部署配置
- `inventory.example.yml` - Ansible清单示例
- `.gitignore` - Git忽略文件配置

## 数据目录
- `data/` - 应用数据目录
- `static/uploads/` - 用户上传文件目录

## 使用说明

### 开发环境
```bash
# 启动开发环境
cd frontend && npm run dev
cd backend && python app.py
```

### 生产环境
```bash
# 部署到生产环境
./production-deploy.sh

# 检查生产环境状态
python full-compatibility-check.py
```

### 兼容性检查
```bash
# 运行完整检查
python full-compatibility-check.py

# 单独检查后端
python nginx-backend-check-simple.py

# 单独检查前端
python frontend-production-check-simple.py
```

## 注意事项

1. 所有检查脚本都是简化版本，兼容Windows环境
2. SSL证书文件是占位符，生产环境需要替换为真实证书
3. 环境变量文件包含敏感信息，请妥善保管
4. 定期运行兼容性检查确保配置正确性