#!/bin/bash

# 🚀 Timeline Notebook 一键启动脚本
# 快速启动本地开发或生产环境

echo "=== Timeline Notebook 一键启动 ==="
echo "请选择启动模式："
echo "1) 本地开发模式 (npm run dev)"
echo "2) 生产模式 (Docker)"
echo "3) 服务器部署模式"
read -p "请输入选择 (1-3): " choice

case $choice in
    1)
        echo "🔧 启动本地开发模式..."
        
        # 检查Node.js
        if ! command -v node &> /dev/null; then
            echo "❌ Node.js未安装，请先安装Node.js"
            exit 1
        fi
        
        # 启动后端
        echo "🔧 启动后端服务..."
        cd backend
        if [ ! -d "venv" ]; then
            python -m venv venv
        fi
        source venv/bin/activate
        pip install -r requirements.txt
        python app.py &
        BACKEND_PID=$!
        cd ..
        
        # 启动前端
        echo "🔧 启动前端服务..."
        cd frontend
        if [ ! -d "node_modules" ]; then
            npm install
        fi
        npm run dev &
        FRONTEND_PID=$!
        cd ..
        
        echo "✅ 开发环境启动完成！"
        echo "📱 前端地址: http://localhost:5173"
        echo "🔧 后端地址: http://localhost:5000"
        echo "按 Ctrl+C 停止服务"
        
        # 等待用户中断
        trap "kill $BACKEND_PID $FRONTEND_PID; exit" INT
        wait
        ;;
        
    2)
        echo "🐳 启动生产模式 (Docker)..."
        ./server-deploy.sh
        ;;
        
    3)
        echo "🖥️ 服务器部署模式"
        echo "请参考 GITHUB-DEPLOY-GUIDE.md 文档进行部署"
        echo "快速命令："
        echo "  Linux: ./server-deploy.sh"
        echo "  Windows: .\\server-deploy.ps1"
        ;;
        
    *)
        echo "❌ 无效选择，请重新运行脚本"
        exit 1
        ;;
esac