"""Timeline Notebook 开发环境 WSGI 入口"""

import os
import sys

# 设置开发环境
os.environ['FLASK_ENV'] = 'development'

# 添加当前目录到Python路径
sys.path.insert(0, os.path.dirname(__file__))

from app import app

# 开发环境应用实例
application = app

if __name__ == "__main__":
    # 开发环境可以直接运行
    print("🚀 Timeline Notebook 开发环境 WSGI 启动")
    print("访问地址: http://localhost:5000")
    
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        threaded=True
    )