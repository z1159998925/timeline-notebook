# Timeline Notebook

一个基于 Flask 和 Vue.js 的时间轴笔记应用。

## 功能特性

- 📝 创建和管理时间轴条目
- 🖼️ 支持图片上传
- 🔍 搜索和筛选功能
- 📱 响应式设计
- 🔐 用户认证系统

## 🚀 快速开始

### 本地开发环境

1. **克隆项目**：
```bash
git clone <repository-url>
cd timeline-notebook
```

2. **启动开发环境**：
```bash
# Windows
start-dev.bat

# 或手动启动
docker-compose -f docker-compose.dev.yml up --build
```

3. **访问应用**：
- 前端：http://localhost
- 后端 API：http://localhost:5000

4. **停止开发环境**：
```bash
# Windows
stop-dev.bat

# 或手动停止
docker-compose -f docker-compose.dev.yml down
```

### 生产环境部署

详细部署指南请参考：[DEPLOY-SERVER.md](DEPLOY-SERVER.md)

**快速部署到Ubuntu服务器**：
```bash
# 上传文件到服务器
upload-to-server.bat

# 在服务器上执行
./deploy-server.sh
```

## 🚀 使用说明

### 基本功能
1. **查看时间线**: 主页显示所有笔记的时间线视图
2. **添加笔记**: 点击"+"按钮创建新笔记
3. **上传图片**: 在创建笔记时可以上传图片
4. **主题切换**: 点击右上角的主题切换按钮

### 管理员功能
1. **登录**: 点击右上角"Admin Login"进入管理员登录
2. **管理笔记**: 登录后可以删除和管理所有笔记
3. **退出登录**: 在管理员面板点击"Logout"

### 自动保存功能
- 输入内容时自动保存草稿到本地存储
- 页面刷新或意外关闭后可恢复草稿
- 成功提交后自动清除草稿

## 📁 项目结构

```
timeline-notebook/
├── backend/                 # 后端Flask应用
│   ├── app.py              # 主应用文件
│   ├── models.py           # 数据库模型
│   ├── routes.py           # API路由
│   ├── config.py           # 配置文件
│   ├── create_admin.py     # 创建管理员脚本
│   ├── requirements.txt    # Python依赖
│   └── static/uploads/     # 上传文件存储
├── frontend/               # 前端Vue应用
│   ├── src/
│   │   ├── components/     # Vue组件
│   │   ├── router/         # 路由配置
│   │   ├── utils/          # 工具函数
│   │   └── App.vue         # 主应用组件
│   ├── package.json        # 前端依赖
│   └── vite.config.js      # Vite配置
└── README.md               # 项目说明
```

## 🔧 配置说明

### 后端配置
- 数据库: SQLite (可在 `config.py` 中修改)
- 上传目录: `backend/static/uploads/`
- 默认端口: 5000

### 前端配置
- API基础URL: `http://localhost:5000/api`
- 开发端口: 5173
- 构建输出: `dist/`

## 🤝 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🐛 问题反馈

如果您发现任何问题或有改进建议，请在 [Issues](https://github.com/z1159998925/timeline-notebook/issues) 页面提交。

## 📞 联系方式

- 项目链接: [https://github.com/z1159998925/timeline-notebook](https://github.com/z1159998925/timeline-notebook)

---

⭐ 如果这个项目对您有帮助，请给它一个星标！