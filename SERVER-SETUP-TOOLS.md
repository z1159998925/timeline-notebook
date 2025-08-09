# 🚀 Timeline Notebook 服务器配置工具推荐

## 🎯 推荐方案对比

### 方案一：使用 Ansible（推荐）⭐⭐⭐⭐⭐
**优势：**
- 🔧 自动化程度最高
- 📋 配置即代码，可版本控制
- 🔄 可重复执行，幂等性好
- 🌐 支持多服务器批量配置
- 📚 丰富的模块生态

### 方案二：使用 Docker Swarm + Portainer
**优势：**
- 🐳 原生Docker集群管理
- 🖥️ 可视化Web界面
- 📊 监控和日志集成
- 🔄 自动故障恢复

### 方案三：使用 1Panel（国产面板）
**优势：**
- 🇨🇳 中文界面，易上手
- 🐳 Docker可视化管理
- 🔐 SSL证书自动管理
- 📊 系统监控面板

## 🏆 最佳推荐：Ansible + 我们的脚本

结合Ansible的自动化能力和我们的部署脚本，实现最佳部署体验。

### 安装Ansible（在本地机器）

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ansible

# CentOS/RHEL
sudo yum install epel-release
sudo yum install ansible

# macOS
brew install ansible

# Windows (WSL)
sudo apt update && sudo apt install ansible
```

### Ansible配置文件

创建以下文件结构：
```
ansible/
├── inventory.yml          # 服务器清单
├── playbook.yml          # 主要部署脚本
├── group_vars/
│   └── all.yml           # 全局变量
└── roles/
    └── timeline/
        ├── tasks/main.yml
        ├── templates/
        └── files/
```

## 📋 完整Ansible部署方案

### 1. 服务器清单 (inventory.yml)
```yaml
all:
  hosts:
    timeline-server:
      ansible_host: 你的服务器IP
      ansible_user: root
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
  vars:
    domain: "张伟爱刘新宇.com"
    email: "1159998925@qq.com"
    project_dir: "/opt/timeline-notebook"
```

### 2. 全局变量 (group_vars/all.yml)
```yaml
# 项目配置
project_name: "timeline-notebook"
project_repo: "https://github.com/z1159998925/timeline-notebook.git"
project_branch: "main"

# Docker配置
docker_compose_version: "2.20.0"

# SSL配置
ssl_email: "{{ email }}"
ssl_domain: "{{ domain }}"

# 安全配置
firewall_allowed_ports:
  - "22/tcp"
  - "80/tcp"
  - "443/tcp"

# 系统优化
system_packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - unzip
  - python3
  - python3-pip
```

### 3. 主部署脚本 (playbook.yml)
```yaml
---
- name: Deploy Timeline Notebook
  hosts: all
  become: yes
  
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes
        upgrade: dist
        
    - name: Install required packages
      apt:
        name: "{{ system_packages }}"
        state: present
        
    - name: Install Docker
      shell: |
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl start docker
        systemctl enable docker
      args:
        creates: /usr/bin/docker
        
    - name: Configure firewall
      ufw:
        rule: allow
        port: "{{ item.split('/')[0] }}"
        proto: "{{ item.split('/')[1] }}"
      loop: "{{ firewall_allowed_ports }}"
      
    - name: Enable firewall
      ufw:
        state: enabled
        policy: deny
        direction: incoming
        
    - name: Create project directory
      file:
        path: "{{ project_dir }}"
        state: directory
        mode: '0755'
        
    - name: Clone project repository
      git:
        repo: "{{ project_repo }}"
        dest: "{{ project_dir }}"
        version: "{{ project_branch }}"
        force: yes
        
    - name: Make scripts executable
      file:
        path: "{{ project_dir }}/{{ item }}"
        mode: '0755'
      loop:
        - setup-server-environment.sh
        - deploy-project.sh
        
    - name: Run server environment setup
      command: "{{ project_dir }}/setup-server-environment.sh"
      args:
        chdir: "{{ project_dir }}"
        
    - name: Deploy project
      command: "{{ project_dir }}/deploy-project.sh {{ domain }} {{ email }}"
      args:
        chdir: "{{ project_dir }}"
        
    - name: Verify deployment
      uri:
        url: "https://{{ domain }}"
        method: GET
        status_code: [200, 301, 302]
      retries: 5
      delay: 10
```

### 4. 执行部署

```bash
# 检查连接
ansible all -i inventory.yml -m ping

# 执行部署
ansible-playbook -i inventory.yml playbook.yml

# 查看部署状态
ansible all -i inventory.yml -m shell -a "docker ps"
```

## 🎯 方案二：1Panel 可视化面板

### 安装1Panel
```bash
curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sh quick_start.sh
```

### 特点：
- 🖥️ Web界面管理
- 🐳 Docker容器可视化
- 🔐 SSL证书自动申请
- 📊 系统监控
- 🗄️ 数据库管理
- 📁 文件管理

### 使用步骤：
1. 安装1Panel
2. 通过Web界面上传项目文件
3. 使用内置Docker管理部署应用
4. 配置SSL证书和域名

## 🎯 方案三：Portainer + Docker Swarm

### 安装Portainer
```bash
# 创建数据卷
docker volume create portainer_data

# 运行Portainer
docker run -d -p 8000:8000 -p 9443:9443 \
  --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

### 特点：
- 🐳 Docker原生管理
- 📊 容器监控
- 🔄 自动重启
- 📝 日志查看
- 🌐 多环境管理

## 🏅 最终推荐

### 对于新手：1Panel
- 中文界面，易于理解
- 可视化操作，降低学习成本
- 集成度高，一站式解决方案

### 对于进阶用户：Ansible
- 自动化程度最高
- 可重复、可版本控制
- 支持复杂的部署场景

### 对于Docker用户：Portainer
- 专注于容器管理
- 轻量级，资源占用少
- 与现有Docker工作流集成好

## 🚀 快速开始

选择你喜欢的方案：

1. **Ansible方案**：复制上面的配置文件，修改服务器IP和域名，执行部署
2. **1Panel方案**：一键安装，Web界面操作
3. **手动方案**：使用我们优化后的脚本

所有方案都会得到相同的结果：一个完全配置好的Timeline Notebook服务！