"""
Timeline Notebook 后端跨域配置管理
提供精确的CORS策略配置和环境适配
"""

import os
import re
from typing import List, Dict, Any
from urllib.parse import urlparse

class CORSConfigManager:
    """CORS配置管理器"""
    
    def __init__(self, environment: str = None):
        self.environment = environment or os.environ.get('FLASK_ENV', 'production')
        self.domain = os.environ.get('DOMAIN', '')
        self.config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """加载CORS配置"""
        if self.environment == 'development':
            return self._get_development_config()
        else:
            return self._get_production_config()
    
    def _get_development_config(self) -> Dict[str, Any]:
        """开发环境CORS配置"""
        return {
            'origins': [
                'http://localhost:5173',
                'http://localhost:5174',
                'http://localhost:3000',
                'http://127.0.0.1:5173',
                'http://127.0.0.1:5174',
                'http://127.0.0.1:3000',
                # 支持不同端口的开发服务器
                'http://localhost:8080',
                'http://localhost:8081',
                'http://localhost:9000'
            ],
            'methods': ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
            'allow_headers': [
                'Content-Type',
                'Authorization',
                'X-Requested-With',
                'Accept',
                'Origin',
                'Cache-Control',
                'X-File-Name'
            ],
            'expose_headers': [
                'Content-Range',
                'X-Content-Range',
                'X-Total-Count'
            ],
            'supports_credentials': True,
            'max_age': 86400  # 24小时
        }
    
    def _get_production_config(self) -> Dict[str, Any]:
        """生产环境CORS配置"""
        origins = []
        
        # 添加主域名
        if self.domain:
            origins.extend([
                f'https://{self.domain}',
                f'http://{self.domain}',
                f'https://www.{self.domain}',
                f'http://www.{self.domain}'
            ])
        
        # 从环境变量获取额外允许的域名
        extra_origins = os.environ.get('CORS_ORIGINS', '').split(',')
        for origin in extra_origins:
            origin = origin.strip()
            if origin and self._is_valid_origin(origin):
                origins.append(origin)
        
        # 如果没有配置任何域名，使用当前请求的origin（谨慎使用）
        if not origins:
            origins = ['*']  # 临时解决方案，生产环境应避免
        
        return {
            'origins': origins,
            'methods': ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
            'allow_headers': [
                'Content-Type',
                'Authorization',
                'X-Requested-With',
                'Accept',
                'Origin'
            ],
            'expose_headers': [
                'Content-Range',
                'X-Content-Range'
            ],
            'supports_credentials': True,
            'max_age': 3600  # 1小时
        }
    
    def _is_valid_origin(self, origin: str) -> bool:
        """验证origin是否有效"""
        try:
            parsed = urlparse(origin)
            return (
                parsed.scheme in ['http', 'https'] and
                parsed.netloc and
                not parsed.netloc.startswith('localhost') and
                not parsed.netloc.startswith('127.0.0.1') and
                not re.match(r'^192\.168\.\d+\.\d+', parsed.netloc)
            )
        except Exception:
            return False
    
    def get_cors_config(self) -> Dict[str, Any]:
        """获取CORS配置"""
        return self.config.copy()
    
    def get_origins(self) -> List[str]:
        """获取允许的源列表"""
        return self.config['origins'].copy()
    
    def is_origin_allowed(self, origin: str) -> bool:
        """检查origin是否被允许"""
        if not origin:
            return False
        
        allowed_origins = self.get_origins()
        
        # 通配符检查
        if '*' in allowed_origins:
            return True
        
        # 精确匹配
        if origin in allowed_origins:
            return True
        
        # 子域名匹配（仅生产环境）
        if self.environment == 'production' and self.domain:
            parsed = urlparse(origin)
            if parsed.netloc.endswith(f'.{self.domain}'):
                return True
        
        return False
    
    def get_flask_cors_config(self) -> Dict[str, Any]:
        """获取Flask-CORS配置"""
        config = self.get_cors_config()
        
        return {
            'origins': config['origins'],
            'methods': config['methods'],
            'allow_headers': config['allow_headers'],
            'expose_headers': config['expose_headers'],
            'supports_credentials': config['supports_credentials'],
            'max_age': config['max_age']
        }
    
    def get_resource_specific_config(self) -> Dict[str, Dict[str, Any]]:
        """获取资源特定的CORS配置"""
        base_config = self.get_flask_cors_config()
        
        return {
            # API端点配置
            r'/api/*': {
                **base_config,
                'methods': ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH']
            },
            
            # 静态文件配置
            r'/static/*': {
                'origins': base_config['origins'],
                'methods': ['GET', 'HEAD', 'OPTIONS'],
                'allow_headers': ['Content-Type', 'Cache-Control'],
                'expose_headers': ['Content-Length', 'Content-Type'],
                'supports_credentials': False,
                'max_age': 86400  # 静态文件缓存更长时间
            },
            
            # 上传端点配置
            r'/upload/*': {
                **base_config,
                'methods': ['POST', 'OPTIONS'],
                'allow_headers': base_config['allow_headers'] + [
                    'X-File-Name',
                    'X-File-Size',
                    'Content-Range'
                ]
            },
            
            # 健康检查端点（无需认证）
            r'/health': {
                'origins': '*',
                'methods': ['GET', 'HEAD'],
                'allow_headers': ['Content-Type'],
                'supports_credentials': False,
                'max_age': 300  # 5分钟
            }
        }
    
    def log_config(self):
        """记录当前CORS配置"""


