# 🚀 Timeline Notebook Windows一键启动脚本
# 快速启动本地开发或生产环境

Write-Host "=== Timeline Notebook 一键启动 ===" -ForegroundColor Green
Write-Host "请选择启动模式：" -ForegroundColor Yellow
Write-Host "1) 本地开发模式 (npm run dev)" -ForegroundColor Cyan
Write-Host "2) 生产模式 (Docker)" -ForegroundColor Cyan
Write-Host "3) 服务器部署模式" -ForegroundColor Cyan

$choice = Read-Host "请输入选择 (1-3)"

switch ($choice) {
    "1" {
        Write-Host "🔧 启动本地开发模式..." -ForegroundColor Yellow
        
        # 检查Node.js
        try {
            node --version | Out-Null
            Write-Host "✅ Node.js已安装" -ForegroundColor Green
        } catch {
            Write-Host "❌ Node.js未安装，请先安装Node.js" -ForegroundColor Red
            exit 1
        }
        
        # 检查Python
        try {
            python --version | Out-Null
            Write-Host "✅ Python已安装" -ForegroundColor Green
        } catch {
            Write-Host "❌ Python未安装，请先安装Python" -ForegroundColor Red
            exit 1
        }
        
        # 启动后端
        Write-Host "🔧 启动后端服务..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend; if (!(Test-Path venv)) { python -m venv venv }; .\venv\Scripts\Activate.ps1; pip install -r requirements.txt; python app.py"
        
        # 等待后端启动
        Start-Sleep -Seconds 5
        
        # 启动前端
        Write-Host "🔧 启动前端服务..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; if (!(Test-Path node_modules)) { npm install }; npm run dev"
        
        Write-Host "✅ 开发环境启动完成！" -ForegroundColor Green
        Write-Host "📱 前端地址: http://localhost:5173" -ForegroundColor Cyan
        Write-Host "🔧 后端地址: http://localhost:5000" -ForegroundColor Cyan
        Write-Host "请在新打开的PowerShell窗口中查看服务状态" -ForegroundColor Yellow
        break
    }
    
    "2" {
        Write-Host "🐳 启动生产模式 (Docker)..." -ForegroundColor Yellow
        .\server-deploy.ps1
        break
    }
    
    "3" {
        Write-Host "🖥️ 服务器部署模式" -ForegroundColor Yellow
        Write-Host "请参考 GITHUB-DEPLOY-GUIDE.md 文档进行部署" -ForegroundColor Cyan
        Write-Host "快速命令：" -ForegroundColor Yellow
        Write-Host "  Linux: ./server-deploy.sh" -ForegroundColor White
        Write-Host "  Windows: .\server-deploy.ps1" -ForegroundColor White
        break
    }
    
    default {
        Write-Host "❌ 无效选择，请重新运行脚本" -ForegroundColor Red
        exit 1
    }
}

Write-Host "按任意键退出..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")