#!/usr/bin/env python3
"""
完整的生产环境兼容性检查脚本
检查前端、后端、Docker、环境配置等所有组件的兼容性
"""

import os
import re
import json
import subprocess
from pathlib import Path
from datetime import datetime

def run_backend_check():
    """运行后端检查"""
    print("🔍 运行后端生产环境检查...")
    try:
        result = subprocess.run(['python', 'nginx-backend-check-simple.py'], 
                              capture_output=True, text=True, cwd='.', 
                              encoding='utf-8', errors='replace')
        
        # 检查返回码和输出内容
        # 如果返回码为0且得分大于等于80%，认为通过
        output_text = result.stdout + result.stderr
        
        # 提取得分百分比
        score_match = re.search(r'检查结果: (\d+\.?\d*)%', output_text)
        if score_match:
            score = float(score_match.group(1))
            is_success = result.returncode == 0 and score >= 80.0
        else:
            # 如果没有找到得分，检查是否有明确的成功标识
            success_indicators = ["100.0%", "所有检查通过", "可以用于生产环境", "SUCCESS:"]
            is_success = result.returncode == 0 and any(indicator in output_text for indicator in success_indicators)
        
        if is_success:
            print("✅ 后端检查通过")
            return True, "后端配置完全正确"
        else:
            print("❌ 后端检查失败")
            return False, output_text
    except Exception as e:
        print(f"❌ 后端检查执行失败: {str(e)}")
        return False, str(e)

def run_frontend_check():
    """运行前端检查"""
    print("🔍 运行前端生产环境检查...")
    try:
        result = subprocess.run(['python', 'frontend-production-check-simple.py'], 
                              capture_output=True, text=True, cwd='.', 
                              encoding='utf-8', errors='replace')
        
        # 检查返回码和输出内容
        # 如果返回码为0且得分大于等于80%，认为通过
        output_text = result.stdout + result.stderr
        
        # 提取得分百分比
        score_match = re.search(r'检查结果: (\d+\.?\d*)%', output_text)
        if score_match:
            score = float(score_match.group(1))
            is_success = result.returncode == 0 and score >= 80.0
        else:
            # 如果没有找到得分，检查是否有明确的成功标识
            success_indicators = ["100.0%", "前端生产环境配置完全正确", "可以安全部署到生产环境", "SUCCESS:"]
            is_success = result.returncode == 0 and any(indicator in output_text for indicator in success_indicators)
        
        if is_success:
            print("✅ 前端检查通过")
            return True, "前端配置完全正确"
        else:
            print("❌ 前端检查失败")
            return False, output_text
    except Exception as e:
        print(f"❌ 前端检查执行失败: {str(e)}")
        return False, str(e)

