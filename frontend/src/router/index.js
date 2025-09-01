import { createRouter, createWebHistory } from 'vue-router'
import HomePage from '../components/HomePage.vue'
import AdminLogin from '../components/AdminLogin.vue'
import AdminDashboard from '../components/AdminDashboard.vue'

import TimeCapsuleList from '../components/TimeCapsuleList.vue'
import MessageWall from '../components/MessageWall.vue'
import MessagePublish from '../components/MessagePublish.vue'
import MessageDetail from '../components/MessageDetail.vue'
import UserRegister from '../components/UserRegister.vue'
import UserLogin from '../components/UserLogin.vue'
import UserProfile from '../components/UserProfile.vue'
import api from '../axios.js';

// 认证状态缓存
let authCache = {
  isLoggedIn: null,
  user: null,
  lastCheck: 0,
  cacheTimeout: 30000 // 30秒缓存
};

// 检查认证状态的函数
const checkAuthStatus = async () => {
  const now = Date.now();
  
  // 如果缓存有效，直接返回缓存结果
  if (authCache.lastCheck && (now - authCache.lastCheck) < authCache.cacheTimeout) {
    return {
      is_logged_in: authCache.isLoggedIn,
      user: authCache.user
    };
  }
  
  try {
    const response = await api.get('/login-status');
    const data = response.data;
    
    // 更新缓存
    authCache.isLoggedIn = data.is_logged_in;
    authCache.user = data.user;
    authCache.lastCheck = now;
    
    return data;
  } catch (error) {
    // API调用失败时，清除缓存
    authCache.isLoggedIn = false;
    authCache.user = null;
    authCache.lastCheck = now;
    throw error;
  }
};

// 清除认证缓存的函数（用于登出时）
export const clearAuthCache = () => {
  authCache.isLoggedIn = null;
  authCache.user = null;
  authCache.lastCheck = 0;
};

// 路由配置
const routes = [
  {
    path: '/',
    name: 'Home',
    component: HomePage
  },
  {
    path: '/admin-login',
    name: 'AdminLogin',
    component: AdminLogin
  },
  {
    path: '/admin-dashboard',
    name: 'AdminDashboard',
    component: AdminDashboard,
    // 路由守卫
    beforeEnter: (to, from, next) => {
      // 检查用户是否已登录且是管理员
      api.get('/login-status')
        .then(response => {
          const data = response.data;
          if (data.is_logged_in && data.user && data.user.role === 'admin') {
            next();
          } else {
            next('/admin-login');
          }
        })
        .catch(() => {
          next('/admin-login');
        });
    }
  },

  {
    path: '/time-capsules',
    name: 'TimeCapsules',
    component: TimeCapsuleList
  },
  {
    path: '/messages',
    name: 'MessageWall',
    component: MessageWall
  },
  {
    path: '/messages/publish',
    name: 'MessagePublish',
    component: MessagePublish,
    meta: { requiresAuth: true }
  },
  {
    path: '/messages/:id',
    name: 'MessageDetail',
    component: MessageDetail
  },
  {
    path: '/register',
    name: 'UserRegister',
    component: UserRegister
  },
  {
    path: '/login',
    name: 'UserLogin',
    component: UserLogin
  },
  {
    path: '/profile',
    name: 'UserProfile',
    component: UserProfile,
    meta: { requiresAuth: true }
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

// 添加全局导航守卫
router.beforeEach(async (to, from, next) => {

  
  // 检查路由是否需要认证
  if (to.meta.requiresAuth) {
    try {
      // 使用缓存的认证检查
      const data = await checkAuthStatus();
      
      if (data.is_logged_in && data.user) {
        // 用户已登录，允许访问

        next();
      } else {
        // 用户未登录，跳转到登录页面

        next('/login');
      }
    } catch (error) {
      // API调用失败，跳转到登录页面
      console.error('检查登录状态失败:', error);
      next('/login');
    }
  } else {
    // 不需要认证的路由，直接通过
    next();
  }
 });
 
 router.afterEach((to, from) => {

});

export default router;