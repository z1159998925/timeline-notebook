"""Timeline Notebook 开发环境后端应用"""

from flask import Flask, jsonify, send_file
from flask_cors import CORS
from config import config
from models import db
from routes import main
import os
import logging
from werkzeug.exceptions import RequestEntityTooLarge

def create_app():
    """创建开发环境Flask应用"""
    
    # 开发环境配置
    os.environ['FLASK_ENV'] = 'development'
    
    # 配置静态文件路径
    app = Flask(__name__, 
                static_folder='static',
                static_url_path='/static')
    
    # 开发环境配置
    app.config.from_object(config['development'])
    
    # 开发环境启用调试模式
    app.debug = True
    app.testing = False
    
    # 数据库初始化
    db_path = 'data/timeline.db'
    db_dir = os.path.dirname(db_path)
    
    if not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)
    
    if not os.path.exists(db_path):
        open(db_path, 'a').close()
    
    db.init_app(app)
    
    # 开发环境CORS配置 - 允许所有来源
    CORS(app, 
         origins=['http://localhost:5173', 'http://127.0.0.1:5173', 'http://localhost:3000'],
         supports_credentials=True,
         allow_headers=['Content-Type', 'Authorization'],
         methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])
    
    # 开发环境日志配置
    if app.debug:
        logging.basicConfig(level=logging.DEBUG)
        app.logger.setLevel(logging.DEBUG)
        app.logger.info('Timeline Notebook 开发环境启动')
    
    # 确保上传目录存在
    upload_folder = app.config.get('UPLOAD_FOLDER', 'static/uploads')
    
    if not os.path.isabs(upload_folder):
        upload_folder = os.path.join(app.root_path, upload_folder)
    
    if not os.path.exists(upload_folder):
        os.makedirs(upload_folder, exist_ok=True)
        app.logger.info(f"创建上传目录: {upload_folder}")
    
    app.logger.info(f"上传目录: {upload_folder}")
    
    # 错误处理
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
    
    # 健康检查端点
    @app.route('/health')
    def health_check():
        """开发环境健康检查"""
        try:
            from sqlalchemy import text
            with app.app_context():
                db.session.execute(text('SELECT 1'))
                db.session.commit()
            
            return jsonify({
                'status': 'healthy',
                'environment': 'development',
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
    
    # 应用信息端点
    @app.route('/info')
    def app_info():
        """应用信息"""
        return jsonify({
            'name': 'Timeline Notebook',
            'version': '1.0.0',
            'environment': 'development',
            'debug': True,
            'database': 'connected' if db else 'disconnected'
        })
    
    # 静态文件服务
    @app.route('/static/uploads/<path:filename>')
    def uploaded_file(filename):
        """提供上传文件的访问"""
        try:
            upload_folder = app.config.get('UPLOAD_FOLDER', 'static/uploads')
            if not os.path.isabs(upload_folder):
                upload_folder = os.path.join(app.root_path, upload_folder)
            
            file_path = os.path.join(upload_folder, filename)
            
            if not os.path.exists(file_path):
                return jsonify({'error': '文件不存在'}), 404
            
            return send_file(file_path)
            
        except Exception as e:
            app.logger.error(f"静态文件访问错误: {e}")
            return jsonify({'error': '文件访问失败'}), 500
    
    # 注册蓝图
    app.register_blueprint(main)
    
    # 创建数据库表
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
    # 开发环境直接运行
    print("🚀 Timeline Notebook 开发服务器启动")
    print("访问地址: http://localhost:5000")
    print("健康检查: http://localhost:5000/health")
    
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        threaded=True
    )