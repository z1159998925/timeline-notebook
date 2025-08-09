import axios from 'axios';

// 根据环境动态设置baseURL
const getBaseURL = () => {
  // 开发环境
  if (import.meta.env.MODE === 'development') {
    return 'http://localhost:5000/api';
  }
  
  // 生产环境使用相对路径
  return '/api';
};

const instance = axios.create({
  baseURL: getBaseURL(),
  timeout: 5000
});

export default instance;