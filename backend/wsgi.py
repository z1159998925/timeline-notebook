#!/usr/bin/env python3
"""
Timeline Notebook WSGI 入口点
用于生产环境部署
"""

import os
from app import app

if __name__ == "__main__":
    # 生产环境配置
    os.environ.setdefault('FLASK_ENV', 'production')
    
    # 启动应用
    app.run(
        host='0.0.0.0',
        port=int(os.environ.get('PORT', 5000)),
        debug=False
    )