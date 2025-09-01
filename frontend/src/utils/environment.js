/**
 * Timeline Notebook 前端环境配置管理
 * 提供统一的环境检测、API配置和路径管理
 */

class EnvironmentManager {
  constructor() {
    this.environment = this.detectEnvironment();
    this.config = this.loadConfig();
    this.initialized = true;
    
    // 在开发环境下输出配置信息
    if (this.environment === 'development') {

    }
  }

  /**
   * 检测当前运行环境
   * @returns {string} 'development' | 'production'
   */
  detectEnvironment() {
    // 1. Vite 环境检测 (优先级最高)
    if (typeof import.meta !== 'undefined' && import.meta.env) {
      const mode = import.meta.env.MODE;
      if (mode) {
        return mode === 'development' ? 'development' : 'production';
      }
    }
    
    // 2. Node.js 环境检测
    if (typeof process !== 'undefined' && process.env && process.env.NODE_ENV) {
      return process.env.NODE_ENV === 'development' ? 'development' : 'production';
    }
    
    // 3. 基于域名的环境检测
    const hostname = window.location.hostname;
    const isDevelopment = hostname === 'localhost' || 
                         hostname === '127.0.0.1' || 
                         hostname.startsWith('192.168.') ||
                         hostname.endsWith('.local');
    
    return isDevelopment ? 'development' : 'production';
  }

  /**
   * 加载环境配置
   * @returns {Object} 配置对象
   */
  loadConfig() {
    const baseConfigs = {
      development: {
        apiBaseURL: 'http://localhost:5000/api',
        mediaBaseURL: 'http://localhost:5000/static',
        wsBaseURL: 'ws://localhost:5000',
        timeout: 10000,
        withCredentials: true,
        debug: true,
        logLevel: 'debug'
      },
      production: {
        apiBaseURL: 'https://your-railway-app.railway.app/api',
        mediaBaseURL: 'https://your-railway-app.railway.app/static',
        wsBaseURL: 'wss://your-railway-app.railway.app',
        timeout: 5000,
        withCredentials: true,
        debug: false,
        logLevel: 'error'
      }
    };

    const config = baseConfigs[this.environment] || baseConfigs.production;
    
    // 从环境变量覆盖配置 (Vite)
    if (typeof import.meta !== 'undefined' && import.meta.env) {
      const env = import.meta.env;
      
      if (env.VITE_API_BASE_URL) {
        config.apiBaseURL = env.VITE_API_BASE_URL;
      }
      
      if (env.VITE_MEDIA_BASE_URL) {
        config.mediaBaseURL = env.VITE_MEDIA_BASE_URL;
      }
      
      if (env.VITE_WS_BASE_URL) {
        config.wsBaseURL = env.VITE_WS_BASE_URL;
      }
    }
    
    return config;
  }

  /**
   * 获取API基础URL
   * @returns {string}
   */
  getApiBaseURL() {
    return this.config.apiBaseURL;
  }

  /**
   * 获取媒体文件基础URL
   * @returns {string}
   */
  getMediaBaseURL() {
    return this.config.mediaBaseURL;
  }

  /**
   * 获取WebSocket基础URL
   * @returns {string}
   */
  getWebSocketBaseURL() {
    return this.config.wsBaseURL;
  }

  /**
   * 获取完整的媒体文件URL
   * @param {string} path - 相对路径
   * @returns {string} 完整URL
   */
  getFullMediaURL(path) {
    if (!path) return '';
    
    // 如果已经是完整URL，直接返回
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    // 处理路径
    let cleanPath = path;
    
    // 移除开头的斜杠
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.slice(1);
    }
    
    // 移除 static/ 前缀（如果存在）
    if (cleanPath.startsWith('static/')) {
      cleanPath = cleanPath.slice(7);
    }
    
