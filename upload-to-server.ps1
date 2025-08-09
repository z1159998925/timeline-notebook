# Timeline Notebook 服务器上传脚本 (PowerShell版本)
# 适用于Windows PowerShell环境

Write-Host "========================================" -ForegroundColor Green
Write-Host "Timeline Notebook 服务器上传脚本" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 获取服务器信息
$SERVER_IP = Read-Host "请输入服务器IP地址"
$SERVER_USER = Read-Host "请输入服务器用户名 (默认root)"
if ([string]::IsNullOrEmpty($SERVER_USER)) {
    $SERVER_USER = "root"
}
$SERVER_PATH = "/opt/timeline-notebook"

Write-Host ""
Write-Host "配置信息:" -ForegroundColor Yellow
Write-Host "服务器IP: $SERVER_IP" -ForegroundColor White
Write-Host "服务器用户: $SERVER_USER" -ForegroundColor White
Write-Host "服务器路径: $SERVER_PATH" -ForegroundColor White
Write-Host ""

# 检查scp命令
try {
    Get-Command scp -ErrorAction Stop | Out-Null
    Write-Host "✓ 找到 scp 命令" -ForegroundColor Green
} catch {
    Write-Host "✗ 未找到 scp 命令" -ForegroundColor Red
    Write-Host "请安装 Git for Windows 或 OpenSSH" -ForegroundColor Yellow
    Read-Host "按回车键退出"
    exit 1
}

Write-Host "开始上传文件到服务器..." -ForegroundColor Cyan
Write-Host ""

try {
    # 创建服务器目录
    Write-Host "1. 创建服务器目录..." -ForegroundColor Yellow
    ssh "$SERVER_USER@$SERVER_IP" "mkdir -p $SERVER_PATH"
    
    # 上传主要文件
    Write-Host "2. 上传应用文件..." -ForegroundColor Yellow
    scp -r backend "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp -r frontend "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp -r static "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    
    # 上传配置文件
    Write-Host "3. 上传配置文件..." -ForegroundColor Yellow
    scp docker-compose-server.yml "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp Dockerfile.backend "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp Dockerfile.frontend.server "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp nginx-domain.conf "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp .env.server "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    
    # 上传部署脚本
    Write-Host "4. 上传部署脚本..." -ForegroundColor Yellow
    scp deploy-server.sh "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp install-docker-ubuntu.sh "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    scp DEPLOY-SERVER.md "$SERVER_USER@${SERVER_IP}:$SERVER_PATH/"
    
    # 设置脚本权限
    Write-Host "5. 设置脚本权限..." -ForegroundColor Yellow
    ssh "$SERVER_USER@$SERVER_IP" "chmod +x $SERVER_PATH/deploy-server.sh"
    ssh "$SERVER_USER@$SERVER_IP" "chmod +x $SERVER_PATH/install-docker-ubuntu.sh"
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "文件上传完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "接下来请在服务器上执行:" -ForegroundColor Cyan
    Write-Host "1. cd $SERVER_PATH" -ForegroundColor White
    Write-Host "2. sudo ./install-docker-ubuntu.sh  (如果未安装Docker)" -ForegroundColor White
    Write-Host "3. sudo ./deploy-server.sh" -ForegroundColor White
    Write-Host ""
    Write-Host "或者手动连接到服务器:" -ForegroundColor Cyan
    Write-Host "ssh $SERVER_USER@$SERVER_IP" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "上传过程中出现错误: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "请检查网络连接和服务器配置" -ForegroundColor Yellow
}

Read-Host "按回车键退出"