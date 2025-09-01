import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # 基本配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'production-secret-key-must-be-set'
    
    # 数据库配置 - 使用绝对路径
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or f'sqlite:///{os.path.join(BASE_DIR, "data", "timeline.db")}'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_timeout': 20,
        'pool_recycle': -1,
        'pool_pre_ping': True
    }
    
    # 文件上传配置
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER') or os.path.join(BASE_DIR, 'static', 'uploads')
    MAX_CONTENT_LENGTH = int(os.environ.get('MAX_CONTENT_LENGTH', 100 * 1024 * 1024))  # 100MB
    
    # 安全配置
    SESSION_COOKIE_SECURE = os.environ.get('FLASK_ENV') == 'production'
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    
    # CORS配置
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*').split(',')
    
    # 日志配置
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

class DevelopmentConfig(Config):
    DEBUG = True
    SESSION_COOKIE_SECURE = False

class ProductionConfig(Config):
    DEBUG = False
    SESSION_COOKIE_SECURE = True
    
    # 生产环境安全配置
    PREFERRED_URL_SCHEME = 'https'
    
    # 强制HTTPS重定向
    FORCE_HTTPS = True
    
    # 生产环境日志级别
    LOG_LEVEL = 'WARNING'
    
    # 生产环境上传文件夹
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER') or '/app/static/uploads'
    
    # 生产环境数据库配置优化
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_timeout': 30,
        'pool_recycle': 3600,  # 1小时回收连接
        'pool_pre_ping': True,
        'pool_size': 10,
        'max_overflow': 20
    }
    
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