    // 拼接完整URL
    const baseURL = this.getMediaBaseURL();
    return `${baseURL}/${cleanPath}`;
  }

  /**
   * 获取完整的API URL
   * @param {string} endpoint - API端点
   * @returns {string} 完整API URL
   */
  getFullApiURL(endpoint) {
    if (!endpoint) return this.getApiBaseURL();
    
    // 如果已经是完整URL，直接返回
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }
    
    // 处理端点路径
    let cleanEndpoint = endpoint;
    
    // 移除开头的斜杠
    if (cleanEndpoint.startsWith('/')) {
      cleanEndpoint = cleanEndpoint.slice(1);
    }
    
    // 移除 api/ 前缀（如果存在）
    if (cleanEndpoint.startsWith('api/')) {
      cleanEndpoint = cleanEndpoint.slice(4);
    }
    
    // 拼接完整URL
    const baseURL = this.getApiBaseURL();
    return `${baseURL}/${cleanEndpoint}`;
  }

  /**
   * 检查是否为开发环境
   * @returns {boolean}
   */
  isDevelopment() {
    return this.environment === 'development';
  }

  /**
   * 检查是否为生产环境
   * @returns {boolean}
   */
  isProduction() {
    return this.environment === 'production';
  }

  /**
   * 获取当前环境名称
   * @returns {string}
   */
  getEnvironment() {
    return this.environment;
  }

  /**
   * 获取配置对象
   * @returns {Object}
   */
  getConfig() {
    return { ...this.config };
  }

  /**
   * 获取请求超时时间
   * @returns {number}
   */
  getTimeout() {
    return this.config.timeout;
  }

  /**
   * 检查是否启用调试模式
   * @returns {boolean}
   */
  isDebugEnabled() {
    return this.config.debug;
  }

  /**
   * 获取日志级别
   * @returns {string}
   */
  getLogLevel() {
    return this.config.logLevel;
  }

  /**
   * 检查是否支持凭证
   * @returns {boolean}
   */
  isCredentialsEnabled() {
    return this.config.withCredentials;
  }

  /**
   * 标准化文件路径
   * @param {string} path - 原始路径
   * @returns {string} 标准化后的路径
   */
  normalizePath(path) {
    if (!path) return '';
    
    // 移除多余的斜杠
    return path.replace(/\/+/g, '/').replace(/\/$/, '');
  }

  /**
   * 构建查询字符串
   * @param {Object} params - 查询参数对象
   * @returns {string} 查询字符串
   */
  buildQueryString(params) {
    if (!params || typeof params !== 'object') return '';
    
    const searchParams = new URLSearchParams();
    
    Object.keys(params).forEach(key => {
      const value = params[key];
      if (value !== null && value !== undefined && value !== '') {
        searchParams.append(key, String(value));
      }
    });
    
    const queryString = searchParams.toString();
    return queryString ? `?${queryString}` : '';
  }

  /**
   * 获取环境信息摘要
   * @returns {Object} 环境信息
   */
  getEnvironmentInfo() {
    return {
      environment: this.environment,
      apiBaseURL: this.config.apiBaseURL,
      mediaBaseURL: this.config.mediaBaseURL,
      wsBaseURL: this.config.wsBaseURL,
      debug: this.config.debug,
      timeout: this.config.timeout,
      withCredentials: this.config.withCredentials,
      userAgent: navigator.userAgent,
      hostname: window.location.hostname,
      protocol: window.location.protocol,
      port: window.location.port
    };
  }
}

// 创建全局实例
const environmentManager = new EnvironmentManager();

// 导出实例和类
export default environmentManager;
export { EnvironmentManager };

// 便捷方法导出
export const getEnvironment = () => environmentManager.getEnvironment();
export const isDevelopment = () => environmentManager.isDevelopment();
export const isProduction = () => environmentManager.isProduction();
export const getApiBaseURL = () => environmentManager.getApiBaseURL();
export const getMediaBaseURL = () => environmentManager.getMediaBaseURL();
export const getFullMediaURL = (path) => environmentManager.getFullMediaURL(path);
export const getFullApiURL = (endpoint) => environmentManager.getFullApiURL(endpoint);
export const getConfig = () => environmentManager.getConfig();
export const getEnvironmentInfo = () => environmentManager.getEnvironmentInfo();

// 在开发环境下将实例挂载到 window 对象，便于调试
if (environmentManager.isDevelopment() && typeof window !== 'undefined') {
  window.__TIMELINE_ENV__ = environmentManager;

}