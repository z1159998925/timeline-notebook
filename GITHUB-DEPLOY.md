# GitHub部署指南

使用GitHub进行Timeline Notebook的版本管理和部署。

## 🚀 GitHub部署优势

- ✅ 版本控制和代码历史
- ✅ 团队协作和代码审查
- ✅ 自动化部署流程
- ✅ 回滚到任意版本
- ✅ 分支管理和功能开发

## 📋 部署步骤

### 1. 创建GitHub仓库

1. 登录GitHub，创建新仓库 `timeline-notebook`
2. 设置为私有仓库（推荐）
3. 不要初始化README、.gitignore或LICENSE

### 2. 本地代码推送到GitHub

```bash
# 在项目根目录执行
cd c:\Users\Administrator\PycharmProjects\timeline-notebook

# 初始化Git仓库
git init

# 添加远程仓库
git remote add origin https://github.com/z1159998925/timeline-notebook.git

# 添加所有文件
git add .

# 提交代码
git commit -m "Initial commit: Timeline Notebook"

# 推送到GitHub
git push -u origin main
```

### 3. 服务器部署配置

#### 方法1: 使用部署脚本（推荐）

1. **上传部署脚本到服务器**：
```bash
scp deploy-from-github.sh root@YOUR_SERVER_IP:/tmp/
scp install-docker-ubuntu.sh root@YOUR_SERVER_IP:/tmp/
```

2. **在服务器上执行**：
```bash
ssh root@YOUR_SERVER_IP
cd /tmp
chmod +x deploy-from-github.sh
chmod +x install-docker-ubuntu.sh

# 脚本已配置正确的GitHub仓库地址
# 无需修改 deploy-from-github.sh

# 执行部署
sudo ./deploy-from-github.sh
```

#### 方法2: 手动部署

```bash
# 连接到服务器
ssh root@YOUR_SERVER_IP

# 安装Git
apt-get update && apt-get install -y git

# 克隆代码
cd /opt
git clone https://github.com/z1159998925/timeline-notebook.git
cd timeline-notebook

# 安装Docker（如果未安装）
sudo ./install-docker-ubuntu.sh

# 执行部署
sudo ./deploy-server.sh
```

### 4. 更新部署流程

当您修改代码后，更新部署：

```bash
# 本地提交并推送
git add .
git commit -m "Update: 描述您的修改"
git push origin main

# 在服务器上更新
ssh root@YOUR_SERVER_IP
cd /opt/timeline-notebook
git pull origin main
sudo ./deploy-server.sh
```

## 🔧 自动化部署脚本

### 创建更新脚本

在服务器上创建 `/opt/timeline-notebook/update.sh`：

```bash
#!/bin/bash
cd /opt/timeline-notebook
git pull origin main
docker-compose -f docker-compose-server.yml up --build -d
echo "部署更新完成！"
```

使用方法：
```bash
ssh root@YOUR_SERVER_IP
cd /opt/timeline-notebook
sudo ./update.sh
```

## 📝 环境配置管理

### .env文件管理

由于 `.env` 文件包含敏感信息，建议：

1. **不要提交 `.env` 到GitHub**（已在.gitignore中排除）
2. **在服务器上手动创建 `.env`**：

```bash
# 在服务器上
cd /opt/timeline-notebook
cp .env.server .env

# 编辑配置
nano .env
```

### 配置文件说明

- `.env.dev` - 本地开发环境配置（可提交）
- `.env.server` - 生产环境配置模板（可提交）
- `.env` - 实际使用的配置（不提交，在服务器上创建）

## 🔒 安全建议

### GitHub访问

1. **使用SSH密钥**（推荐）：
```bash
# 在服务器上生成SSH密钥
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# 添加公钥到GitHub
cat ~/.ssh/id_rsa.pub
```

2. **使用Personal Access Token**：
   - GitHub Settings → Developer settings → Personal access tokens
   - 生成token并在克隆时使用

### 私有仓库

建议将仓库设置为私有，避免敏感配置泄露。

## 🚀 完整部署命令

### 首次部署

```bash
# 1. 本地推送到GitHub
git init
git remote add origin https://github.com/z1159998925/timeline-notebook.git
git add .
git commit -m "Initial commit"
git push -u origin main

# 2. 服务器部署
ssh root@YOUR_SERVER_IP
cd /opt
git clone https://github.com/z1159998925/timeline-notebook.git
cd timeline-notebook
cp .env.server .env
# 编辑 .env 文件配置
sudo ./install-docker-ubuntu.sh
sudo ./deploy-server.sh
```

### 日常更新

```bash
# 本地
git add .
git commit -m "Update features"
git push origin main

# 服务器
ssh root@YOUR_SERVER_IP
cd /opt/timeline-notebook
git pull origin main
sudo ./deploy-server.sh
```

## 📊 监控和管理

### 查看部署状态
```bash
cd /opt/timeline-notebook
docker-compose -f docker-compose-server.yml ps
docker-compose -f docker-compose-server.yml logs -f
```

### 回滚到之前版本
```bash
cd /opt/timeline-notebook
git log --oneline  # 查看提交历史
git checkout COMMIT_HASH  # 回滚到指定版本
sudo ./deploy-server.sh
```

## ✅ 访问应用

部署完成后访问：https://xn--cpq55e94lgvdcukyqt.com