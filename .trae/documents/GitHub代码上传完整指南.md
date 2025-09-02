# GitHub代码上传完整指南

本指南将详细介绍如何将时光轴笔记项目上传到GitHub，适合编程新手使用。

## 1. 准备工作

### 1.1 安装Git

**Windows用户：**
1. 访问 [Git官网](https://git-scm.com/download/win)
2. 下载Git for Windows
3. 运行安装程序，保持默认设置即可
4. 安装完成后，打开命令提示符或PowerShell
5. 输入 `git --version` 验证安装成功

**Mac用户：**
```bash
# 使用Homebrew安装
brew install git

# 或者从官网下载安装包
# https://git-scm.com/download/mac
```

**Linux用户：**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git

# CentOS/RHEL
sudo yum install git
```

### 1.2 配置Git

首次使用Git需要配置用户信息：

```bash
# 配置用户名（替换为你的GitHub用户名）
git config --global user.name "你的用户名"

# 配置邮箱（替换为你的GitHub邮箱）
git config --global user.email "你的邮箱@example.com"

# 验证配置
git config --list
```

### 1.3 创建GitHub账户

1. 访问 [GitHub官网](https://github.com)
2. 点击"Sign up"注册账户
3. 填写用户名、邮箱和密码
4. 验证邮箱地址
5. 完成账户设置

## 2. 创建GitHub仓库

### 2.1 在GitHub网站创建仓库

1. 登录GitHub账户
2. 点击右上角的"+"号，选择"New repository"
3. 填写仓库信息：
   - **Repository name**: `timeline-notebook`（或你喜欢的名称）
   - **Description**: `时光轴笔记 - 个人时间线管理应用`
   - **Visibility**: 选择Public（公开）或Private（私有）
   - **不要**勾选"Add a README file"、"Add .gitignore"、"Choose a license"
4. 点击"Create repository"

### 2.2 获取仓库地址

创建完成后，GitHub会显示仓库地址，类似：
```
https://github.com/你的用户名/timeline-notebook.git
```

## 3. 本地Git初始化

### 3.1 打开项目目录

```bash
# 进入项目根目录
cd C:\Users\Administrator\Desktop\timeline-notebook-main\timeline-notebook-main

# 或者在文件管理器中右键选择"在此处打开PowerShell"或"Git Bash Here"
```

### 3.2 初始化Git仓库

```bash
# 初始化Git仓库
git init

# 查看当前状态
git status
```

## 4. 配置.gitignore文件

### 4.1 检查现有.gitignore

项目中已经有`.gitignore`文件，但我们需要确保它包含必要的忽略规则：

```bash
# 查看.gitignore内容
type .gitignore
```

### 4.2 完善.gitignore内容

确保`.gitignore`文件包含以下内容：

```gitignore
# 依赖目录
node_modules/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python

# 环境变量文件
.env
.env.local
.env.production
.env.development

# 数据库文件
*.db
*.sqlite
*.sqlite3
backend/data/timeline.db

# 日志文件
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# 构建输出
dist/
build/
.vite/

# IDE文件
.vscode/
.idea/
*.swp
*.swo
*~

# 系统文件
.DS_Store
Thumbs.db

# SSL证书
ssl/
*.pem
*.key
*.crt

# 备份文件
*.backup
*.bak

# 临时文件
tmp/
temp/

# Docker相关
.dockerignore

# 上传文件
static/uploads/
backend/static/uploads/
```

## 5. 添加和提交代码

### 5.1 添加文件到暂存区

```bash
# 添加所有文件（除了.gitignore中指定的）
git add .

# 查看暂存区状态
git status
```

### 5.2 提交代码

```bash
# 提交代码到本地仓库
git commit -m "初始提交：时光轴笔记项目"

# 查看提交历史
git log --oneline
```

## 6. 连接远程仓库

### 6.1 添加远程仓库

```bash
# 添加远程仓库（替换为你的仓库地址）
git remote add origin https://github.com/你的用户名/timeline-notebook.git

# 验证远程仓库
git remote -v
```

### 6.2 推送代码到GitHub

```bash
# 推送代码到GitHub（首次推送）
git push -u origin main

# 如果出现分支名称问题，可能需要：
git branch -M main
git push -u origin main
```

## 7. 身份验证

### 7.1 使用Personal Access Token（推荐）

由于GitHub已停止支持密码验证，需要使用Personal Access Token：

1. 登录GitHub，进入Settings
2. 点击左侧"Developer settings"
3. 选择"Personal access tokens" > "Tokens (classic)"
4. 点击"Generate new token" > "Generate new token (classic)"
5. 设置token信息：
   - **Note**: `timeline-notebook-upload`
   - **Expiration**: 选择合适的过期时间
   - **Scopes**: 勾选`repo`（完整仓库访问权限）
6. 点击"Generate token"
7. **重要**：复制生成的token（只显示一次）

### 7.2 使用Token进行身份验证

当Git要求输入密码时：
- **Username**: 你的GitHub用户名
- **Password**: 粘贴刚才复制的Personal Access Token

### 7.3 配置凭据缓存（可选）

```bash
# Windows
git config --global credential.helper manager-core

# Mac
git config --global credential.helper osxkeychain

# Linux
git config --global credential.helper store
```

## 8. 验证上传成功

### 8.1 检查GitHub仓库

1. 刷新GitHub仓库页面
2. 确认所有文件都已上传
3. 检查文件结构是否完整
4. 查看提交历史

### 8.2 克隆测试（可选）

```bash
# 在另一个目录测试克隆
cd /tmp
git clone https://github.com/你的用户名/timeline-notebook.git
cd timeline-notebook
ls -la
```

## 9. 后续维护

### 9.1 日常提交流程

```bash
# 1. 查看文件变更
git status

# 2. 添加变更文件
git add .
# 或添加特定文件
git add 文件名

# 3. 提交变更
git commit -m "描述你的变更内容"

# 4. 推送到GitHub
git push
```

### 9.2 良好的提交信息规范

```bash
# 功能添加
git commit -m "feat: 添加用户登录功能"

# 问题修复
git commit -m "fix: 修复时间线显示错误"

# 文档更新
git commit -m "docs: 更新部署指南"

# 样式调整
git commit -m "style: 优化首页布局"

# 重构代码
git commit -m "refactor: 重构用户认证模块"
```

### 9.3 分支管理（进阶）

```bash
# 创建新分支
git checkout -b feature/新功能名称

# 切换分支
git checkout main
git checkout feature/新功能名称

# 合并分支
git checkout main
git merge feature/新功能名称

# 删除分支
git branch -d feature/新功能名称
```

## 10. 常见问题解决

### 10.1 推送被拒绝

**问题**：`! [rejected] main -> main (fetch first)`

**解决**：
```bash
# 先拉取远程更新
git pull origin main

# 如果有冲突，解决后重新提交
git add .
git commit -m "解决合并冲突"

# 再次推送
git push origin main
```

### 10.2 身份验证失败

**问题**：`Authentication failed`

**解决**：
1. 确认Personal Access Token是否正确
2. 检查token是否过期
3. 确认token权限是否足够
4. 清除缓存的凭据：
   ```bash
   git config --global --unset credential.helper
   ```

### 10.3 文件过大

**问题**：`file exceeds GitHub's file size limit`

**解决**：
1. 检查`.gitignore`是否正确配置
2. 移除大文件：
   ```bash
   git rm --cached 大文件名
   git commit -m "移除大文件"
   ```
3. 使用Git LFS处理大文件（如需要）

### 10.4 忘记添加.gitignore

**问题**：敏感文件已经被提交

**解决**：
```bash
# 停止跟踪文件但保留本地文件
git rm --cached 敏感文件名

# 添加到.gitignore
echo "敏感文件名" >> .gitignore

# 提交更改
git add .gitignore
git commit -m "添加.gitignore，移除敏感文件"
git push
```

### 10.5 提交信息写错

**问题**：最后一次提交信息有误

**解决**：
```bash
# 修改最后一次提交信息
git commit --amend -m "正确的提交信息"

# 如果已经推送，需要强制推送（谨慎使用）
git push --force
```

## 11. 安全建议

### 11.1 保护敏感信息

1. **永远不要**提交以下文件：
   - 包含密码的配置文件
   - API密钥和令牌
   - 数据库文件
   - SSL证书和私钥

2. 使用环境变量存储敏感信息
3. 定期检查`.gitignore`文件
4. 使用`git log`检查提交历史

### 11.2 Personal Access Token安全

1. 设置合理的过期时间
2. 只授予必要的权限
3. 定期轮换token
4. 不要在代码中硬编码token
5. 如果token泄露，立即撤销并重新生成

## 12. 下一步

代码成功上传到GitHub后，你可以：

1. **设置仓库描述和标签**
   - 在GitHub仓库页面添加详细描述
   - 添加相关标签（topics）

2. **创建README.md**
   - 项目介绍
   - 安装和使用说明
   - 功能特性
   - 贡献指南

3. **设置GitHub Pages**（如果需要）
   - 展示项目演示
   - 托管项目文档

4. **配置GitHub Actions**（进阶）
   - 自动化测试
   - 自动部署
   - 代码质量检查

5. **邀请协作者**
   - 添加团队成员
   - 设置权限管理

## 总结

通过本指南，你已经学会了：
- Git的基本配置和使用
- 创建和管理GitHub仓库
- 代码的提交和推送流程
- 常见问题的解决方法
- 安全最佳实践

现在你的时光轴笔记项目已经安全地存储在GitHub上，可以进行版本控制和协作开发了。记住定期提交代码变更，保持良好的提交习惯！

---

**提示**：如果在操作过程中遇到问题，可以参考[GitHub官方文档](https://docs.github.com)或在项目Issues中提问。