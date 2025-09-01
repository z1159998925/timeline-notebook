import sqlite3
import os
from datetime import datetime

# 检查数据库文件
db_path = os.path.join(os.getcwd(), 'data', 'timeline.db')
print(f'数据库路径: {db_path}')
print(f'文件存在: {os.path.exists(db_path)}')

if os.path.exists(db_path):
    print(f'文件大小: {os.path.getsize(db_path)} bytes')

# 连接数据库
try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 获取所有表
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    print(f'\n数据库表: {[table[0] for table in tables]}')
    
    # 检查每个表的数据
    for table in tables:
        table_name = table[0]
        print(f'\n=== 表: {table_name} ===')
        
        # 获取表结构
        cursor.execute(f"PRAGMA table_info({table_name})")
        columns = cursor.fetchall()
        print(f'字段: {[(col[1], col[2]) for col in columns]}')
        
        # 获取记录数
        cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
        count = cursor.fetchone()[0]
        print(f'记录数: {count}')
        
        # 如果有数据，显示前5条记录
        if count > 0:
            cursor.execute(f"SELECT * FROM {table_name} LIMIT 5")
            rows = cursor.fetchall()
            print(f'前5条记录:')
            for i, row in enumerate(rows, 1):
                print(f'  {i}: {row}')
                
            # 检查日期字段的数据质量
            date_columns = [col[1] for col in columns if 'date' in col[1].lower() or 'time' in col[1].lower()]
            if date_columns:
                print(f'\n日期字段数据质量检查:')
                for date_col in date_columns:
                    # 检查NULL值
                    cursor.execute(f"SELECT COUNT(*) FROM {table_name} WHERE {date_col} IS NULL")
                    null_count = cursor.fetchone()[0]
                    print(f'  {date_col} - NULL值: {null_count}')
                    
                    # 检查空字符串
                    cursor.execute(f"SELECT COUNT(*) FROM {table_name} WHERE {date_col} = ''")
                    empty_count = cursor.fetchone()[0]
                    print(f'  {date_col} - 空字符串: {empty_count}')
                    
                    # 显示一些样本数据
                    cursor.execute(f"SELECT {date_col} FROM {table_name} WHERE {date_col} IS NOT NULL AND {date_col} != '' LIMIT 3")
                    samples = cursor.fetchall()
                    print(f'  {date_col} - 样本数据: {[s[0] for s in samples]}')
    
    conn.close()
    print('\n数据库检查完成')
    
except Exception as e:
    print(f'数据库检查出错: {e}')