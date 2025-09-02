# 时光轴笔记项目 - Windows服务器部署脚本
# 自动化Docker容器部署流程

param(
    [switch]$Help,
    [switch]$Http,
    [switch]$Https,
    [switch]$BuildOnly,
    [switch]$NoBuild
)

# 配置变量
$ProjectName = "timeline-notebook"
$DockerComposeFile = "docker-compose.yml"
$HttpComposeFile = "docker-compose-http.yml"
$EnvFile = ".env.production"

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARN] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "[STEP] $Message" "Blue"
}

# 显示横幅
function Show-Banner {
    Write-ColorOutput "================================================" "Blue"
    Write-ColorOutput "    时光轴笔记项目 - Windows服务器部署脚本" "Blue"
    Write-ColorOutput "================================================" "Blue"
    Write-Host ""
}

# 显示帮助信息
function Show-Help {
    Write-Host "用法：.\deploy.ps1 [选项]"
    Write-Host "选项："
    Write-Host "  -Help          显示帮助信息"
    Write-Host "  -Http          强制使用HTTP模式"
    Write-Host "  -Https         强制使用HTTPS模式"
    Write-Host "  -BuildOnly     仅构建镜像，不启动服务"
    Write-Host "  -NoBuild       跳过镜像构建，直接启动服务"
    Write-Host ""
    Write-Host "示例："
    Write-Host "  .\deploy.ps1                # 交互式部署"
    Write-Host "  .\deploy.ps1 -Http          # HTTP模式部署"
    Write-Host "  .\deploy.ps1 -Https         # HTTPS模式部署"
    Write-Host "  .\deploy.ps1 -BuildOnly     # 仅构建镜像"
}

# 检查系统要求
function Test-Requirements {
    Write-Step "检查系统要求..."
    
    # 检查Docker
    try {
        $dockerVersion = docker --version 2>$null
        if (-not $dockerVersion) {
            throw "Docker未找到"
        }
        Write-Info "Docker已安装: $dockerVersion"
    }
    catch {
        Write-Error "Docker未安装，请先安装Docker Desktop for Windows"
        Write-Host "下载地址：https://www.docker.com/products/docker-desktop"
        exit 1
    }
    
    # 检查Docker Compose
    try {
        $composeVersion = docker-compose --version 2>$null
        if (-not $composeVersion) {
            throw "Docker Compose未找到"
        }
        Write-Info "Docker Compose已安装: $composeVersion"
    }
    catch {
        Write-Error "Docker Compose未安装，请确保Docker Desktop已正确安装"
        exit 1
    }
    
    # 检查Docker服务状态
    try {
        docker ps 2>$null | Out-Null
        Write-Info "Docker服务运行正常"
    }
    catch {
        Write-Error "Docker服务未运行，请启动Docker Desktop"
        exit 1
    }
    
    Write-Info "系统要求检查通过"
}

# 创建必要目录
function New-Directories {
    Write-Step "创建必要目录..."
    
    # 创建数据目录
    $directories = @("data\uploads", "data\logs", "data\db")
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Info "创建目录: $dir"
        }
    }
    
    Write-Info "目录创建完成"
}

# 配置环境变量
function Set-Environment {
    Write-Step "配置环境变量..."
    
    if (-not (Test-Path $EnvFile)) {
        Write-Warning "环境配置文件不存在，创建默认配置..."
        
        # 生成随机密钥
        $secretKey = -join ((1..64) | ForEach {Get-Random -input ([char[]]'0123456789abcdef')})
        
        $envContent = @"
# 生产环境配置
FLASK_ENV=production
SECRET_KEY=$secretKey
DATABASE_URL=sqlite:///data/timeline.db
UPLOAD_FOLDER=/app/data/uploads
MAX_CONTENT_LENGTH=104857600
DOMAIN=localhost
CORS_ORIGINS=https://localhost,http://localhost
LOG_LEVEL=INFO

# 会话配置
SESSION_COOKIE_SECURE=True
SESSION_COOKIE_HTTPONLY=True
SESSION_COOKIE_SAMESITE=Lax
"@
        
        $envContent | Out-File -FilePath $EnvFile -Encoding UTF8
        Write-Info "默认环境配置已创建，请根据需要修改 $EnvFile"
    }
    else {
        Write-Info "环境配置文件已存在"
    }
}

