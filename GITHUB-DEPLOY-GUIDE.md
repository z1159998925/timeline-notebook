# 🚀 Timeline Notebook GitHub推送与服务器部署指南

## 📋 目录
- [GitHub推送步骤](#github推送步骤)
- [服务器部署步骤](#服务器部署步骤)
- [常见问题解决](#常见问题解决)
- [维护命令](#维护命令)

## 🔗 GitHub推送步骤

### 1. 创建GitHub仓库
1. 登录GitHub (https://github.com)
2. 点击右上角 "+" 按钮，选择 "New repository"
3. 填写仓库信息：
   - Repository name: `timeline-notebook`
   - Description: `Timeline Notebook - 个人笔记管理系统`
   - 选择 Public 或 Private
   - **不要**勾选 "Add a README file"
   - **不要**勾选 "Add .gitignore"
   - **不要**勾选 "Choose a license"
4. 点击 "Create repository"

### 2. 推送代码到GitHub

在项目目录下执行以下命令：

```bash
# 添加远程仓库（替换YOUR_USERNAME为你的GitHub用户名）
git remote add origin https://github.com/YOUR_USERNAME/timeline-notebook.git

# 推送代码到GitHub
git branch -M main
git push -u origin main
```

**PowerShell版本：**
```powershell
# 添加远程仓库
git remote add origin https://github.com/YOUR_USERNAME/timeline-notebook.git

# 推送代码
git branch -M main
git push -u origin main
```

### 3. 验证推送成功
- 刷新GitHub仓库页面
- 确认所有文件已上传
- 检查README.md是否正确显示

## 🖥️ 服务器部署步骤

### 方式一：Linux服务器部署

#### 1. 服务器准备
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用Docker组权限
exit
```

#### 2. 克隆项目
```bash
# 克隆项目（替换YOUR_USERNAME为你的GitHub用户名）
git clone https://github.com/YOUR_USERNAME/timeline-notebook.git
cd timeline-notebook
```

#### 3. 快速部署
```bash
# 给部署脚本执行权限
chmod +x server-deploy.sh

# 执行部署
./server-deploy.sh
```

### 方式二：Windows服务器部署

#### 1. 服务器准备
1. 安装Docker Desktop for Windows
2. 确保Docker Desktop正在运行
3. 打开PowerShell（管理员权限）

#### 2. 克隆项目
```powershell
# 克隆项目
git clone https://github.com/YOUR_USERNAME/timeline-notebook.git
cd timeline-notebook
```

#### 3. 快速部署
```powershell
# 执行PowerShell部署脚本
.\server-deploy.ps1
```

## 🔧 部署后访问

部署成功后，你可以通过以下地址访问：

- **前端界面**: `http://服务器IP:80`
- **后端API**: `http://服务器IP:5000`
- **健康检查**: `http://服务器IP:5000/health`

### 本地测试访问
- **前端界面**: http://localhost:80
- **后端API**: http://localhost:5000

## 🛠️ 维护命令

### 查看服务状态
```bash
docker-compose ps
```

### 查看日志
```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f nginx
```

### 重启服务
```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart backend
```

### 停止服务
```bash
docker-compose down
```

### 更新代码
```bash
# 拉取最新代码
git pull origin main

# 重新构建并启动
docker-compose up --build -d
```

## ❗ 常见问题解决

### 1. 端口被占用
```bash
# 查看端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :5000

# 停止占用端口的进程
sudo kill -9 PID
```

### 2. Docker权限问题
```bash
# 添加用户到docker组
sudo usermod -aG docker $USER
# 重新登录
exit
```

### 3. 服务启动失败
```bash
# 查看详细错误日志
docker-compose logs backend
docker-compose logs frontend

# 重新构建镜像
docker-compose build --no-cache
docker-compose up -d
```

### 4. 数据库问题
```bash
# 检查数据目录权限
ls -la data/

# 重新创建数据库
docker-compose exec backend python -c "from app_production import db; db.create_all()"
```

## 🔒 生产环境建议

虽然此部署脚本专注于快速运行，但在生产环境中建议：

1. **使用HTTPS**: 配置SSL证书
2. **设置防火墙**: 只开放必要端口
3. **定期备份**: 备份数据库和上传文件
4. **监控日志**: 设置日志轮转和监控
5. **更新密钥**: 使用强密码和密钥

## 📞 支持

如果遇到问题，请检查：
1. Docker和Docker Compose是否正确安装
2. 端口80和5000是否被占用
3. 服务器防火墙设置
4. 查看详细的错误日志

---

**快速部署命令总结：**

```bash
# Linux
git clone https://github.com/YOUR_USERNAME/timeline-notebook.git
cd timeline-notebook
chmod +x server-deploy.sh
./server-deploy.sh
```

```powershell
# Windows
git clone https://github.com/YOUR_USERNAME/timeline-notebook.git
cd timeline-notebook
.\server-deploy.ps1
```