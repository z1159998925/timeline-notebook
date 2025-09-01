import axios from 'axios';
import environmentManager from './environment.js';

// 创建axios实例，使用环境管理器配置
const instance = axios.create({
  baseURL: environmentManager.getApiBaseURL(),
  timeout: environmentManager.getTimeout(),
  withCredentials: environmentManager.isCredentialsEnabled(),
  headers: {
    'Content-Type': 'application/json',
    'X-Requested-With': 'XMLHttpRequest'
  }
});

// 请求拦截器
instance.interceptors.request.use(
  (config) => {
    // 在开发环境下打印请求信息
    if (environmentManager.isDevelopment()) {
    
    }
    
    // 添加时间戳防止缓存（仅开发环境）
    if (environmentManager.isDevelopment() && config.method === 'get') {
      config.params = {
        ...config.params,
        _t: Date.now()
      };
    }
    
    return config;
  },
  (error) => {
    console.error('❌ 请求错误:', error);
    return Promise.reject(error);
  }
);

// 响应拦截器
instance.interceptors.response.use(
  (response) => {
    // 在开发环境下打印响应信息
    if (environmentManager.isDevelopment()) {
    
    }
    return response;
  },
  (error) => {
    console.error('❌ 响应错误:', error);
    
    // 统一错误处理
    if (error.response) {
      const { status, data } = error.response;
      switch (status) {
        case 401:
          console.warn('🔐 未授权访问');
          // 可以在这里处理登录跳转
          break;
        case 403:
          console.warn('🚫 访问被禁止');
          break;
        case 404:
          console.warn('🔍 资源未找到');
          break;
        case 413:
          console.warn('📁 文件大小超过限制');
          break;
        case 500:
          console.error('💥 服务器内部错误');
          break;
        default:
          console.error(`🔥 HTTP错误 ${status}:`, data?.message || error.message);
      }
    } else if (error.request) {
      console.error('🌐 网络错误: 无法连接到服务器');
    } else {
      console.error('⚙️ 请求配置错误:', error.message);
    }
    
    return Promise.reject(error);
  }
);

// 导出实例
export default instance;

// 导出便捷方法
export const getMediaUrl = (path) => environmentManager.getFullMediaURL(path);
export const getApiBaseUrl = () => environmentManager.getApiBaseURL();
export const getEnvironment = () => environmentManager.getEnvironment();