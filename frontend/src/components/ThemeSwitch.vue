<template>
  <button
    class="theme-switch"
    @click="toggleTheme"
    aria-label="切换主题"
    :title="isDarkMode ? '切换到浅色模式' : '切换到深色模式'"
  >
    <i :class="isDarkMode ? 'fas fa-sun' : 'fas fa-moon'" />
    <span class="sr-only">{{ isDarkMode ? '切换到浅色模式' : '切换到深色模式' }}</span>
  </button>
</template>

<script>
import { ref, onMounted } from 'vue';

export default {
  name: 'ThemeSwitch',
  setup() {
    const isDarkMode = ref(false);

    // 检查本地存储或系统偏好
    const checkThemePreference = () => {
      const savedTheme = localStorage.getItem('theme');
      if (savedTheme === 'dark') {
        isDarkMode.value = true;
        document.documentElement.classList.add('dark');
      } else if (savedTheme === 'light') {
        isDarkMode.value = false;
        document.documentElement.classList.remove('dark');
      } else {
        // 检测系统偏好
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        isDarkMode.value = prefersDark;
        if (prefersDark) {
          document.documentElement.classList.add('dark');
        }
      }
    };

    // 切换主题
    const toggleTheme = () => {
      isDarkMode.value = !isDarkMode.value;
  
      if (isDarkMode.value) {
        document.documentElement.classList.add('dark');
        localStorage.setItem('theme', 'dark');
      } else {
        document.documentElement.classList.remove('dark');
        localStorage.setItem('theme', 'light');
      }
    };

    onMounted(() => {
      checkThemePreference();
    });

    return {
      isDarkMode,
      toggleTheme
    };
  }
};
</script>

<style scoped>
.theme-switch {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  color: white;
  cursor: pointer;
  font-size: 1.2rem;
  padding: 8px;
  border-radius: 50%;
  transition: all 0.2s;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.theme-switch:hover {
  background-color: rgba(255, 255, 255, 0.2);
  transform: scale(1.1);
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
</style>