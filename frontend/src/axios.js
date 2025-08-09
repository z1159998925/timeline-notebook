import axios from 'axios';

// 获取基础URL的函数
function getBaseURL() {
  // 在Vite环境中使用import.meta.env.MODE
  if (typeof import.meta !== 'undefined' && import.meta.env) {
    return import.meta.env.MODE === 'development' ? 'http://localhost:5000' : '';
  }
  // 兼容其他环境
  return process.env.NODE_ENV === 'production' ? '' : 'http://localhost:5000';
}

// 创建axios实例
const api = axios.create({
  baseURL: getBaseURL(),
  timeout: 30000, // 增加到30秒，支持文件上传
  withCredentials: true // 允许携带cookie
});

// 请求拦截器
api.interceptors.request.use(
  config => {
    console.log('请求配置:', config);
    return config;
  },
  error => {
    console.error('请求错误:', error);
    return Promise.reject(error);
  }
);

// 响应拦截器
api.interceptors.response.use(
  response => {
    console.log('响应数据:', response);
    return response;
  },
  error => {
    console.error('响应错误:', error);
    return Promise.reject(error);
  }
);

export default api;