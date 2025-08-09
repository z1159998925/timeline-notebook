@echo off
echo ========================================
echo Timeline Notebook - 本地开发环境启动
echo ========================================

REM 复制开发环境配置
copy .env.dev .env

REM 停止可能运行的容器
docker-compose -f docker-compose.dev.yml down

REM 启动开发环境
echo 正在启动开发环境...
docker-compose -f docker-compose.dev.yml up --build -d

REM 等待服务启动
echo 等待服务启动...
timeout /t 10 /nobreak > nul

REM 检查服务状态
echo 检查服务状态...
docker-compose -f docker-compose.dev.yml ps

echo.
echo ========================================
echo 开发环境启动完成！
echo ========================================
echo 前端访问地址: http://localhost
echo 后端API地址: http://localhost:5000
echo.
echo 停止开发环境: docker-compose -f docker-compose.dev.yml down
echo 查看日志: docker-compose -f docker-compose.dev.yml logs -f
echo ========================================

pause