import sqlite3
import os
from datetime import datetime
import json

def analyze_data_quality():
    db_path = os.path.join(os.path.dirname(__file__), 'data', 'timeline.db')
    
    if not os.path.exists(db_path):
        print(f"数据库文件不存在: {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("=== 数据库数据质量分析报告 ===")
    print(f"数据库文件: {db_path}")
    print(f"文件大小: {os.path.getsize(db_path)} bytes")
    print()
    
    # 获取所有表名
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = cursor.fetchall()
    
    data_quality_issues = []
    
    for table_name in tables:
        table = table_name[0]
        print(f"\n=== 分析表: {table} ===")
        
        # 获取表结构
        cursor.execute(f"PRAGMA table_info({table})")
        columns = cursor.fetchall()
        
        print(f"表结构:")
        for col in columns:
            print(f"  {col[1]} ({col[2]}) - {'NOT NULL' if col[3] else 'NULL'}")
        
        # 获取记录数
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"记录数: {count}")
        
        if count == 0:
            print("表为空，跳过数据质量检查")
            continue
        
        # 检查每个字段的数据质量
        for col in columns:
            col_name = col[1]
            col_type = col[2]
            
            print(f"\n检查字段: {col_name} ({col_type})")
            
            # 检查NULL值
            cursor.execute(f"SELECT COUNT(*) FROM {table} WHERE {col_name} IS NULL")
            null_count = cursor.fetchone()[0]
            if null_count > 0:
                print(f"  ⚠️  NULL值: {null_count} 条")
                data_quality_issues.append(f"{table}.{col_name}: {null_count} 条NULL值")
            
            # 检查空字符串
            if 'TEXT' in col_type.upper() or 'VARCHAR' in col_type.upper():
                cursor.execute(f"SELECT COUNT(*) FROM {table} WHERE {col_name} = ''")
                empty_count = cursor.fetchone()[0]
                if empty_count > 0:
                    print(f"  ⚠️  空字符串: {empty_count} 条")
                    data_quality_issues.append(f"{table}.{col_name}: {empty_count} 条空字符串")
            
            # 检查日期时间字段
            if any(keyword in col_name.lower() for keyword in ['date', 'time', 'created', 'updated']):
                print(f"  检查日期时间格式...")
                
                # 获取所有非NULL值
                cursor.execute(f"SELECT {col_name} FROM {table} WHERE {col_name} IS NOT NULL LIMIT 10")
                date_samples = cursor.fetchall()
                
                invalid_dates = []
                for sample in date_samples:
                    date_value = sample[0]
                    if date_value:
                        try:
                            # 尝试解析日期
                            if isinstance(date_value, str):
                                # 尝试多种日期格式
                                formats = [
                                    '%Y-%m-%d %H:%M:%S',
                                    '%Y-%m-%d',
                                    '%Y-%m-%dT%H:%M:%S',
                                    '%Y-%m-%dT%H:%M:%S.%f'
                                ]
                                parsed = False
                                for fmt in formats:
                                    try:
                                        datetime.strptime(date_value, fmt)
                                        parsed = True
                                        break
                                    except ValueError:
                                        continue
                                
                                if not parsed:
                                    invalid_dates.append(date_value)
                        except Exception as e:
                            invalid_dates.append(f"{date_value} (错误: {e})")
                
                if invalid_dates:
                    print(f"  ⚠️  无效日期格式: {len(invalid_dates)} 条")
                    for invalid in invalid_dates[:3]:  # 只显示前3个
                        print(f"    - {invalid}")
                    data_quality_issues.append(f"{table}.{col_name}: {len(invalid_dates)} 条无效日期")
                else:
                    print(f"  ✅ 日期格式正常")
            
            # 检查数值字段的异常值
            if 'INTEGER' in col_type.upper() or 'REAL' in col_type.upper():
                cursor.execute(f"SELECT MIN({col_name}), MAX({col_name}), AVG({col_name}) FROM {table} WHERE {col_name} IS NOT NULL")
                stats = cursor.fetchone()
                if stats[0] is not None:
                    print(f"  数值范围: {stats[0]} ~ {stats[1]}, 平均值: {stats[2]:.2f}")
                    
                    # 检查负值（如果字段名暗示应该是正数）
                    if any(keyword in col_name.lower() for keyword in ['count', 'size', 'length', 'id']) and stats[0] < 0:
                        print(f"  ⚠️  发现负值: 最小值 {stats[0]}")
                        data_quality_issues.append(f"{table}.{col_name}: 存在负值 {stats[0]}")
        
        # 显示前5条记录作为样本
        print(f"\n前5条记录样本:")
        cursor.execute(f"SELECT * FROM {table} LIMIT 5")
        samples = cursor.fetchall()
        col_names = [col[1] for col in columns]
        
        for i, sample in enumerate(samples, 1):
            print(f"  记录 {i}:")
            for j, value in enumerate(sample):
                print(f"    {col_names[j]}: {value}")
    
    # 总结数据质量问题
    print(f"\n\n=== 数据质量问题总结 ===")
    if data_quality_issues:
        print(f"发现 {len(data_quality_issues)} 个数据质量问题:")
        for issue in data_quality_issues:
            print(f"  ❌ {issue}")
        
        print(f"\n=== 建议的清理操作 ===")
        print("1. 清理NULL值和空字符串")
        print("2. 修复无效的日期格式")
        print("3. 检查并修正异常的数值")
        print("4. 考虑添加数据验证约束")
    else:
        print("✅ 未发现明显的数据质量问题")
    
    conn.close()

if __name__ == '__main__':
    analyze_data_quality()