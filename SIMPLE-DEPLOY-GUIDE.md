# Timeline Notebook 简化部署指南

## 🎯 概述

这是一个全新的、简化的部署方案，分为两个步骤：
1. **服务器环境配置** - 在全新服务器上配置所有必要环境
2. **项目部署** - 下载代码并部署应用

## 📋 前提条件

- Ubuntu 20.04+ 服务器
- 域名已解析到服务器IP
- 服务器可访问互联网
- 有sudo权限

## 🚀 部署步骤

### 第一步：配置服务器环境

在全新的服务器上运行以下命令：

```bash
# 下载环境配置脚本
wget https://raw.githubusercontent.com/z1159998925/timeline-notebook/main/setup-server-environment.sh

# 给脚本执行权限
chmod +x setup-server-environment.sh

# 运行环境配置（需要sudo权限）
sudo ./setup-server-environment.sh
```

这个脚本会自动：
- ✅ 更新系统包
- ✅ 安装Docker和Docker Compose
- ✅ 配置防火墙（开放22, 80, 443端口）
- ✅ 创建项目目录
- ✅ 安装必要工具
- ✅ 优化系统参数
- ✅ 设置时区

### 第二步：部署项目

环境配置完成后，运行以下命令：

```bash
# 进入项目目录
cd /opt

# 克隆项目代码
git clone https://github.com/z1159998925/timeline-notebook.git

# 进入项目目录
cd timeline-notebook

# 给部署脚本执行权限
chmod +x deploy-project.sh

# 运行部署脚本（替换为你的域名和邮箱）
sudo ./deploy-project.sh 你的域名.com 你的邮箱@example.com
```

例如：
```bash
sudo ./deploy-project.sh 张伟爱刘新宇.com 1159998925@qq.com
```

## 🔧 脚本功能说明

### setup-server-environment.sh
- 🔧 系统环境配置
- 🐳 Docker安装和配置
- 🔥 防火墙设置
- 📁 目录结构创建
- ⚡ 系统优化
- 🔍 环境检查工具

### deploy-project.sh
- 📝 生成Docker配置文件
- 🏗️ 构建和启动服务
- 🔐 自动申请SSL证书
- 🔄 配置HTTPS
- 🧪 部署验证

## 📊 部署后管理

### 查看服务状态
```bash
cd /opt/timeline-notebook
docker compose -f docker-compose-https.yml ps
```

### 查看日志
```bash
# 查看所有服务日志
docker compose -f docker-compose-https.yml logs -f

# 查看特定服务日志
docker compose -f docker-compose-https.yml logs -f backend
docker compose -f docker-compose-https.yml logs -f frontend
```

### 重启服务
```bash
docker compose -f docker-compose-https.yml restart
```

### 停止服务
```bash
docker compose -f docker-compose-https.yml down
```

### 更新代码
```bash
cd /opt/timeline-notebook
git pull origin main
docker compose -f docker-compose-https.yml down
docker compose -f docker-compose-https.yml build
docker compose -f docker-compose-https.yml up -d
```

## 🔍 故障排除

### 检查环境
```bash
/opt/timeline-notebook/check-environment.sh
```

### 检查端口占用
```bash
ss -tuln | grep -E ':(80|443|5000)'
```

### 检查防火墙状态
```bash
sudo ufw status
```

### 检查SSL证书
```bash
docker compose -f docker-compose-https.yml exec certbot certbot certificates
```

### 重新申请SSL证书
```bash
docker compose -f docker-compose-https.yml exec certbot certbot renew --force-renewal
```

## 🎯 优势

1. **分步骤部署** - 环境配置和项目部署分离，更清晰
2. **自动化程度高** - 一键配置整个环境
3. **错误处理完善** - 详细的错误提示和解决方案
4. **易于维护** - 清晰的管理命令和日志查看
5. **安全性好** - 自动配置防火墙和SSL证书

## 📞 支持

如果遇到问题，请检查：
1. 域名是否正确解析到服务器IP
2. 服务器防火墙是否正确配置
3. 邮箱地址是否有效
4. 服务器是否有足够的磁盘空间和内存

## 🔄 SSL证书自动续期

SSL证书会自动续期，如需手动续期：

```bash
cd /opt/timeline-notebook
docker compose -f docker-compose-https.yml exec certbot certbot renew
docker compose -f docker-compose-https.yml restart frontend
```