# 选择部署模式
function Select-DeploymentMode {
    Write-Host ""
    Write-Host "请选择部署模式："
    Write-Host "1. HTTPS模式（推荐，需要SSL证书）"
    Write-Host "2. HTTP模式（测试用）"
    Write-Host ""
    
    do {
        $mode = Read-Host "请输入选择 (1/2)"
        switch ($mode) {
            "1" {
                $script:DeploymentMode = "https"
                $script:ComposeFile = $DockerComposeFile
                break
            }
            "2" {
                $script:DeploymentMode = "http"
                $script:ComposeFile = $HttpComposeFile
                break
            }
            default {
                Write-Error "无效选择，请输入1或2"
                continue
            }
        }
        break
    } while ($true)
    
    Write-Info "选择了 $script:DeploymentMode 部署模式"
}

# 检查SSL证书（HTTPS模式）
function Test-SslCertificates {
    if ($script:DeploymentMode -eq "https") {
        Write-Step "检查SSL证书..."
        
        $sslPath = "C:\nginx\ssl"
        $certFile = Join-Path $sslPath "fullchain.pem"
        $keyFile = Join-Path $sslPath "privkey.pem"
        
        if (-not (Test-Path $certFile) -or -not (Test-Path $keyFile)) {
            Write-Warning "SSL证书不存在"
            Write-Host "请先配置SSL证书："
            Write-Host "1. 手动配置证书到 C:\nginx\ssl\ 目录"
            Write-Host "2. 查看 SSL-CERTIFICATE-GUIDE.md 获取详细说明"
            Write-Host ""
            
            $continue = Read-Host "是否继续部署？(y/N)"
            if ($continue -notmatch '^[Yy]$') {
                Write-Info "部署已取消"
                exit 0
            }
        }
        else {
            Write-Info "SSL证书检查通过"
        }
    }
}

# 构建镜像
function Build-Images {
    Write-Step "构建Docker镜像..."
    
    try {
        # 构建后端镜像
        Write-Info "构建后端镜像..."
        docker build -f Dockerfile.backend -t timeline-backend:latest .
        if ($LASTEXITCODE -ne 0) {
            throw "后端镜像构建失败"
        }
        
        # 构建前端镜像
        Write-Info "构建前端镜像..."
        if ($script:DeploymentMode -eq "https") {
            docker build -f Dockerfile.frontend.production -t timeline-frontend:latest .
        }
        else {
            docker build -f Dockerfile.frontend.server -t timeline-frontend:latest .
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "前端镜像构建失败"
        }
        
        Write-Info "镜像构建完成"
    }
    catch {
        Write-Error "镜像构建失败: $_"
        exit 1
    }
}

# 启动服务
function Start-Services {
    Write-Step "启动服务..."
    
    try {
        # 停止现有服务
        Write-Info "停止现有服务..."
        docker-compose -f $script:ComposeFile down 2>$null
        
        # 启动新服务
        Write-Info "启动新服务..."
        docker-compose -f $script:ComposeFile up -d
        
        if ($LASTEXITCODE -ne 0) {
            throw "服务启动失败"
        }
        
        # 等待服务启动
        Write-Info "等待服务启动..."
        Start-Sleep -Seconds 10
        
        # 检查服务状态
        Write-Info "检查服务状态..."
        docker-compose -f $script:ComposeFile ps
    }
    catch {
        Write-Error "服务启动失败: $_"
        exit 1
    }
}

