from app import app
from models import db, User
from werkzeug.security import generate_password_hash

# 使用应用上下文
with app.app_context():
    # 检查是否已有管理员用户
    existing_admin = User.query.filter_by(role='admin').first()
    if existing_admin:

    else:
        # 创建新管理员用户
        admin_username = 'admin'
        admin_password = 'admin123'
        new_admin = User(
            username=admin_username,
            password_hash=generate_password_hash(admin_password),
            role='admin'
        )
        db.session.add(new_admin)
        db.session.commit()