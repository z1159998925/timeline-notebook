# 🚀 Timeline Notebook Windows服务器快速部署脚本
# 专注功能运行，无安全检查

Write-Host "=== Timeline Notebook Windows服务器快速部署 ===" -ForegroundColor Green
Write-Host "开始时间: $(Get-Date)" -ForegroundColor Yellow

# 检查Docker
try {
    docker --version | Out-Null
    Write-Host "✅ Docker已安装" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker未安装，请先安装Docker Desktop" -ForegroundColor Red
    exit 1
}

try {
    docker-compose --version | Out-Null
    Write-Host "✅ Docker Compose已安装" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Compose未安装，请先安装Docker Compose" -ForegroundColor Red
    exit 1
}

# 停止并清理旧容器
Write-Host "🧹 清理旧容器和镜像..." -ForegroundColor Yellow
try {
    docker-compose down --remove-orphans 2>$null
    docker system prune -f 2>$null
} catch {
    Write-Host "清理过程中出现警告，继续执行..." -ForegroundColor Yellow
}

# 创建必要目录
Write-Host "📁 创建必要目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "backend\static\uploads" | Out-Null
New-Item -ItemType Directory -Force -Path "data" | Out-Null
New-Item -ItemType Directory -Force -Path "logs" | Out-Null

# 生成简化的生产环境配置
Write-Host "⚙️ 生成生产环境配置..." -ForegroundColor Yellow
$timestamp = [int][double]::Parse((Get-Date -UFormat %s))
$envContent = @"
# Timeline Notebook 生产环境配置
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=timeline-notebook-production-key-$timestamp
DATABASE_URL=sqlite:///data/timeline_notebook.db
UPLOAD_FOLDER=/app/static/uploads
MAX_CONTENT_LENGTH=16777216
CORS_ORIGINS=*
PORT=5000
HOST=0.0.0.0
"@

$envContent | Out-File -FilePath ".env.production" -Encoding UTF8
Write-Host "✅ 环境配置生成完成" -ForegroundColor Green

# 构建并启动服务
Write-Host "🔨 构建并启动服务..." -ForegroundColor Yellow
docker-compose up --build -d

# 等待服务启动
Write-Host "⏳ 等待服务启动..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 检查服务状态
Write-Host "🔍 检查服务状态..." -ForegroundColor Yellow
docker-compose ps

# 简单的健康检查
Write-Host "🏥 进行健康检查..." -ForegroundColor Yellow

# 检查后端服务
for ($i = 1; $i -le 5; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ 后端服务运行正常" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "⏳ 等待后端服务启动... ($i/5)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

# 检查前端服务
for ($i = 1; $i -le 5; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:80" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ 前端服务运行正常" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "⏳ 等待前端服务启动... ($i/5)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

# 获取本机IP地址
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "以太网*" | Where-Object {$_.IPAddress -notlike "169.254.*"} | Select-Object -First 1).IPAddress
if (-not $ipAddress) {
    $ipAddress = "localhost"
}

Write-Host ""
Write-Host "🎉 部署完成！" -ForegroundColor Green
Write-Host "📱 前端访问地址: http://$ipAddress:80" -ForegroundColor Cyan
Write-Host "🔧 后端API地址: http://$ipAddress:5000" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 常用命令:" -ForegroundColor Yellow
Write-Host "  查看日志: docker-compose logs -f"
Write-Host "  停止服务: docker-compose down"
Write-Host "  重启服务: docker-compose restart"
Write-Host "  查看状态: docker-compose ps"
Write-Host ""
Write-Host "完成时间: $(Get-Date)" -ForegroundColor Yellow