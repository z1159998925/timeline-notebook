import axios from 'axios';
import environmentManager from './utils/environment.js';

// 创建axios实例，使用环境管理器配置
const api = axios.create({
  baseURL: environmentManager.getApiBaseURL(),
  timeout: environmentManager.getTimeout(),
  withCredentials: environmentManager.isCredentialsEnabled()
});

// 请求拦截器
api.interceptors.request.use(
  config => {

    return config;
  },
  error => {
    if (environmentManager.isDebugEnabled()) {
      console.error('❌ 请求错误:', error);
    }
    return Promise.reject(error);
  }
);

// 响应拦截器
api.interceptors.response.use(
  response => {

    return response;
  },
  error => {
    if (environmentManager.isDebugEnabled()) {
      console.error('❌ 响应错误:', error);
    }
    return Promise.reject(error);
  }
);

export default api;

// 便捷导出函数
export const getApiBaseUrl = () => environmentManager.getApiBaseURL();
export const getMediaUrl = (path) => environmentManager.getFullMediaURL(path);
export const getEnvironment = () => environmentManager.getEnvironment();