from flask import Flask, jsonify
from flask_cors import CORS
from config import config
from models import db
from routes import main
import os
from werkzeug.exceptions import RequestEntityTooLarge

# 根据环境变量选择配置
config_name = os.environ.get('FLASK_ENV', 'development')
app_config = config.get(config_name, config['default'])

app = Flask(__name__)
app.config.from_object(app_config)

# 初始化数据库
db.init_app(app)

# 动态CORS配置
cors_origins = app.config.get('CORS_ORIGINS', ['*'])
if cors_origins == ['*']:
    # 开发环境
    cors_origins = ["http://localhost:5173", "http://localhost:5174", "http://localhost:3000"]
else:
    # 生产环境，添加域名
    domain = os.environ.get('DOMAIN', 'xn--cpq55e94lgvdcukyqt.com')
    cors_origins.extend([
        f"https://{domain}",
        f"http://{domain}",
        "http://localhost:5173",  # 保留开发环境
        "http://localhost:5174"
    ])

# 允许跨域，配置支持凭证
CORS(app, 
     supports_credentials=True, 
     resources={r"/*": {
         "origins": cors_origins,
         "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
         "allow_headers": ["Content-Type", "Authorization"]
     }})

# 文件大小超限错误处理
@app.errorhandler(RequestEntityTooLarge)
def handle_file_too_large(e):
    return jsonify({'message': '文件大小超过限制（最大16MB）'}), 413

# 注册蓝图
app.register_blueprint(main)

# 创建上传文件夹
upload_folder = app.config.get('UPLOAD_FOLDER')
if upload_folder and not os.path.exists(upload_folder):
    os.makedirs(upload_folder, exist_ok=True)

# 创建数据库表
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    # 根据环境设置debug模式
    debug_mode = config_name == 'development'
    port = int(os.environ.get('PORT', 5000))
    
    app.run(
        debug=debug_mode, 
        use_reloader=debug_mode, 
        host='0.0.0.0', 
        port=port
    )