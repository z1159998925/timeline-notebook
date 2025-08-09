@echo off
REM Timeline Notebook 服务器上传脚本
REM 适用于Windows本地环境

echo ========================================
echo Timeline Notebook 服务器上传脚本
echo ========================================
echo.

REM 配置变量（请根据实际情况修改）
set /p SERVER_IP="请输入服务器IP地址: "
set /p SERVER_USER="请输入服务器用户名 (默认root): " || set SERVER_USER=root
set SERVER_PATH=/opt/timeline-notebook

echo 请确保已配置以下信息：
echo 服务器IP: %SERVER_IP%
echo 服务器用户: %SERVER_USER%
echo 服务器路径: %SERVER_PATH%
echo.

REM 检查是否安装了scp或rsync
where scp >nul 2>nul
if %errorlevel% neq 0 (
    echo 错误: 未找到 scp 命令
    echo 请安装 Git for Windows 或 OpenSSH
    pause
    exit /b 1
)

echo 开始上传文件到服务器...
echo.

REM 创建服务器目录
echo 1. 创建服务器目录...
ssh %SERVER_USER%@%SERVER_IP% "mkdir -p %SERVER_PATH%"

REM 上传主要文件
echo 2. 上传应用文件...
scp -r backend %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp -r frontend %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp -r static %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/

REM 上传配置文件
echo 3. 上传配置文件...
scp docker-compose-server.yml %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp Dockerfile.backend %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp Dockerfile.frontend.server %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp nginx-domain.conf %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp .env.server %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/

REM 上传部署脚本
echo 4. 上传部署脚本...
scp deploy-server.sh %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp install-docker-ubuntu.sh %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/
scp DEPLOY-SERVER.md %SERVER_USER%@%SERVER_IP%:%SERVER_PATH%/

REM 设置脚本权限
echo 5. 设置脚本权限...
ssh %SERVER_USER%@%SERVER_IP% "chmod +x %SERVER_PATH%/deploy-server.sh"
ssh %SERVER_USER%@%SERVER_IP% "chmod +x %SERVER_PATH%/install-docker-ubuntu.sh"

echo.
echo ========================================
echo 文件上传完成！
echo ========================================
echo.
echo 接下来请在服务器上执行：
echo 1. cd %SERVER_PATH%
echo 2. sudo ./install-docker-ubuntu.sh  (如果未安装Docker)
echo 3. sudo ./deploy-server.sh
echo.
echo 或者手动连接到服务器：
echo ssh %SERVER_USER%@%SERVER_IP%
echo.

pause