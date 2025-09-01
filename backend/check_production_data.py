#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查生产环境数据问题
分析重复时间戳和空白数据的原因
"""

import sqlite3
import os
from datetime import datetime
from collections import Counter

def check_production_data():
    """检查生产环境数据问题"""
    
    # 数据库路径
    db_path = os.path.join(os.path.dirname(__file__), 'data', 'timeline.db')
    
    if not os.path.exists(db_path):
        print(f"❌ 数据库文件不存在: {db_path}")
        return
    
    print(f"📊 检查数据库: {db_path}")
    print(f"数据库大小: {os.path.getsize(db_path)} bytes")
    print("=" * 60)
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # 1. 检查时光轴数据
        print("\n🔍 检查时光轴数据 (timeline_entry)")
        cursor.execute("SELECT COUNT(*) FROM timeline_entry")
        total_entries = cursor.fetchone()[0]
        print(f"总记录数: {total_entries}")
        
        if total_entries > 0:
            # 检查重复时间戳
            cursor.execute("""
                SELECT created_at, COUNT(*) as count 
                FROM timeline_entry 
                GROUP BY created_at 
                HAVING COUNT(*) > 1
                ORDER BY count DESC
            """)
            duplicate_timestamps = cursor.fetchall()
            
            if duplicate_timestamps:
                print(f"\n⚠️  发现 {len(duplicate_timestamps)} 个重复时间戳:")
                for timestamp, count in duplicate_timestamps[:10]:  # 显示前10个
                    print(f"  {timestamp}: {count} 条记录")
            else:
                print("✅ 没有发现重复时间戳")
            
            # 检查空白数据
            cursor.execute("""
                SELECT id, title, content, created_at 
                FROM timeline_entry 
                WHERE title IS NULL OR title = '' OR content IS NULL OR content = ''
                ORDER BY created_at DESC
                LIMIT 10
            """)
            empty_entries = cursor.fetchall()
            
            if empty_entries:
                print(f"\n⚠️  发现 {len(empty_entries)} 条空白数据:")
                for entry in empty_entries:
                    print(f"  ID: {entry[0]}, 标题: '{entry[1]}', 内容: '{entry[2][:50]}...', 时间: {entry[3]}")
            else:
                print("✅ 没有发现空白数据")
            
            # 显示最近的数据
            cursor.execute("""
                SELECT id, title, content, created_at 
                FROM timeline_entry 
                ORDER BY created_at DESC 
                LIMIT 5
            """)
            recent_entries = cursor.fetchall()
            
            print("\n📝 最近的5条记录:")
            for entry in recent_entries:
                title = entry[1] or '(无标题)'
                content = (entry[2] or '(无内容)')[:50]
                print(f"  ID: {entry[0]}, 标题: {title}, 内容: {content}..., 时间: {entry[3]}")
        
        # 2. 检查时间胶囊数据
        print("\n\n🔍 检查时间胶囊数据 (time_capsule)")
        cursor.execute("SELECT COUNT(*) FROM time_capsule")
        total_capsules = cursor.fetchone()[0]
        print(f"总记录数: {total_capsules}")
        
        if total_capsules > 0:
            # 检查重复时间戳
            cursor.execute("""
                SELECT created_at, COUNT(*) as count 
                FROM time_capsule 
                GROUP BY created_at 
                HAVING COUNT(*) > 1
                ORDER BY count DESC
            """)
            duplicate_timestamps = cursor.fetchall()
            
            if duplicate_timestamps:
                print(f"\n⚠️  发现 {len(duplicate_timestamps)} 个重复时间戳:")
                for timestamp, count in duplicate_timestamps[:10]:
                    print(f"  {timestamp}: {count} 条记录")
            else:
                print("✅ 没有发现重复时间戳")
            
            # 显示最近的数据
            cursor.execute("""
                SELECT id, title, content, created_at, unlock_date 
                FROM time_capsule 
                ORDER BY created_at DESC 
                LIMIT 5
            """)
            recent_capsules = cursor.fetchall()
            
            print("\n📦 最近的5个时间胶囊:")
            for capsule in recent_capsules:
                title = capsule[1] or '(无标题)'
                content = (capsule[2] or '(无内容)')[:50]
                print(f"  ID: {capsule[0]}, 标题: {title}, 内容: {content}..., 创建: {capsule[3]}, 解锁: {capsule[4]}")
        
        # 3. 检查数据库表结构
        print("\n\n🏗️  数据库表结构:")
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        for table in tables:
            table_name = table[0]
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns = cursor.fetchall()
            print(f"\n表: {table_name}")
            for col in columns:
                print(f"  {col[1]} ({col[2]}) - {'NOT NULL' if col[3] else 'NULL'} - 默认值: {col[4]}")
        
        # 4. 检查数据创建时间分布
        print("\n\n📊 数据创建时间分布分析:")
        
        # 时光轴数据时间分布
        if total_entries > 0:
            cursor.execute("""
                SELECT DATE(created_at) as date, COUNT(*) as count
                FROM timeline_entry 
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 10
            """)
            date_distribution = cursor.fetchall()
            
            print("\n时光轴数据按日期分布:")
            for date, count in date_distribution:
                print(f"  {date}: {count} 条记录")
        
        # 时间胶囊数据时间分布
        if total_capsules > 0:
            cursor.execute("""
                SELECT DATE(created_at) as date, COUNT(*) as count
                FROM time_capsule 
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 10
            """)
            capsule_date_distribution = cursor.fetchall()
            
            print("\n时间胶囊数据按日期分布:")
            for date, count in capsule_date_distribution:
                print(f"  {date}: {count} 条记录")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ 检查数据库时出错: {e}")
        return
    
    print("\n" + "=" * 60)
    print("✅ 数据检查完成")

if __name__ == '__main__':
    check_production_data()