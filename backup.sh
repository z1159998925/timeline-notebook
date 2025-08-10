#!/bin/bash

# Timeline Notebook 备份脚本
# 用于备份数据库、上传文件和配置

set -e

# 配置
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="timeline_backup_${TIMESTAMP}"

# 创建备份目录
mkdir -p "${BACKUP_DIR}"

echo "🔄 开始备份 Timeline Notebook..."
echo "备份时间: $(date)"
echo "备份目录: ${BACKUP_DIR}/${BACKUP_NAME}"

# 创建备份文件夹
CURRENT_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}"
mkdir -p "${CURRENT_BACKUP}"

# 1. 备份数据库
echo "📊 备份数据库..."
if [ -f "./data/timeline.db" ]; then
    cp "./data/timeline.db" "${CURRENT_BACKUP}/timeline.db"
    echo "✅ 数据库备份完成"
else
    echo "⚠️ 数据库文件不存在"
fi

# 2. 备份上传文件
echo "📁 备份上传文件..."
if [ -d "./static/uploads" ]; then
    cp -r "./static/uploads" "${CURRENT_BACKUP}/"
    echo "✅ 上传文件备份完成"
else
    echo "⚠️ 上传文件目录不存在"
fi

# 3. 备份配置文件
echo "⚙️ 备份配置文件..."
CONFIG_FILES=(
    ".env"
    ".env.production"
    "backend/.env"
    "frontend/.env"
    "frontend/.env.production"
    "docker-compose.yml"
    "nginx.conf"
)

mkdir -p "${CURRENT_BACKUP}/config"
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "${CURRENT_BACKUP}/config/"
        echo "✅ 备份配置文件: $file"
    else
        echo "⚠️ 配置文件不存在: $file"
    fi
done

# 4. 备份日志文件
echo "📝 备份日志文件..."
if [ -d "./logs" ]; then
    cp -r "./logs" "${CURRENT_BACKUP}/"
    echo "✅ 日志文件备份完成"
else
    echo "⚠️ 日志目录不存在"
fi

# 5. 创建备份信息文件
echo "📋 创建备份信息..."
cat > "${CURRENT_BACKUP}/backup_info.txt" << EOF
Timeline Notebook 备份信息
========================

备份时间: $(date)
备份版本: ${TIMESTAMP}
系统信息: $(uname -a)
Docker版本: $(docker --version 2>/dev/null || echo "Docker未安装")

备份内容:
- 数据库文件 (timeline.db)
- 上传文件目录 (uploads/)
- 配置文件 (config/)
- 日志文件 (logs/)

恢复说明:
1. 停止所有服务: docker-compose down
2. 恢复数据库: cp backup/timeline.db ./data/
3. 恢复上传文件: cp -r backup/uploads ./static/
4. 恢复配置文件: cp backup/config/* ./
5. 重启服务: docker-compose up -d

EOF

# 6. 压缩备份
echo "🗜️ 压缩备份文件..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"
cd ..

# 7. 清理旧备份（保留最近10个）
echo "🧹 清理旧备份..."
cd "${BACKUP_DIR}"
ls -t timeline_backup_*.tar.gz | tail -n +11 | xargs -r rm
cd ..

echo "✅ 备份完成！"
echo "备份文件: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "备份大小: $(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)"

# 8. 验证备份
echo "🔍 验证备份文件..."
if tar -tzf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" > /dev/null 2>&1; then
    echo "✅ 备份文件验证成功"
else
    echo "❌ 备份文件验证失败"
    exit 1
fi

echo "🎉 备份流程完成！"