"""
Timeline Notebook 生产环境 WSGI 入口
用于 Gunicorn 等生产服务器
"""

import os
import sys

# 确保生产环境
os.environ['FLASK_ENV'] = 'production'

# 添加当前目录到Python路径
sys.path.insert(0, os.path.dirname(__file__))

from app_production import app

# 生产环境应用实例
application = app

if __name__ == "__main__":
    pass