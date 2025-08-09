# GitHub 部署命令

## 🚀 一键部署到服务器

### 方式1：使用GitHub部署脚本（推荐）
```bash
# 在服务器上执行
curl -fsSL https://raw.githubusercontent.com/z1159998925/timeline-notebook/main/deploy-from-github.sh | sudo bash
```

### 方式2：手动GitHub部署
```bash
# 1. 连接服务器
ssh root@YOUR_SERVER_IP

# 2. 克隆代码
cd /opt
git clone https://github.com/z1159998925/timeline-notebook.git
cd timeline-notebook

# 3. 配置环境
cp .env.server .env

# 4. 安装Docker（如果未安装）
chmod +x install-docker-ubuntu.sh
./install-docker-ubuntu.sh

# 5. 部署服务
docker-compose -f docker-compose-server.yml up --build -d

# 6. 创建管理员账户
docker exec -it timeline-backend python create_admin.py
```

### 方式3：使用原有部署脚本
```bash
# 在服务器上执行
curl -fsSL https://raw.githubusercontent.com/z1159998925/timeline-notebook/main/deploy.sh | bash
```

## 📝 本地代码推送到GitHub

如果您需要推送本地修改到GitHub：

```bash
# 在本地项目目录执行
git add .
git commit -m "Update: 描述您的修改"
git push origin main
```

## 🔄 服务器更新代码

当GitHub有新代码时，在服务器上更新：

```bash
# 连接服务器
ssh root@YOUR_SERVER_IP
cd /opt/timeline-notebook

# 拉取最新代码
git pull origin main

# 重新构建并启动
docker-compose -f docker-compose-server.yml up --build -d
```

## 🎯 推荐部署流程

1. **首次部署**：使用方式1的一键部署脚本
2. **日常更新**：本地修改 → 推送到GitHub → 服务器拉取更新

## 📋 部署后检查

```bash
# 检查服务状态
docker-compose -f docker-compose-server.yml ps

# 查看日志
docker-compose -f docker-compose-server.yml logs -f

# 健康检查
curl http://localhost/health
```

---

**注意**：所有脚本都已配置正确的GitHub仓库地址 `https://github.com/z1159998925/timeline-notebook.git`