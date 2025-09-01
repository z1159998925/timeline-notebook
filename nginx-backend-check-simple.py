#!/usr/bin/env python3
"""
简化版nginx和后端匹配性检查脚本（无表情符号）
验证nginx配置与后端路由的兼容性
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime

def check_nginx_config():
    """检查nginx配置"""
    print("检查nginx配置...")
    
    nginx_conf = Path('nginx.conf')
    if not nginx_conf.exists():
        print("ERROR: nginx.conf文件不存在")
        return False
    
    with open(nginx_conf, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        'upstream backend': 'upstream backend' in content,
        'API代理': 'location /api/' in content,
        '静态文件代理': 'location /static/' in content,
        '健康检查': '/api/health' in content,
        'Gzip压缩': 'gzip on' in content,
        '安全头': 'add_header X-Frame-Options' in content,
        '缓存配置': 'expires' in content,
        '文件上传限制': 'client_max_body_size' in content
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    print(f"Nginx配置检查: {passed}/{len(checks)} 项通过")
    return passed == len(checks)

def check_backend_routes():
    """检查后端路由"""
    print("检查后端路由...")
    
    routes_file = Path('backend/routes.py')
    if not routes_file.exists():
        print("ERROR: backend/routes.py文件不存在")
        return False
    
    with open(routes_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 提取API路由
    api_routes = re.findall(r'@app\.route\([\'"]([^\'"]+)[\'"]', content)
    health_routes = [route for route in api_routes if 'health' in route]
    static_routes = [route for route in api_routes if 'static' in route]
    
    print(f"发现API路由: {len(api_routes)} 个")
    for route in api_routes[:5]:  # 显示前5个
        print(f"  - {route}")
    if len(api_routes) > 5:
        print(f"  ... 还有 {len(api_routes) - 5} 个")
    
    print(f"健康检查路由: {len(health_routes)} 个")
    print(f"静态文件路由: {len(static_routes)} 个")
    
    return True

def check_static_files():
    """检查静态文件配置"""
    print("检查静态文件配置...")
    
    # 检查Flask应用配置
    app_files = ['backend/app.py', 'backend/app_production.py']
    flask_config_ok = False
    
    for app_file in app_files:
        if Path(app_file).exists():
            with open(app_file, 'r', encoding='utf-8') as f:
                content = f.read()
            if 'static_folder' in content or 'static_url_path' in content:
                print(f"PASS: Flask静态文件配置在 {app_file}")
                flask_config_ok = True
                break
    
    if not flask_config_ok:
        print("FAIL: Flask应用缺少静态文件配置")
    
    # 检查上传目录配置
    env_files = ['.env.production', '.env']
    upload_config_ok = False
    
    for env_file in env_files:
        if Path(env_file).exists():
            with open(env_file, 'r', encoding='utf-8') as f:
                content = f.read()
            if 'UPLOAD_FOLDER' in content:
                print(f"PASS: 上传目录配置在 {env_file}")
                upload_config_ok = True
                break
    
    if not upload_config_ok:
        print("FAIL: 缺少UPLOAD_FOLDER环境变量配置")
    
    return flask_config_ok and upload_config_ok

def check_docker_config():
    """检查Docker配置"""
    print("检查Docker配置...")
    
    compose_file = Path('docker-compose.yml')
    if not compose_file.exists():
        print("ERROR: docker-compose.yml文件不存在")
        return False
    
    with open(compose_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        '后端服务': 'backend:' in content,
        '前端服务': 'frontend:' in content,
        '网络配置': 'networks:' in content,
        '健康检查': 'healthcheck:' in content,
        '环境变量文件': 'env_file:' in content,
        '卷挂载': 'volumes:' in content
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    print(f"Docker配置检查: {passed}/{len(checks)} 项通过")
    return passed == len(checks)

def check_cors_config():
    """检查CORS配置"""
    print("检查CORS配置...")
    
    cors_file = Path('backend/cors_config.py')
    if not cors_file.exists():
        print("ERROR: backend/cors_config.py文件不存在")
        return False
    
    with open(cors_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        'CORS管理器类': 'class CORSConfigManager' in content or 'class CORSManager' in content,
        '生产环境配置': 'production' in content.lower(),
        'Flask-CORS配置': 'CORS(' in content or 'flask_cors_config' in content.lower(),
        '域名验证': 'origins' in content
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    return passed == len(checks)

def check_environment_variables():
    """检查环境变量配置"""
    print("检查环境变量配置...")
    
    env_file = Path('.env.production')
    if not env_file.exists():
        print("ERROR: .env.production文件不存在")
        return False
    
    with open(env_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    required_vars = [
        'FLASK_ENV', 'SECRET_KEY', 'DATABASE_URL', 'UPLOAD_FOLDER',
        'DOMAIN', 'CORS_ORIGINS', 'MAX_CONTENT_LENGTH'
    ]
    
    missing_vars = []
    for var in required_vars:
        if var not in content:
            missing_vars.append(var)
    
    if missing_vars:
        print(f"FAIL: 缺少环境变量: {', '.join(missing_vars)}")
        return False
    else:
        print("PASS: 所有必要的环境变量都已配置")
        return True

def generate_compatibility_report():
    """生成兼容性报告"""
    print("生成兼容性报告...")
    
    # 运行各项检查
    nginx_ok = check_nginx_config()
    routes_ok = check_backend_routes()
    static_ok = check_static_files()
    docker_ok = check_docker_config()
    cors_ok = check_cors_config()
    env_ok = check_environment_variables()
    
    # 生成报告
    report = {
        'timestamp': datetime.now().isoformat(),
        'checks': {
            'nginx_config': nginx_ok,
            'backend_routes': routes_ok,
            'static_files': static_ok,
            'docker_config': docker_ok,
            'cors_config': cors_ok,
            'environment_variables': env_ok
        }
    }
    
    # 计算总体得分
    passed_checks = sum(1 for result in report['checks'].values() if result)
    total_checks = len(report['checks'])
    score = (passed_checks / total_checks) * 100
    
    report['score'] = score
    report['status'] = 'PASS' if score == 100 else 'FAIL'
    
    # 保存报告
    with open('nginx-backend-compatibility-report.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    return report

def main():
    """主检查函数"""
    print("开始nginx和后端匹配性检查...")
    print("=" * 60)
    
    report = generate_compatibility_report()
    
    print("=" * 60)
    print(f"检查结果: {report['score']:.1f}% ({sum(1 for r in report['checks'].values() if r)}/{len(report['checks'])} 项通过)")
    
    if report['status'] == 'PASS':
        print("SUCCESS: 所有检查通过！nginx和后端配置完全匹配，可以用于生产环境")
        return 0
    else:
        print("WARNING: 存在配置问题，请修复后重新检查")
        print("失败的检查项:")
        for check, result in report['checks'].items():
            if not result:
                print(f"  - {check}")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())