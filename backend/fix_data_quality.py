import sqlite3
import os
from datetime import datetime

def fix_data_quality():
    db_path = os.path.join(os.path.dirname(__file__), 'data', 'timeline.db')
    
    if not os.path.exists(db_path):
        print(f"数据库文件不存在: {db_path}")
        return
    
    # 备份数据库
    backup_path = db_path + '.backup.' + datetime.now().strftime('%Y%m%d_%H%M%S')
    import shutil
    shutil.copy2(db_path, backup_path)
    print(f"数据库已备份到: {backup_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("\n=== 开始修复数据质量问题 ===")
    
    try:
        # 1. 修复用户表的日期格式问题
        print("\n1. 修复用户表的日期格式...")
        
        # 获取当前时间作为默认值
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # 修复 created_at 字段
        cursor.execute("""
            UPDATE user 
            SET created_at = ? 
            WHERE created_at IS NULL OR created_at = '' OR 
                  created_at NOT LIKE '____-__-__ __:__:__'
        """, (current_time,))
        
        affected_rows = cursor.rowcount
        print(f"  修复了 {affected_rows} 条用户的 created_at 字段")
        
        # 修复 updated_at 字段
        cursor.execute("""
            UPDATE user 
            SET updated_at = ? 
            WHERE updated_at IS NULL OR updated_at = '' OR 
                  updated_at NOT LIKE '____-__-__ __:__:__'
        """, (current_time,))
        
        affected_rows = cursor.rowcount
        print(f"  修复了 {affected_rows} 条用户的 updated_at 字段")
        
        # 2. 修复关键词过滤表的日期格式
        print("\n2. 修复关键词过滤表的日期格式...")
        
        cursor.execute("""
            UPDATE keyword_filters 
            SET created_at = ? 
            WHERE created_at IS NULL OR created_at = '' OR 
                  created_at NOT LIKE '____-__-__ __:__:__'
        """, (current_time,))
        
        affected_rows = cursor.rowcount
        print(f"  修复了 {affected_rows} 条关键词过滤的 created_at 字段")
        
        # 3. 处理用户表的NULL值（设置合理的默认值）
        print("\n3. 处理用户表的NULL值...")
        
        # 为email设置默认值（如果需要的话，可以设置为空字符串或保持NULL）
        # 这里我们保持email为NULL，因为这是合理的
        
        # 为avatar_url设置默认值
        cursor.execute("""
            UPDATE user 
            SET avatar_url = '/default-avatar.png' 
            WHERE avatar_url IS NULL
        """)
        affected_rows = cursor.rowcount
        print(f"  为 {affected_rows} 个用户设置了默认头像")
        
        # 为bio设置默认值
        cursor.execute("""
            UPDATE user 
            SET bio = '这个用户很懒，什么都没有留下。' 
            WHERE bio IS NULL
        """)
        affected_rows = cursor.rowcount
        print(f"  为 {affected_rows} 个用户设置了默认简介")
        
        # last_login保持NULL是合理的，表示从未登录
        
        # 4. 处理用户活动表的NULL值
        print("\n4. 处理用户活动表的NULL值...")
        
        # 为ip_address设置默认值
        cursor.execute("""
            UPDATE user_activities 
            SET ip_address = '127.0.0.1' 
            WHERE ip_address IS NULL
        """)
        affected_rows = cursor.rowcount
        print(f"  为 {affected_rows} 条活动记录设置了默认IP地址")
        
        # 为user_agent设置默认值
        cursor.execute("""
            UPDATE user_activities 
            SET user_agent = 'Unknown' 
            WHERE user_agent IS NULL
        """)
        affected_rows = cursor.rowcount
        print(f"  为 {affected_rows} 条活动记录设置了默认用户代理")
        
        # 5. 验证修复结果
        print("\n5. 验证修复结果...")
        
        # 检查用户表
        cursor.execute("SELECT COUNT(*) FROM user WHERE created_at IS NULL OR created_at = ''")
        invalid_created = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM user WHERE updated_at IS NULL OR updated_at = ''")
        invalid_updated = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM user WHERE avatar_url IS NULL")
        null_avatar = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM user WHERE bio IS NULL")
        null_bio = cursor.fetchone()[0]
        
        print(f"  用户表验证结果:")
        print(f"    无效 created_at: {invalid_created} 条")
        print(f"    无效 updated_at: {invalid_updated} 条")
        print(f"    NULL avatar_url: {null_avatar} 条")
        print(f"    NULL bio: {null_bio} 条")
        
        # 检查关键词过滤表
        cursor.execute("SELECT COUNT(*) FROM keyword_filters WHERE created_at IS NULL OR created_at = ''")
        invalid_keyword_created = cursor.fetchone()[0]
        print(f"  关键词过滤表验证结果:")
        print(f"    无效 created_at: {invalid_keyword_created} 条")
        
        # 检查用户活动表
        cursor.execute("SELECT COUNT(*) FROM user_activities WHERE ip_address IS NULL")
        null_ip = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM user_activities WHERE user_agent IS NULL")
        null_agent = cursor.fetchone()[0]
        
        print(f"  用户活动表验证结果:")
        print(f"    NULL ip_address: {null_ip} 条")
        print(f"    NULL user_agent: {null_agent} 条")
        
        # 提交更改
        conn.commit()
        print("\n✅ 数据质量修复完成！")
        
        # 6. 提供进一步的建议
        print("\n=== 进一步的建议 ===")
        print("1. 考虑在应用层添加数据验证，确保新数据的质量")
        print("2. 定期运行数据质量检查脚本")
        print("3. 考虑添加数据库约束来防止无效数据")
        print("4. 实现更严格的前端表单验证")
        print("5. 考虑使用数据库触发器来自动设置默认值")
        
    except Exception as e:
        print(f"❌ 修复过程中出现错误: {e}")
        conn.rollback()
        print("已回滚所有更改")
    
    finally:
        conn.close()

if __name__ == '__main__':
    fix_data_quality()