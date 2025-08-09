<template>
  <div class="app-container">
    <header class="app-header">
      <div class="header-content">
        <h1>时光轴记事本</h1>
        <nav class="main-nav">
          <router-link to="/" class="nav-link">📝 时光轴</router-link>
          <router-link to="/time-capsules" class="nav-link">⏰ 时间胶囊</router-link>
        </nav>
        <ThemeSwitch />
        <div class="admin-link">
          <router-link to="/admin-login" v-if="!isLoggedIn">管理员登录</router-link>
          <router-link to="/admin-dashboard" v-if="isLoggedIn && user && user.role === 'admin'">{{ user.username }} (进入后台)</router-link>
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
import api from './axios.js'
import ThemeSwitch from './components/ThemeSwitch.vue'

export default {
  name: 'App',
  components: {
    ThemeSwitch
  },
  setup() {
    const isLoggedIn = ref(false);
    const user = ref(null);

    const checkLoginStatus = () => {
      api.get('/api/login-status')
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
    watch(() => window.location.pathname, () => {
      checkLoginStatus();
    });

    return {
      isLoggedIn,
      user
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

.admin-link {
  display: flex;
  align-items: center;
  white-space: nowrap;
}

.admin-link a {
      color: white;
      text-decoration: none;
      padding: 6px 12px;
      border-radius: 4px;
      background-color: rgba(255, 255, 255, 0.2);
      transition: background-color 0.3s;
    }

    .admin-link a:hover {
      background-color: rgba(255, 255, 255, 0.3);
    }

.admin-link span {
  padding: 6px 12px;
  border-radius: 4px;
  background-color: rgba(255, 255, 255, 0.1);
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
  
  .admin-link {
    font-size: 0.9rem;
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