# 验证部署
function Test-Deployment {
    Write-Step "验证部署..."
    
    try {
        # 检查容器状态
        $failedServices = docker-compose -f $script:ComposeFile ps --services --filter "status=exited" 2>$null
        
        if ($failedServices) {
            Write-Error "以下服务启动失败：$failedServices"
            Write-Info "查看日志：docker-compose -f $script:ComposeFile logs"
            return $false
        }
        
        # 测试健康检查
        Write-Info "测试服务健康状态..."
        
        if ($script:DeploymentMode -eq "https") {
            $healthUrl = "https://localhost/health"
        }
        else {
            $healthUrl = "http://localhost/health"
        }
        
        # 等待服务完全启动
        $maxAttempts = 30
        $attempt = 1
        
        while ($attempt -le $maxAttempts) {
            try {
                $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5 2>$null
                if ($response.StatusCode -eq 200) {
                    Write-Info "健康检查通过"
                    break
                }
            }
            catch {
                # 忽略错误，继续尝试
            }
            
            if ($attempt -eq $maxAttempts) {
                Write-Warning "健康检查超时，但服务可能仍在启动中"
                break
            }
            
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
            $attempt++
        }
        
        Write-Host ""
        Write-Info "部署验证完成"
        return $true
    }
    catch {
        Write-Error "部署验证失败: $_"
        return $false
    }
}

# 显示部署信息
function Show-DeploymentInfo {
    Write-Step "部署信息"
    
    Write-Host ""
    Write-ColorOutput "=== 部署完成 ===" "Green"
    Write-Host "部署模式：$script:DeploymentMode"
    Write-Host "配置文件：$script:ComposeFile"
    Write-Host ""
    
    if ($script:DeploymentMode -eq "https") {
        Write-Host "访问地址：https://your-domain.com"
        Write-Host "健康检查：https://your-domain.com/health"
    }
    else {
        Write-Host "访问地址：http://localhost"
        Write-Host "健康检查：http://localhost/health"
    }
    
    Write-Host ""
    Write-ColorOutput "=== 常用命令 ===" "Yellow"
    Write-Host "查看服务状态：docker-compose -f $script:ComposeFile ps"
    Write-Host "查看日志：docker-compose -f $script:ComposeFile logs"
    Write-Host "重启服务：docker-compose -f $script:ComposeFile restart"
    Write-Host "停止服务：docker-compose -f $script:ComposeFile down"
    Write-Host "更新服务：.\deploy.ps1"
    Write-Host ""
    
    Write-ColorOutput "=== 文档参考 ===" "Cyan"
    Write-Host "服务器部署指南：SERVER-DEPLOYMENT-GUIDE.md"
    Write-Host "SSL证书配置：SSL-CERTIFICATE-GUIDE.md"
    Write-Host ""
}

# 主函数
function Main {
    # 显示帮助
    if ($Help) {
        Show-Help
        exit 0
    }
    
    Show-Banner
    
    # 设置部署参数
    $script:BuildImages = -not $NoBuild
    $script:StartServices = -not $BuildOnly
    
    # 解析部署模式
    if ($Http) {
        $script:DeploymentMode = "http"
        $script:ComposeFile = $HttpComposeFile
    }
    elseif ($Https) {
        $script:DeploymentMode = "https"
        $script:ComposeFile = $DockerComposeFile
    }
    
    try {
        # 执行部署步骤
        Test-Requirements
        New-Directories
        Set-Environment
        
        # 如果没有指定模式，让用户选择
        if (-not $script:DeploymentMode) {
            Select-DeploymentMode
        }
        
        Test-SslCertificates
        
        if ($script:BuildImages) {
            Build-Images
        }
        
        if ($script:StartServices) {
            Start-Services
            $deploymentSuccess = Test-Deployment
            
            if ($deploymentSuccess) {
                Show-DeploymentInfo
            }
            else {
                Write-Error "部署验证失败，请检查日志"
                exit 1
            }
        }
        
        Write-Info "部署脚本执行完成！"
    }
    catch {
        Write-Error "部署过程中发生错误: $_"
        Write-Info "查看错误日志：docker-compose -f $script:ComposeFile logs"
        exit 1
    }
}

# 运行主函数
Main