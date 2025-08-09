from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
import hashlib

db = SQLAlchemy()

class TimelineEntry(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    media_type = db.Column(db.String(20), nullable=True)  # 'image', 'video', 'file'
    media_path = db.Column(db.String(255), nullable=True)
    likes = db.Column(db.Integer, default=0)

class Comment(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    entry_id = db.Column(db.Integer, db.ForeignKey('timeline_entry.id'), nullable=False)
    entry = db.relationship('TimelineEntry', backref=db.backref('comments', lazy=True))

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='user')  # 'user' or 'admin'

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class TimeCapsule(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    unlock_date = db.Column(db.DateTime, nullable=False)  # 解锁日期
    question = db.Column(db.String(255), nullable=False)  # 解锁问题
    answer_hash = db.Column(db.String(128), nullable=False)  # 答案哈希
    media_type = db.Column(db.String(20), nullable=True)  # 'image', 'video', 'file'
    media_path = db.Column(db.String(255), nullable=True)
    is_unlocked = db.Column(db.Boolean, default=False)  # 是否已解锁
    unlock_attempts = db.Column(db.Integer, default=0)  # 解锁尝试次数
    
    def set_answer(self, answer):
        """设置胶囊答案"""
        # 将答案转为小写并去除首尾空格，提高匹配成功率
        normalized_answer = answer.strip().lower()
        self.answer_hash = hashlib.sha256(normalized_answer.encode()).hexdigest()
    
    def check_answer(self, answer):
        """验证胶囊答案"""
        # 同样进行标准化处理
        normalized_answer = answer.strip().lower()
        return self.answer_hash == hashlib.sha256(normalized_answer.encode()).hexdigest()
    
    def can_unlock(self):
        """检查是否可以解锁（时间是否到达）"""
        return datetime.utcnow() >= self.unlock_date
    
    def get_remaining_time(self):
        """获取剩余时间（秒）"""
        if self.can_unlock():
            return 0
        return int((self.unlock_date - datetime.utcnow()).total_seconds())