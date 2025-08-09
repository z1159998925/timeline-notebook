@echo off
echo ========================================
echo Timeline Notebook - 停止本地开发环境
echo ========================================

REM 停止开发环境容器
docker-compose -f docker-compose.dev.yml down

echo 开发环境已停止！
echo ========================================

pause