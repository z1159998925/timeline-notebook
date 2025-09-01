# Timeline Notebook 服务器自动部署指南

## 概述

本指南将帮助您使用 Ansible 自动化部署 Timeline Notebook 到远程服务器。支持 Ubuntu/Debian 系统的一键部署。

## 前置要求

### 服务器要求
- **操作系统**: Ubuntu 18.04+ 或 Debian 9+
- **内存**: 最少 2GB RAM（推荐 4GB+）
- **存储**: 最少 20GB 可用空间
- **网络**: 公网 IP 地址
- **端口**: 开放 22 (SSH), 80 (HTTP), 443 (HTTPS) 端口

### 本地环境要求
- Python 3.6+
- Ansible 2.9+
- Git

## 部署步骤

### 1. 安装 Ansible（如果未安装）

```bash
# Windows (使用 WSL 或 Git Bash)
pip install ansible

# macOS
brew install ansible

# Ubuntu/Debian
sudo apt update
sudo apt install ansible
```

### 2. 配置服务器信息

编辑 `inventory.yml` 文件，填入您的服务器信息：

```yaml
all:
  hosts:
    production_server:
      ansible_host: 192.168.1.100        # 您的服务器IP
      ansible_user: root                  # SSH用户名
      ansible_ssh_pass: your_password     # SSH密码
      ansible_port: 22                    # SSH端口
  
  vars:
    domain_name: yourdomain.com          # 您的域名
    admin_email: admin@yourdomain.com    # 管理员邮箱
```

### 3. 测试服务器连接

```bash
ansible all -i inventory.yml -m ping
```

如果连接成功，您会看到类似输出：
```
production_server | SUCCESS => {
    "ping": "pong"
}
```

### 4. 执行自动部署

```bash
ansible-playbook -i inventory.yml ansible-deploy.yml
```

部署过程包括：
- 系统更新和基础软件安装
- Docker 和 Docker Compose 安装
- 防火墙配置
- 项目代码部署
- SSL 证书申请和配置
- 服务启动和验证

### 5. 验证部署

部署完成后，访问您的域名：
- HTTP: `http://yourdomain.com`
- HTTPS: `https://yourdomain.com`

## 配置说明

### 必需信息

请准备以下信息：

1. **服务器信息**
   - IP 地址
   - SSH 用户名（通常是 root 或 ubuntu）
   - SSH 密码或私钥文件路径
   - SSH 端口（默认 22）

2. **域名信息**
   - 域名（如 example.com）
   - 管理员邮箱（用于 SSL 证书申请）

3. **数据库配置**
   - 数据库名称
   - 数据库用户名
   - 数据库密码（请使用强密码）

### 安全配置

- 自动生成安全的 Flask SECRET_KEY
- 配置防火墙规则
- 启用 HTTPS 和 SSL 证书
- 设置安全的 Cookie 配置
- 配置 CORS 策略

### 域名配置

在部署前，请确保：
1. 域名已解析到服务器 IP
2. DNS 记录生效（可能需要等待几分钟到几小时）

## 常见问题

### Q: 部署失败怎么办？
A: 检查以下几点：
- 服务器是否可以正常 SSH 连接
- 域名是否正确解析到服务器 IP
- 服务器是否有足够的磁盘空间和内存
- 防火墙是否开放了必要端口

### Q: SSL 证书申请失败？
A: 确保：
- 域名已正确解析到服务器
- 80 和 443 端口已开放
- 邮箱地址有效

### Q: 如何更新应用？
A: 重新运行部署命令即可：
```bash
ansible-playbook -i inventory.yml ansible-deploy.yml
```

### Q: 如何查看应用日志？
A: SSH 到服务器后执行：
```bash
cd /opt/timeline-notebook
docker-compose logs -f
```

## 管理命令

部署完成后，您可以使用以下命令管理应用：

```bash
# 查看服务状态
docker-compose ps

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 更新应用
git pull
docker-compose build
docker-compose up -d
```

## 支持

如果遇到问题，请检查：
1. 服务器系统日志：`journalctl -f`
2. 应用日志：`docker-compose logs`
3. Nginx 日志：`docker-compose logs nginx`

---

**注意**: 请确保在生产环境中使用强密码，并定期更新系统和应用。