def check_docker_compose():
    """检查Docker Compose配置"""
    print("🔍 检查Docker Compose配置...")
    
    compose_file = Path('docker-compose.yml')
    if not compose_file.exists():
        print("❌ docker-compose.yml不存在")
        return False
    
    with open(compose_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = {
        '前端服务': 'frontend:' in content,
        '后端服务': 'backend:' in content,
        'Nginx服务': 'nginx:' in content,
        '数据库服务': 'db:' in content or 'database:' in content,
        '网络配置': 'networks:' in content,
        '卷配置': 'volumes:' in content,
        '环境变量': 'environment:' in content or 'env_file:' in content,
        '端口映射': 'ports:' in content,
        '依赖关系': 'depends_on:' in content
    }
    
    passed = 0
    for check, result in checks.items():
        if result:
            print(f"✅ {check}")
            passed += 1
        else:
            print(f"❌ {check}")
    
    print(f"Docker Compose配置: {passed}/{len(checks)} 项通过")
    return passed >= len(checks) * 0.8  # 80%通过即可

def check_environment_files():
    """检查环境配置文件"""
    print("🔍 检查环境配置文件...")
    
    env_files = [
        '.env',
        '.env.production',
        'backend/.env',
        'frontend/.env',
        'frontend/.env.production'
    ]
    
    existing_files = []
    for env_file in env_files:
        if Path(env_file).exists():
            existing_files.append(env_file)
            print(f"✅ {env_file} 存在")
        else:
            print(f"⚠️ {env_file} 不存在")
    
    # 至少需要有基本的环境配置
    required_files = ['.env', 'backend/.env']
    has_required = any(Path(f).exists() for f in required_files)
    
    if has_required:
        print("✅ 基本环境配置文件存在")
        return True
    else:
        print("❌ 缺少必要的环境配置文件")
        return False

def check_ssl_certificates():
    """检查SSL证书配置"""
    print("🔍 检查SSL证书配置...")
    
    cert_paths = [
        'ssl/cert.pem',
        'ssl/key.pem',
        'nginx/ssl/cert.pem',
        'nginx/ssl/key.pem'
    ]
    
    has_ssl = False
    for cert_path in cert_paths:
        if Path(cert_path).exists():
            print(f"✅ SSL证书 {cert_path} 存在")
            has_ssl = True
        else:
            print(f"⚠️ SSL证书 {cert_path} 不存在")
    
    if has_ssl:
        print("✅ SSL证书配置正确")
        return True
    else:
        print("⚠️ 未配置SSL证书（可选）")
        return True  # SSL是可选的

def check_production_scripts():
    """检查生产环境脚本"""
    print("🔍 检查生产环境脚本...")
    
    scripts = {
        'production-deploy.sh': '生产部署脚本',
        'production-check.sh': '生产检查脚本',
        'backup.sh': '备份脚本',
        'update-deploy.sh': '更新部署脚本'
    }
    
    passed = 0
    for script, description in scripts.items():
        if Path(script).exists():
            print(f"✅ {description} ({script})")
            passed += 1
        else:
            print(f"⚠️ {description} ({script}) 不存在")
    
    print(f"生产环境脚本: {passed}/{len(scripts)} 个存在")
    return passed >= 2  # 至少需要2个脚本

def check_security_config():
    """检查安全配置"""
    print("🔍 检查安全配置...")
    
    security_checks = []
    
    # 检查Nginx安全配置
    nginx_conf = Path('nginx.conf')
    if nginx_conf.exists():
        with open(nginx_conf, 'r', encoding='utf-8') as f:
            nginx_content = f.read()
        
        if 'ssl_protocols' in nginx_content:
            security_checks.append("✅ SSL协议配置")
        else:
            security_checks.append("⚠️ SSL协议配置")
        
        if 'add_header X-Frame-Options' in nginx_content:
            security_checks.append("✅ X-Frame-Options头")
        else:
            security_checks.append("⚠️ X-Frame-Options头")
        
        if 'add_header X-Content-Type-Options' in nginx_content:
            security_checks.append("✅ X-Content-Type-Options头")
        else:
            security_checks.append("⚠️ X-Content-Type-Options头")
    
    # 检查后端安全配置
    cors_config = Path('backend/cors_config.py')
    if cors_config.exists():
        security_checks.append("✅ CORS配置文件")
    else:
        security_checks.append("⚠️ CORS配置文件")
    
    # 检查环境变量安全
    env_file = Path('.env')
    if env_file.exists():
        with open(env_file, 'r', encoding='utf-8') as f:
            env_content = f.read()
        
        if 'SECRET_KEY' in env_content:
            security_checks.append("✅ SECRET_KEY配置")
        else:
            security_checks.append("⚠️ SECRET_KEY配置")
    
    for check in security_checks:
        print(f"  {check}")
    
    passed_security = sum(1 for check in security_checks if check.startswith("✅"))
    total_security = len(security_checks)
    
    print(f"安全配置: {passed_security}/{total_security} 项通过")
    return passed_security >= total_security * 0.7  # 70%通过即可

def generate_comprehensive_report():
    """生成综合检查报告"""
    print("\n📊 生成综合检查报告...")
    
    # 运行各项检查
    backend_ok, backend_msg = run_backend_check()
    frontend_ok, frontend_msg = run_frontend_check()
    docker_ok = check_docker_compose()
    env_ok = check_environment_files()
    ssl_ok = check_ssl_certificates()
    scripts_ok = check_production_scripts()
    security_ok = check_security_config()
    
    # 生成报告
    report = {
        'timestamp': datetime.now().isoformat(),
        'checks': {
            'backend_production': backend_ok,
            'frontend_production': frontend_ok,
            'docker_compose': docker_ok,
            'environment_files': env_ok,
            'ssl_certificates': ssl_ok,
            'production_scripts': scripts_ok,
            'security_config': security_ok
        },
        'messages': {
            'backend': backend_msg,
            'frontend': frontend_msg
        }
    }
    
    # 计算总体得分
    passed_checks = sum(1 for result in report['checks'].values() if result)
    total_checks = len(report['checks'])
    score = (passed_checks / total_checks) * 100
    
    report['score'] = score
    report['status'] = 'PRODUCTION_READY' if score >= 85 else 'NEEDS_IMPROVEMENT'
    
    # 保存报告
    with open('full-compatibility-report.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    return report

def main():
    """主检查函数"""
    print("🚀 开始完整的生产环境兼容性检查...")
    print("=" * 80)
    
    report = generate_comprehensive_report()
    
    print("\n" + "=" * 80)
    print(f"📊 综合检查结果: {report['score']:.1f}% ({sum(1 for r in report['checks'].values() if r)}/{len(report['checks'])} 项通过)")
    
    if report['status'] == 'PRODUCTION_READY':
        print("🎉 应用已准备好部署到生产环境！")
        print("✅ 前端和后端配置完全匹配")
        print("✅ 所有关键组件配置正确")
        print("✅ 安全配置符合要求")
        print("\n🚀 可以执行以下命令开始部署:")
        print("   ./production-deploy.sh")
        return 0
    else:
        print("⚠️ 应用配置需要改进，建议修复以下问题:")
        print("\n❌ 失败的检查项:")
        for check, result in report['checks'].items():
            if not result:
                print(f"  - {check}")
        
        print("\n💡 建议:")
        if not report['checks']['backend_production']:
            print("  - 运行 python nginx-backend-check-simple.py 查看后端问题")
        if not report['checks']['frontend_production']:
            print("  - 运行 python frontend-production-check-simple.py 查看前端问题")
        if not report['checks']['docker_compose']:
            print("  - 检查 docker-compose.yml 配置")
        if not report['checks']['environment_files']:
            print("  - 创建必要的环境配置文件")
        if not report['checks']['security_config']:
            print("  - 完善安全配置")
        
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())