class DynamicCORSHandler:
    """动态CORS处理器"""
    
    def __init__(self, config_manager: CORSConfigManager):
        self.config_manager = config_manager
    
    def handle_preflight(self, request):
        """处理预检请求"""
        origin = request.headers.get('Origin')
        
        if not self.config_manager.is_origin_allowed(origin):
            return None, 403
        
        headers = {
            'Access-Control-Allow-Origin': origin,
            'Access-Control-Allow-Methods': ', '.join(self.config_manager.config['methods']),
            'Access-Control-Allow-Headers': ', '.join(self.config_manager.config['allow_headers']),
            'Access-Control-Max-Age': str(self.config_manager.config['max_age'])
        }
        
        if self.config_manager.config['supports_credentials']:
            headers['Access-Control-Allow-Credentials'] = 'true'
        
        return headers, 200
    
    def add_cors_headers(self, response, request):
        """为响应添加CORS头"""
        origin = request.headers.get('Origin')
        
        if self.config_manager.is_origin_allowed(origin):
            response.headers['Access-Control-Allow-Origin'] = origin
            
            if self.config_manager.config['supports_credentials']:
                response.headers['Access-Control-Allow-Credentials'] = 'true'
            
            if self.config_manager.config['expose_headers']:
                response.headers['Access-Control-Expose-Headers'] = ', '.join(
                    self.config_manager.config['expose_headers']
                )
        
        return response

def create_cors_config(environment: str = None) -> CORSConfigManager:
    """创建CORS配置管理器"""
    return CORSConfigManager(environment)

def setup_flask_cors(app, config_manager: CORSConfigManager = None):
    """为Flask应用设置CORS"""
    from flask_cors import CORS
    
    if config_manager is None:
        config_manager = create_cors_config()
    
    # 获取资源特定配置
    resources = config_manager.get_resource_specific_config()
    
    # 应用CORS配置
    CORS(app, resources=resources)
    
    # 记录配置
    config_manager.log_config()
    
    return config_manager

# 便捷函数
def get_cors_origins(environment: str = None) -> List[str]:
    """获取CORS允许的源列表"""
    config_manager = create_cors_config(environment)
    return config_manager.get_origins()

def is_development_environment() -> bool:
    """检查是否为开发环境"""
    return os.environ.get('FLASK_ENV', 'production') == 'development'

def validate_cors_config() -> bool:
    """验证CORS配置"""
    try:
        config_manager = create_cors_config()
        origins = config_manager.get_origins()
        
        if not origins:

            return False
        
        if '*' in origins and len(origins) > 1:

        
        if is_development_environment():

        else:
            if '*' in origins:

                return False
            
        
        return True
        
    except Exception as e:

        return False

if __name__ == '__main__':
    # 测试配置

    
    # 开发环境测试

    dev_config = create_cors_config('development')
    dev_config.log_config()
    
    # 生产环境测试

    os.environ['DOMAIN'] = 'example.com'
    prod_config = create_cors_config('production')
    prod_config.log_config()
    
    # 验证配置

    validate_cors_config()