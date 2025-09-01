from flask import Flask, jsonify
from flask_cors import CORS
from config import config
from models import db
from routes import main
import os
from werkzeug.exceptions import RequestEntityTooLarge

# 根据环境变量选择配置
config_name = os.environ.get('FLASK_ENV', 'production')
app_config = config.get(config_name, config['production'])

app = Flask(__name__)
app.config.from_object(app_config)

# 确保数据库目录和文件存在
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
db_path = os.path.join(BASE_DIR, 'data', 'timeline.db')
db_dir = os.path.dirname(db_path)
if not os.path.exists(db_dir):
    os.makedirs(db_dir, exist_ok=True)
    os.chmod(db_dir, 0o777)

# 确保数据库文件存在
if not os.path.exists(db_path):
    open(db_path, 'a').close()
    os.chmod(db_path, 0o666)

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
    os.chmod(upload_folder, 0o777)  # 确保有写入权限

# 创建数据库表
with app.app_context():
    try:
        db.create_all()
        print("✅ 数据库表创建成功")
    except Exception as e:
        print(f"❌ 数据库表创建失败: {e}")

if __name__ == '__main__':
    # 根据环境变量决定启动模式
    is_production = os.environ.get('FLASK_ENV') == 'production'
    debug_mode = not is_production
    
    # Railway会通过PORT环境变量提供端口号
    port = int(os.environ.get('PORT', 5000))
    
    if is_production:
        print(f"启动Timeline Notebook后端服务 (生产模式) - 端口: {port}...")
    else:
        print("启动Timeline Notebook后端服务 (开发模式)...")
        print(f"访问地址: http://localhost:{port}")
        print(f"健康检查: http://localhost:{port}/health")
        print(f"API文档: http://localhost:{port}/api/")
    
    app.run(host='0.0.0.0', port=port, debug=debug_mode)
