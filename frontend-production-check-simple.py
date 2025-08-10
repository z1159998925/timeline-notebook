#!/usr/bin/env python3
"""
简化版前端生产环境检查脚本（无表情符号）
验证前端配置的生产环境就绪状态
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime

def check_frontend_build_config():
    """检查前端构建配置"""
    print("检查前端构建配置...")
    
    package_json = Path('frontend/package.json')
    if not package_json.exists():
        print("ERROR: frontend/package.json不存在")
        return False
    
    with open(package_json, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    checks = {
        '构建脚本': 'build' in config.get('scripts', {}),
        'Vue依赖': 'vue' in config.get('dependencies', {}),
        'Axios依赖': 'axios' in config.get('dependencies', {}),
        'Vite构建工具': 'vite' in config.get('devDependencies', {}),
        '现代浏览器支持': 'browserslist' in config or 'targets' in config.get('build', {})
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    print(f"前端构建配置: {passed}/{len(checks)} 项通过")
    return passed == len(checks)

def check_vite_config():
    """检查Vite配置"""
    print("检查Vite配置...")
    
    vite_configs = {
        'vite.config.js': 'frontend/vite.config.js',
        'vite.config.production.js': 'frontend/vite.config.production.js'
    }
    
    all_passed = True
    
    for name, path in vite_configs.items():
        config_file = Path(path)
        if not config_file.exists():
            print(f"ERROR: {name} 不存在")
            all_passed = False
            continue
        
        with open(config_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if name == 'vite.config.js':
            checks = {
                'Vue插件': '@vitejs/plugin-vue' in content,
                '构建配置': 'build:' in content,
                '代码分割': 'rollupOptions' in content,
                '压缩配置': 'minify' in content,
                '开发代理': 'proxy' in content
            }
        else:  # production config
            checks = {
                'Vue插件': '@vitejs/plugin-vue' in content,
                '构建配置': 'build:' in content,
                '代码分割': 'rollupOptions' in content,
                '压缩配置': 'minify' in content,
                '生产优化': 'outDir' in content,
                '源码映射关闭': 'sourcemap: false' in content
            }
        
        passed = 0
        for check, result in checks.items():
            if result:
                passed += 1
        
        status = "PASS" if passed == len(checks) else "FAIL"
        print(f"  {name}: {passed}/{len(checks)} 项通过")
        
        for check, result in checks.items():
            status_mark = "PASS" if result else "FAIL"
            print(f"    {status_mark}: {check}")
        
        if passed != len(checks):
            all_passed = False
    
    return all_passed

def check_environment_config():
    """检查环境配置"""
    print("检查环境配置...")
    
    env_manager = Path('frontend/src/utils/environment.js')
    if not env_manager.exists():
        print("ERROR: 环境配置文件不存在")
        return False
    
    with open(env_manager, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        '环境管理器类': 'class EnvironmentManager' in content,
        '环境检测': 'isDevelopment' in content,
        'API配置': 'getApiBaseURL' in content or 'getApiBaseUrl' in content,
        '媒体文件配置': 'getMediaBaseURL' in content or 'getMediaUrl' in content,
        '开发环境配置': 'development' in content,
        '生产环境配置': 'production' in content,
        'Vite环境变量': 'import.meta.env' in content
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    print(f"环境配置: {passed}/{len(checks)} 项通过")
    return passed == len(checks)

def check_axios_config():
    """检查Axios配置"""
    print("检查Axios配置...")
    
    # 检查多个可能的Axios配置文件路径
    possible_paths = [
        Path('frontend/src/api/axios.js'),
        Path('frontend/src/api/config.js'),
        Path('frontend/src/utils/axios.js'),
        Path('frontend/src/config/api.js')
    ]
    
    api_file = None
    for path in possible_paths:
        if path.exists():
            api_file = path
            break
    
    if not api_file:
        print("ERROR: Axios配置文件不存在")
        return False
    
    with open(api_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        'Axios导入': 'import axios' in content,
        'API实例创建': 'axios.create' in content,
        '基础URL配置': 'baseURL' in content,
        '超时配置': 'timeout' in content,
        '凭证配置': 'withCredentials' in content,
        '请求拦截器': 'interceptors.request' in content,
        '响应拦截器': 'interceptors.response' in content,
        '环境配置': 'import.meta.env' in content or 'process.env' in content,
        'API端点常量': 'API_ENDPOINTS' in content or 'endpoints' in content.lower()
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    print(f"Axios配置: {passed}/{len(checks)} 项通过")
    return passed == len(checks)

def check_api_usage():
    """检查API使用情况"""
    print("检查API使用情况...")
    
    frontend_src = Path('frontend/src')
    if not frontend_src.exists():
        print("ERROR: 前端源码目录不存在")
        return False
    
    # 扫描所有Vue和JS文件
    api_calls = set()
    for file_path in frontend_src.rglob('*.vue'):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 提取API调用
        patterns = [
            r'api\.get\([\'"]([^\'"]+)[\'"]',
            r'api\.post\([\'"]([^\'"]+)[\'"]',
            r'api\.put\([\'"]([^\'"]+)[\'"]',
            r'api\.delete\([\'"]([^\'"]+)[\'"]',
            r'axios\.get\([\'"]([^\'"]+)[\'"]',
            r'axios\.post\([\'"]([^\'"]+)[\'"]'
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, content)
            for match in matches:
                if match.startswith('/api/'):
                    api_calls.add(match)
    
    for file_path in frontend_src.rglob('*.js'):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        for pattern in patterns:
            matches = re.findall(pattern, content)
            for match in matches:
                if match.startswith('/api/'):
                    api_calls.add(match)
    
    print(f"发现API端点: {len(api_calls)} 个")
    
    # 检查必要的API端点
    required_endpoints = [
        '/api/timeline', '/api/login', '/api/register', 
        '/api/health', '/api/login-status'
    ]
    
    missing_endpoints = []
    for endpoint in required_endpoints:
        if not any(endpoint in call for call in api_calls):
            missing_endpoints.append(endpoint)
    
    if missing_endpoints:
        print(f"FAIL: 缺少API端点: {', '.join(missing_endpoints)}")
        return False
    else:
        print("PASS: 所有必要的API端点都已使用")
        return True

def check_frontend_dockerfile():
    """检查前端Dockerfile"""
    print("检查前端Dockerfile...")
    
    dockerfile = Path('Dockerfile.frontend.production')
    if not dockerfile.exists():
        print("ERROR: Dockerfile.frontend.production不存在")
        return False
    
    with open(dockerfile, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        '多阶段构建': 'FROM node:' in content and 'FROM nginx:' in content,
        '生产环境变量': 'NODE_ENV=production' in content,
        'API基础URL': 'VITE_API_BASE_URL' in content,
        'NPM构建': 'npm run build' in content,
        'Nginx配置': 'nginx.conf' in content,
        '健康检查': 'HEALTHCHECK' in content,
        '端口暴露': 'EXPOSE' in content
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"PASS: {check}")
            passed += 1
        else:
            print(f"FAIL: {check}")
    
    print(f"Dockerfile配置: {passed}/{len(checks)} 项通过")
    return passed == len(checks)

def check_frontend_backend_compatibility():
    """检查前端后端兼容性"""
    print("检查前端后端兼容性...")
    
    # 检查后端路由
    backend_routes = Path('backend/routes.py')
    if not backend_routes.exists():
        print("ERROR: 后端路由文件不存在")
        return False
    
    with open(backend_routes, 'r', encoding='utf-8') as f:
        backend_content = f.read()
    
    # 提取后端API路由
    backend_api_routes = set(re.findall(r'@main\.route\([\'"]([^\'"]+)[\'"]', backend_content))
    
    # 提取前端API调用
    frontend_api_calls = set()
    frontend_src = Path('frontend/src')
    
    if frontend_src.exists():
        for file_path in frontend_src.rglob('*.vue'):
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            patterns = [
                r'api\.get\([\'"]([^\'"]+)[\'"]',
                r'api\.post\([\'"]([^\'"]+)[\'"]',
                r'api\.put\([\'"]([^\'"]+)[\'"]',
                r'api\.delete\([\'"]([^\'"]+)[\'"]'
            ]
            
            for pattern in patterns:
                matches = re.findall(pattern, content)
                for match in matches:
                    if match.startswith('/api/'):
                        # 简化路由（移除参数）
                        simplified = re.sub(r'/\d+', '/<int:id>', match)
                        simplified = re.sub(r'/\$\{[^}]+\}', '/<int:id>', simplified)
                        frontend_api_calls.add(simplified)
    
    # 检查匹配性
    unmatched_calls = []
    for call in frontend_api_calls:
        if not any(call in route or route in call for route in backend_api_routes):
            unmatched_calls.append(call)
    
    if unmatched_calls:
        print(f"FAIL: 前端API调用与后端路由不匹配: {', '.join(unmatched_calls)}")
        return False
    else:
        print("PASS: 前端API调用与后端路由完全匹配")
        return True

def generate_frontend_report():
    """生成前端检查报告"""
    print("生成前端检查报告...")
    
    # 运行各项检查
    build_ok = check_frontend_build_config()
    vite_ok = check_vite_config()
    env_ok = check_environment_config()
    axios_ok = check_axios_config()
    api_ok = check_api_usage()
    dockerfile_ok = check_frontend_dockerfile()
    compatibility_ok = check_frontend_backend_compatibility()
    
    # 生成报告
    report = {
        'timestamp': datetime.now().isoformat(),
        'checks': {
            'build_config': build_ok,
            'vite_config': vite_ok,
            'environment_config': env_ok,
            'axios_config': axios_ok,
            'api_usage': api_ok,
            'dockerfile': dockerfile_ok,
            'frontend_backend_compatibility': compatibility_ok
        }
    }
    
    # 计算总体得分
    passed_checks = sum(1 for result in report['checks'].values() if result)
    total_checks = len(report['checks'])
    score = (passed_checks / total_checks) * 100
    
    report['score'] = score
    report['status'] = 'PASS' if score == 100 else 'FAIL'
    
    # 保存报告
    with open('frontend-production-report.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    return report

def main():
    """主检查函数"""
    print("开始前端生产环境检查...")
    print("=" * 60)
    
    report = generate_frontend_report()
    
    print("=" * 60)
    print(f"检查结果: {report['score']:.1f}% ({sum(1 for r in report['checks'].values() if r)}/{len(report['checks'])} 项通过)")
    
    if report['status'] == 'PASS':
        print("SUCCESS: 前端生产环境配置完全正确！")
        print("PASS: 前端与后端配置完全匹配")
        print("PASS: 可以安全部署到生产环境")
        return 0
    else:
        print("WARNING: 前端配置存在问题，请修复后重新检查")
        print("失败的检查项:")
        for check, result in report['checks'].items():
            if not result:
                print(f"  - {check}")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())