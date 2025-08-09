@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo 🧪 Timeline Notebook 兼容性测试 (Windows)
echo =============================================
echo.

REM 检查系统信息
echo 📊 系统信息
echo 操作系统: %OS%
echo 架构: %PROCESSOR_ARCHITECTURE%
echo 计算机名: %COMPUTERNAME%
echo.

REM 检查 Node.js 版本
echo 🟢 Node.js 兼容性检查
where node >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
    echo ✅ Node.js 版本: !NODE_VERSION!
    
    REM 简单版本检查 (检查是否包含 v16 或更高)
    echo !NODE_VERSION! | findstr /r "v1[6-9]\|v[2-9][0-9]" >nul
    if !errorlevel! equ 0 (
        echo ✅ Node.js 版本兼容
    ) else (
        echo ❌ Node.js 版本过低，需要 16.0.0 或更高
    )
) else (
    echo ❌ Node.js 未安装
)

where npm >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('npm --version') do echo ✅ npm 版本: %%i
) else (
    echo ❌ npm 未安装
)
echo.

REM 检查 Python 版本
echo 🐍 Python 兼容性检查
where python >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
    echo ✅ Python 版本: !PYTHON_VERSION!
    
    REM 简单版本检查 (检查是否包含 3.8 或更高)
    echo !PYTHON_VERSION! | findstr /r "3\.[8-9]\|3\.1[0-9]" >nul
    if !errorlevel! equ 0 (
        echo ✅ Python 版本兼容
    ) else (
        echo ❌ Python 版本过低，需要 3.8.0 或更高
    )
) else (
    echo ❌ Python 未安装
)

where pip >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%i in ('pip --version') do echo ✅ pip 版本: %%i
) else (
    echo ❌ pip 未安装
)
echo.

REM 检查 Docker 版本
echo 🐳 Docker 兼容性检查
where docker >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('docker --version') do (
        set DOCKER_VERSION=%%i
        set DOCKER_VERSION=!DOCKER_VERSION:,=!
        echo ✅ Docker 版本: !DOCKER_VERSION!
    )
    
    REM 检查 Docker Compose
    docker compose version >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=4" %%i in ('docker compose version') do echo ✅ Docker Compose V2: %%i
    ) else (
        echo ❌ Docker Compose V2 未安装
    )
    
    REM 检查 Docker 服务状态
    docker info >nul 2>&1
    if !errorlevel! equ 0 (
        echo ✅ Docker 服务运行正常
    ) else (
        echo ❌ Docker 服务未运行
    )
) else (
    echo ❌ Docker 未安装
)
echo.

REM 检查端口可用性
echo 🔌 端口兼容性检查
netstat -an | findstr ":5000 " >nul
if %errorlevel% equ 0 (
    echo ⚠️ 端口 5000 ^(后端API^): 已被占用
) else (
    echo ✅ 端口 5000 ^(后端API^): 可用
)

netstat -an | findstr ":5173 " >nul
if %errorlevel% equ 0 (
    echo ⚠️ 端口 5173 ^(前端开发^): 已被占用
) else (
    echo ✅ 端口 5173 ^(前端开发^): 可用
)

netstat -an | findstr ":80 " >nul
if %errorlevel% equ 0 (
    echo ⚠️ 端口 80 ^(HTTP^): 已被占用
) else (
    echo ✅ 端口 80 ^(HTTP^): 可用
)

netstat -an | findstr ":443 " >nul
if %errorlevel% equ 0 (
    echo ⚠️ 端口 443 ^(HTTPS^): 已被占用
) else (
    echo ✅ 端口 443 ^(HTTPS^): 可用
)
echo.

REM 检查磁盘空间
echo 💾 磁盘空间检查
for /f "tokens=3" %%i in ('dir /-c ^| findstr /r "可用字节"') do (
    set DISK_FREE=%%i
    echo 可用磁盘空间: !DISK_FREE! 字节
)
echo ✅ 磁盘空间检查完成
echo.

REM 检查网络连接
echo 🌐 网络连接检查
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 互联网连接正常
) else (
    echo ⚠️ 互联网连接异常
)
echo.

REM 前端依赖检查
echo 📦 前端依赖兼容性检查
if exist "frontend\package.json" (
    echo ✅ package.json 存在
    
    if exist "frontend\package-lock.json" (
        echo ✅ package-lock.json 存在
    ) else (
        echo ⚠️ package-lock.json 不存在
    )
    
    if exist "frontend\node_modules" (
        echo ✅ node_modules 存在
    ) else (
        echo ⚠️ node_modules 不存在，需要运行 npm install
    )
) else (
    echo ❌ frontend\package.json 不存在
)
echo.

REM 后端依赖检查
echo 🐍 后端依赖兼容性检查
if exist "backend\requirements.txt" (
    echo ✅ requirements.txt 存在
    echo 关键依赖版本:
    findstr /r "^Flask" backend\requirements.txt
    findstr /r "^gunicorn" backend\requirements.txt
) else (
    echo ❌ backend\requirements.txt 不存在
)
echo.

REM 配置文件检查
echo ⚙️ 配置文件检查
set config_files=.env.dev .env.production .env.server docker-compose-http.yml nginx-http.conf nginx-domain.conf

for %%f in (%config_files%) do (
    if exist "%%f" (
        echo ✅ %%f 存在
    ) else (
        echo ⚠️ %%f 不存在
    )
)
echo.

REM 部署脚本检查
echo 🚀 部署脚本检查
if exist "setup-server-environment.sh" (
    echo ✅ setup-server-environment.sh 存在
) else (
    echo ❌ setup-server-environment.sh 不存在
)

if exist "deploy-project.sh" (
    echo ✅ deploy-project.sh 存在
) else (
    echo ❌ deploy-project.sh 不存在
)
echo.

REM 总结
echo 📋 兼容性检查总结
echo =============================================
echo ✅ 表示通过检查
echo ⚠️ 表示需要注意  
echo ❌ 表示需要修复
echo.
echo 详细兼容性信息请查看: COMPATIBILITY-REPORT.md
echo.
echo 🎉 兼容性检查完成！
echo.
pause