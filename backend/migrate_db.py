#!/usr/bin/env python3
"""
数据库迁移脚本：将TimeCapsule表从密码模式迁移到问题答案模式
"""

import sqlite3
import os
from datetime import datetime

def migrate_database():
    """迁移数据库结构"""
    db_path = r'C:\Users\Administrator\PycharmProjects\timeline-notebook\backend\instance\timeline_new.db'
    
    if not os.path.exists(db_path):
        print("数据库文件不存在，无需迁移")
        return
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # 检查是否已经有question列
        cursor.execute("PRAGMA table_info(time_capsule)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'question' in columns:
            print("数据库已经是最新结构，无需迁移")
            return
        
        print("开始迁移数据库...")
        
        # 1. 创建新的表结构
        cursor.execute('''
            CREATE TABLE time_capsule_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title VARCHAR(100) NOT NULL,
                content TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                unlock_date DATETIME NOT NULL,
                question VARCHAR(255) NOT NULL,
                answer_hash VARCHAR(128) NOT NULL,
                media_type VARCHAR(20),
                media_path VARCHAR(255),
                is_unlocked BOOLEAN DEFAULT 0,
                unlock_attempts INTEGER DEFAULT 0
            )
        ''')
        
        # 2. 迁移现有数据（如果有的话）
        cursor.execute("SELECT COUNT(*) FROM time_capsule")
        count = cursor.fetchone()[0]
        
        if count > 0:
            print(f"发现 {count} 条现有记录，开始迁移...")
            
            # 获取现有数据
            cursor.execute('''
                SELECT id, title, content, created_at, unlock_date, 
                       password_hash, media_type, media_path, is_unlocked, unlock_attempts
                FROM time_capsule
            ''')
            
            old_records = cursor.fetchall()
            
            # 迁移数据，为旧记录设置默认问题
            for record in old_records:
                cursor.execute('''
                    INSERT INTO time_capsule_new 
                    (id, title, content, created_at, unlock_date, question, answer_hash,
                     media_type, media_path, is_unlocked, unlock_attempts)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    record[0],  # id
                    record[1],  # title
                    record[2],  # content
                    record[3],  # created_at
                    record[4],  # unlock_date
                    "这个时间胶囊的密码是什么？",  # 默认问题
                    record[5],  # password_hash -> answer_hash
                    record[6],  # media_type
                    record[7],  # media_path
                    record[8],  # is_unlocked
                    record[9]   # unlock_attempts
                ))
            
            print(f"成功迁移 {count} 条记录")
        
        # 3. 删除旧表
        cursor.execute("DROP TABLE time_capsule")
        
        # 4. 重命名新表
        cursor.execute("ALTER TABLE time_capsule_new RENAME TO time_capsule")
        
        # 提交更改
        conn.commit()
        print("数据库迁移完成！")
        
    except Exception as e:
        print(f"迁移失败: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    migrate_database()