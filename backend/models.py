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
    email = db.Column(db.String(255), nullable=True)
    bio = db.Column(db.Text, nullable=True)  # 用户简介
    avatar_url = db.Column(db.String(500), nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = db.Column(db.DateTime, nullable=True)  # 最后登录时间
    login_count = db.Column(db.Integer, default=0)  # 登录次数

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def get_avatar_url(self):
        """获取用户头像URL，如果没有上传头像则返回默认头像"""
        if self.avatar_url:
            return self.avatar_url
        # 使用用户名首字母生成默认头像URL
        first_letter = self.username[0].upper() if self.username else 'U'
        return f'/api/avatar/default/{first_letter}'

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


# 留言墙相关模型
class Message(db.Model):
    """留言模型"""
    __tablename__ = 'messages'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    is_pinned = db.Column(db.Boolean, default=False)
    status = db.Column(db.String(20), default='published')  # published, pending, rejected
    like_count = db.Column(db.Integer, default=0)
    comment_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关系
    user = db.relationship('User', backref=db.backref('messages', lazy=True))
    comments = db.relationship('MessageComment', backref='message', lazy=True, cascade='all, delete-orphan')
    likes = db.relationship('MessageLike', backref='message', lazy=True, cascade='all, delete-orphan')
    images = db.relationship('MessageImage', backref='message', lazy=True, cascade='all, delete-orphan')


class MessageComment(db.Model):
    """留言评论模型"""
    __tablename__ = 'message_comments'
    
    id = db.Column(db.Integer, primary_key=True)
    message_id = db.Column(db.Integer, db.ForeignKey('messages.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    parent_id = db.Column(db.Integer, db.ForeignKey('message_comments.id'), nullable=True)  # 父评论ID，支持嵌套回复
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关系
    user = db.relationship('User', backref=db.backref('message_comments', lazy=True))
    parent = db.relationship('MessageComment', remote_side=[id], backref='replies')


class MessageLike(db.Model):
    """留言点赞模型"""
    __tablename__ = 'message_likes'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    message_id = db.Column(db.Integer, db.ForeignKey('messages.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # 关系
    user = db.relationship('User', backref=db.backref('message_likes', lazy=True))
    
    # 唯一约束，防止重复点赞
    __table_args__ = (db.UniqueConstraint('user_id', 'message_id', name='unique_user_message_like'),)


class MessageImage(db.Model):
    """留言图片模型"""
    __tablename__ = 'message_images'
    
    id = db.Column(db.Integer, primary_key=True)
    message_id = db.Column(db.Integer, db.ForeignKey('messages.id'), nullable=False)
    image_url = db.Column(db.String(500), nullable=False)
    image_name = db.Column(db.String(255), nullable=False)
    file_size = db.Column(db.Integer, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class KeywordFilter(db.Model):
    """关键词过滤模型"""
    __tablename__ = 'keyword_filters'
    
    id = db.Column(db.Integer, primary_key=True)
    keyword = db.Column(db.String(100), nullable=False)
    type = db.Column(db.String(20), default='blacklist')  # blacklist, sensitive
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)