import { createRouter, createWebHistory } from 'vue-router'
import HomePage from '../components/HomePage.vue'
import AdminLogin from '../components/AdminLogin.vue'
import AdminDashboard from '../components/AdminDashboard.vue'
import ImageTestComponent from '../components/ImageTestComponent.vue'
import TimeCapsuleList from '../components/TimeCapsuleList.vue'
import api from '../axios.js';

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
      api.get('/api/login-status')
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
    path: '/test-image',
    name: 'ImageTest',
    component: ImageTestComponent
  },
  {
    path: '/time-capsules',
    name: 'TimeCapsules',
    component: TimeCapsuleList
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

// 添加全局导航守卫
router.beforeEach((to, from, next) => {
  console.log('导航守卫 - 准备跳转:', from.path, '->', to.path);
  next();
});

router.afterEach((to, from) => {
  console.log('导航守卫 - 跳转完成:', from.path, '->', to.path);
});

export default router;