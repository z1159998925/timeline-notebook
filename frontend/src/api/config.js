/**
 * Axios API 配置文件
 * 统一管理前端API调用配置
 */

import axios from 'axios'

// 环境配置
const isDevelopment = import.meta.env.MODE === 'development'
const isProduction = import.meta.env.MODE === 'production'

// API基础URL配置
const getBaseURL = () => {
  if (isDevelopment) {
    // 开发环境：使用Vite代理
    return '/api'
  } else if (isProduction) {
    // 生产环境：使用相对路径（通过nginx代理）
    return '/api'
  }
  return '/api'
}

// 创建axios实例
const apiClient = axios.create({
  baseURL: getBaseURL(),
  timeout: 30000, // 30秒超时
  withCredentials: true, // 支持跨域cookie
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
})

// 请求拦截器
apiClient.interceptors.request.use(
  (config) => {
    // 开发环境日志
    if (isDevelopment) {
  
    }
    
    // 添加时间戳防止缓存
    if (config.method === 'get') {
      config.params = {
        ...config.params,
        _t: Date.now()
      }
    }
    
    return config
  },
  (error) => {
    console.error('❌ Request Error:', error)
    return Promise.reject(error)
  }
)

// 响应拦截器
apiClient.interceptors.response.use(
  (response) => {
    // 开发环境日志
    if (isDevelopment) {
  
    }
    return response
  },
  (error) => {
    console.error('❌ Response Error:', error)
    
    // 统一错误处理
    if (error.response) {
      const { status, data } = error.response
      
      switch (status) {
        case 401:
          console.warn('🔐 未授权访问，请重新登录')
          // 可以在这里触发登录页面跳转
          break
        case 403:
          console.warn('🚫 权限不足')
          break
        case 404:
          console.warn('🔍 请求的资源不存在')
          break
        case 500:
          console.error('💥 服务器内部错误')
          break
        default:
          console.error(`🔥 HTTP错误 ${status}:`, data?.message || error.message)
      }
    } else if (error.request) {
      console.error('🌐 网络错误，请检查网络连接')
    } else {
      console.error('⚠️ 请求配置错误:', error.message)
    }
    
    return Promise.reject(error)
  }
)

// 文件上传专用配置
export const createUploadClient = () => {
  return axios.create({
    baseURL: getBaseURL(),
    timeout: 120000, // 2分钟超时（文件上传）
    withCredentials: true,
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
}

// API端点常量
export const API_ENDPOINTS = {
  // 健康检查
  HEALTH: '/health',
  
  // 用户认证
  LOGIN: '/login',
  LOGOUT: '/logout',
  REGISTER: '/register',
  LOGIN_STATUS: '/login-status',
  
  // 时光轴
  TIMELINE: '/timeline',
  TIMELINE_LIKE: (id) => `/timeline/${id}/like`,
  TIMELINE_COMMENTS: (id) => `/timeline/${id}/comments`,
  
  // 时间胶囊
  TIME_CAPSULES: '/time-capsules',
  
  // 管理员
  ADMIN_USERS_COUNT: '/admin/users/count',
  ADMIN_BACKUPS: '/admin/backups',
  ADMIN_BACKUP: '/admin/backup',
  ADMIN_RESTORE: '/admin/restore',
  
  // 测试
  TEST_SESSION: '/test-session'
}

// 导出配置
export default apiClient
export { getBaseURL, isDevelopment, isProduction }