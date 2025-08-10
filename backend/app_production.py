"""
Timeline Notebook 生产环境后端应用
严格按照生产环境最佳实践配置
"""

from flask import Flask, jsonify
from flask_cors import CORS
from config import config
from models import db
from routes import main
import os
import logging
from logging.handlers import RotatingFileHandler
from werkzeug.exceptions import RequestEntityTooLarge
import sys

def create_app():
    """创建生产环境Flask应用"""
    
    # 强制生产环境
    os.environ['FLASK_ENV'] = 'production'
    
    # 配置静态文件路径
    app = Flask(__name__, 
                static_folder='static',
                static_url_path='/static')
    
    # 🛡️ 安全配置 - 强制生产环境
    app.config.from_object(config['production'])
    
    # 验证必要的生产环境配置
    required_env_vars = ['SECRET_KEY', 'DATABASE_URL']
    missing_vars = []
    
    for var in required_env_vars:
        value = os.environ.get(var)
        if not value or value in ['your-production-secret-key-here-change-this', 'production-secret-key-must-be-set']:
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ 缺少必要的生产环境变量: {', '.join(missing_vars)}")
        print("请设置正确的环境变量后重新启动")
        sys.exit(1)
    
    # 🔒 强制关闭调试模式
    app.debug = False
    app.testing = False
    
    # 🗄️ 数据库初始化
    db_path = 'data/timeline.db'
    db_dir = os.path.dirname(db_path)
    
    if not os.path.exists(db_dir):
        os.makedirs(db_dir, mode=0o755, exist_ok=True)
    
    if not os.path.exists(db_path):
        open(db_path, 'a').close()
        os.chmod(db_path, 0o644)  # 生产环境使用更严格的权限
    
    db.init_app(app)
    
    # 🔒 使用统一的CORS配置管理器
    try:
        from cors_config import CORSConfigManager
        cors_manager = CORSConfigManager(is_production=True)
        
        # 应用CORS配置
        CORS(app, **cors_manager.get_flask_cors_config())
        
        # 验证CORS配置
        domain = os.environ.get('DOMAIN')
        if not domain:
            app.logger.warning("⚠️ 未设置DOMAIN环境变量，CORS配置可能不完整")
        else:
            app.logger.info(f"✅ CORS配置已应用，主域名: {domain}")
            
    except ImportError as e:
        app.logger.error(f"❌ 无法导入CORS配置管理器: {e}")
        # 回退到基础CORS配置
        domain = os.environ.get('DOMAIN')
        if domain:
            allowed_origins = [f"https://{domain}"]
            CORS(app, origins=allowed_origins, supports_credentials=True)
        else:
            app.logger.error("❌ 未设置DOMAIN环境变量，CORS配置失败")
            sys.exit(1)
    
    # 📝 生产环境日志配置
    if not app.debug:
        # 创建日志目录
        log_dir = 'logs'
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, mode=0o755, exist_ok=True)
        
        # 配置文件日志
        file_handler = RotatingFileHandler(
            'logs/timeline.log', 
            maxBytes=10240000,  # 10MB
            backupCount=10
        )
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        ))
        file_handler.setLevel(logging.WARNING)
        app.logger.addHandler(file_handler)
        
        # 设置日志级别
        app.logger.setLevel(logging.WARNING)
        app.logger.info('Timeline Notebook 生产环境启动')
    
    # 📁 确保上传目录存在 - 生产环境路径处理
    upload_folder = app.config.get('UPLOAD_FOLDER', '/app/static/uploads')
    
    # 处理相对路径和绝对路径
    if not os.path.isabs(upload_folder):
        upload_folder = os.path.join(app.root_path, upload_folder)
    
    if not os.path.exists(upload_folder):
        try:
            os.makedirs(upload_folder, mode=0o755, exist_ok=True)
            app.logger.info(f"✅ 创建上传目录: {upload_folder}")
        except PermissionError as e:
            app.logger.error(f"❌ 无法创建上传目录 {upload_folder}: {e}")
            sys.exit(1)
    
    # 验证目录权限
    if not os.access(upload_folder, os.W_OK):
        app.logger.error(f"❌ 上传目录无写入权限: {upload_folder}")
        sys.exit(1)
    
    app.logger.info(f"✅ 上传目录已就绪: {upload_folder}")
    
    # ⚠️ 错误处理
    @app.errorhandler(RequestEntityTooLarge)
    def handle_file_too_large(e):
        app.logger.warning(f"文件上传超过大小限制: {e}")
        return jsonify({'error': '文件大小超过限制'}), 413
    
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({'error': '资源未找到'}), 404
    
    @app.errorhandler(500)
    def internal_error(e):
        app.logger.error(f"内部服务器错误: {e}")
        return jsonify({'error': '内部服务器错误'}), 500
    
    # 🏥 健康检查端点
    @app.route('/health')
    def health_check():
        """生产环境健康检查"""
        try:
            # 检查数据库连接 (SQLAlchemy 2.0+ 兼容)
            from sqlalchemy import text
            with app.app_context():
                db.session.execute(text('SELECT 1'))
                db.session.commit()
            
            return jsonify({
                'status': 'healthy',
                'environment': 'production',
                'debug': app.debug,
                'database': 'connected'
            }), 200
        except Exception as e:
            app.logger.error(f"健康检查失败: {e}")
            return jsonify({
                'status': 'unhealthy',
                'error': str(e),
                'database': 'disconnected'
            }), 503
    
    # 📊 生产环境信息端点（仅限内部）
    @app.route('/info')
    def app_info():
        """应用信息（生产环境限制访问）"""
        return jsonify({
            'name': 'Timeline Notebook',
            'version': '1.0.0',
            'environment': 'production',
            'debug': False,
            'database': 'connected' if db else 'disconnected'
        })
    
    # 📁 静态文件服务（用于nginx代理）
    @app.route('/static/uploads/<path:filename>')
    def uploaded_file(filename):
        """提供上传文件的访问"""
        try:
            upload_folder = app.config.get('UPLOAD_FOLDER', '/app/static/uploads')
            if not os.path.isabs(upload_folder):
                upload_folder = os.path.join(app.root_path, upload_folder)
            
            file_path = os.path.join(upload_folder, filename)
            
            # 安全检查：防止路径遍历攻击
            if not os.path.commonpath([upload_folder, file_path]) == upload_folder:
                app.logger.warning(f"路径遍历攻击尝试: {filename}")
                return jsonify({'error': '非法文件路径'}), 403
            
            if not os.path.exists(file_path):
                return jsonify({'error': '文件不存在'}), 404
            
            return send_file(file_path)
            
        except Exception as e:
            app.logger.error(f"静态文件访问错误: {e}")
            return jsonify({'error': '文件访问失败'}), 500
    
    # 注册蓝图
    app.register_blueprint(main)
    
    # 🗄️ 创建数据库表
    with app.app_context():
        try:
            db.create_all()
            app.logger.info("数据库表创建/验证成功")
        except Exception as e:
            app.logger.error(f"数据库初始化失败: {e}")
            raise
    
    return app

# 创建应用实例
app = create_app()

if __name__ == '__main__':
    # 生产环境不应该直接运行此文件
    # 应该使用 Gunicorn 或其他 WSGI 服务器
    print("⚠️  警告: 生产环境应使用 Gunicorn 启动")
    print("正确启动命令: gunicorn -w 4 app_production:app")
    
    # 如果必须直接运行，使用生产配置
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,  # 强制关闭调试
        threaded=True
    )