<template>
  <div class="app-container">
    <!-- 健康检查组件 -->
    <HealthCheck />
    
    <header class="app-header">
      <div class="header-content">
        <h1>时光轴记事本</h1>
        <nav class="main-nav">
          <router-link to="/" class="nav-link">📝 时光轴</router-link>
          <router-link to="/messages" class="nav-link">💬 留言墙</router-link>
          <router-link to="/time-capsules" class="nav-link">⏰ 时间胶囊</router-link>
        </nav>
        <ThemeSwitch />
        <div class="user-section">
          <!-- 未登录状态 -->
          <template v-if="!isLoggedIn">
            <router-link to="/login" class="auth-link login-link">登录</router-link>
            <router-link to="/register" class="auth-link register-link">注册</router-link>
            <router-link to="/admin-login" class="auth-link admin-link">管理员</router-link>
          </template>
          <!-- 已登录状态 -->
          <template v-else>
            <div class="user-info">
              <span class="welcome-text">欢迎，{{ user?.username }}！</span>
              <router-link to="/profile" v-if="user?.role !== 'admin'" class="auth-link profile-link">个人中心</router-link>
              <router-link to="/admin-dashboard" v-if="user?.role === 'admin'" class="auth-link admin-dashboard-link">管理后台</router-link>
              <button @click="logout" class="auth-link logout-btn">退出</button>
            </div>
          </template>
        </div>
      </div>
    </header>
    <main class="app-main">
      <router-view />
    </main>
    <footer class="app-footer">
      <p>© 2023 时光轴记事本</p>
    </footer>
  </div>
</template>

<script>
import { ref, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import api from './axios.js'
import ThemeSwitch from './components/ThemeSwitch.vue'
import HealthCheck from './components/HealthCheck.vue';

export default {
  name: 'App',
  components: {
    ThemeSwitch,
    HealthCheck
  },
  setup() {
    const route = useRoute();
    const isLoggedIn = ref(false);
    const user = ref(null);

    const checkLoginStatus = () => {
      api.get('/login-status')
        .then(response => {
          isLoggedIn.value = response.data.is_logged_in;
          user.value = response.data.user || null;
        })
        .catch(error => {
          console.error('检查登录状态失败:', error);
        });
    };

    onMounted(() => {
      checkLoginStatus();
    });

    // 监听路由变化，重新检查登录状态
    watch(() => route.path, () => {
      checkLoginStatus();
    });

    const logout = () => {
      api.post('/logout')
        .then(() => {
          isLoggedIn.value = false;
          user.value = null;
          // 刷新当前页面或跳转到首页
          window.location.reload();
        })
        .catch(error => {
          console.error('退出登录失败:', error);
        });
    };

    return {
      isLoggedIn,
      user,
      logout
    };
  }
};
</script>

<style>
/* 全局主题变量定义 */
:root {
  --bg-color: #f5f5f5;
  --text-color: #333;
  --header-bg: #42b983;
  --footer-bg: #333;
  --card-bg: white;
  --border-color: #ddd;
  --timeline-line: #e0e0e0;
  --link-color: #3b82f6;
  --button-bg: #42b983;
}

/* 暗黑模式变量覆盖 */
.dark {
  --bg-color: #1a1a1a;
  --text-color: #e0e0e0;
  --header-bg: #2d3748;
  --footer-bg: #1f2937;
  --card-bg: #2d3748;
  --border-color: #4a5568;
  --timeline-line: #4a5568;
  --link-color: #60a5fa;
  --button-bg: #3b82f6;
}
</style>

<style scoped>

.app-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background-color: var(--bg-color);
  color: var(--text-color);
  width: 100%;
  box-sizing: border-box;
}

.app-header {
  background-color: var(--header-bg);
  color: white;
  padding: 15px 20px;
  box-sizing: border-box;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  max-width: 1200px;
  margin: 0 auto;
  gap: 15px;
}

.header-content h1 {
  margin: 0;
}

.main-nav {
  display: flex;
  gap: 20px;
  flex: 1;
  justify-content: center;
}

.nav-link {
  color: white;
  text-decoration: none;
  padding: 8px 16px;
  border-radius: 20px;
  transition: background-color 0.3s;
  font-weight: 500;
}

.nav-link:hover {
  background-color: rgba(255, 255, 255, 0.2);
}

.nav-link.router-link-active {
  background-color: rgba(255, 255, 255, 0.3);
}

.user-section {
  display: flex;
  align-items: center;
  gap: 10px;
  white-space: nowrap;
}

.auth-link {
  color: white;
  text-decoration: none;
  padding: 6px 12px;
  border-radius: 20px;
  transition: all 0.3s ease;
  font-size: 14px;
  font-weight: 500;
  border: none;
  cursor: pointer;
  background: none;
}

.login-link {
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.login-link:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.5);
}

.register-link {
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.register-link:hover {
  background: rgba(255, 255, 255, 0.3);
  border-color: rgba(255, 255, 255, 0.5);
}

.admin-link {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.admin-link:hover {
  background: rgba(255, 255, 255, 0.2);
  border-color: rgba(255, 255, 255, 0.4);
}

.profile-link {
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.profile-link:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.5);
}

.admin-dashboard-link {
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.admin-dashboard-link:hover {
  background: rgba(255, 255, 255, 0.3);
  border-color: rgba(255, 255, 255, 0.5);
}

.welcome-text {
  color: white;
  font-size: 14px;
  margin-right: 5px;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.logout-btn {
  background-color: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.3s;
  font-size: 0.9rem;
}

.logout-btn:hover {
  background-color: rgba(255, 255, 255, 0.3);
}

@media (max-width: 768px) {
  .app-header {
    padding: 12px 15px;
  }
  
  .app-header h1 {
    font-size: 1.3rem;
  }
  
  .header-content {
    flex-wrap: wrap;
    gap: 10px;
  }
  
  .main-nav {
    order: 3;
    width: 100%;
    justify-content: center;
    margin-top: 10px;
  }
  
  .nav-link {
    font-size: 0.9rem;
    padding: 6px 12px;
  }
  
  .user-section {
    gap: 8px;
  }
  
  .auth-link {
    font-size: 12px;
    padding: 4px 8px;
  }
  
  .user-info {
    gap: 8px;
  }
  
  .logout-btn {
    font-size: 0.8rem;
    padding: 4px 8px;
  }
}

.app-main {
  flex: 1;
  padding: 20px;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .app-main {
    padding: 15px 10px;
  }
}

.app-footer {
  background-color: var(--footer-bg);
  color: white;
  text-align: center;
  padding: 10px;
  font-size: 0.9rem;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .app-footer {
    font-size: 0.85rem;
    padding: 8px;
  }
}
</style>
