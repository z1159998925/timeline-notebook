import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from models import db, User, KeywordFilter
from flask import Flask
from config import config

def init_database():
    # 创建Flask应用实例
    app = Flask(__name__)
    config_name = os.environ.get('FLASK_ENV', 'production')
    app_config = config.get(config_name, config['production'])
    app.config.from_object(app_config)
    
    # 初始化数据库
    db.init_app(app)
    
    with app.app_context():
        # 创建所有表
        db.create_all()
        
        # 检查是否已存在管理员用户
        admin_user = User.query.filter_by(username='admin').first()
        if not admin_user:
            # 创建默认管理员用户
            admin_user = User(
                username='admin',
                role='admin'
            )
            admin_user.set_password('admin123')
            db.session.add(admin_user)
            db.session.commit()
    
        else:
    
        
        # 初始化关键词过滤数据
        if KeywordFilter.query.count() == 0:
            default_keywords = [
                '垃圾', '广告', '色情', '暴力', '政治', '反动',
                '法轮功', '六四', '天安门', '习近平', '共产党',
                '毒品', '赌博', '诈骗', '传销', '邪教'
            ]
            
            for keyword in default_keywords:
                filter_keyword = KeywordFilter(
                    keyword=keyword,
                    type='blacklist',
                    is_active=True
                )
                db.session.add(filter_keyword)
            
            db.session.commit()
    
        else:
    

if __name__ == '__main__':
    init_database()