<template>
  <div class="health-check" v-if="showHealthCheck">
    <div class="health-status" :class="healthStatus.class">
      <span class="status-icon">{{ healthStatus.icon }}</span>
      <span class="status-text">{{ healthStatus.text }}</span>
      <button @click="checkHealth" class="refresh-btn" :disabled="checking">
        {{ checking ? '检查中...' : '刷新' }}
      </button>
    </div>
    <div v-if="healthData" class="health-details">
      <small>版本: {{ healthData.version }} | 环境: {{ healthData.environment }}</small>
    </div>
  </div>
</template>

<script>
import api from '../axios.js'

export default {
  name: 'HealthCheck',
  data() {
    return {
      healthStatus: {
        class: 'unknown',
        icon: '⚪',
        text: '未知'
      },
      healthData: null,
      checking: false,
      showHealthCheck: false
    }
  },
  mounted() {
    // 只在开发环境或管理员模式下显示健康检查
    this.showHealthCheck = this.isDevelopment() || this.isAdmin()
    if (this.showHealthCheck) {
      this.checkHealth()
      // 每30秒自动检查一次
      this.healthCheckInterval = setInterval(this.checkHealth, 30000)
    }
  },
  beforeUnmount() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval)
    }
  },
  methods: {
    async checkHealth() {
      this.checking = true
      try {
        const response = await api.get('/api/health')
        this.healthData = response.data
        
        if (response.data.status === 'healthy') {
          this.healthStatus = {
            class: 'healthy',
            icon: '✅',
            text: '服务正常'
          }
        } else {
          this.healthStatus = {
            class: 'unhealthy',
            icon: '❌',
            text: '服务异常'
          }
        }
      } catch (error) {
        this.healthStatus = {
          class: 'error',
          icon: '🔴',
          text: '连接失败'
        }
        this.healthData = null
        console.error('健康检查失败:', error)
      } finally {
        this.checking = false
      }
    },
    isDevelopment() {
      return import.meta.env.DEV || import.meta.env.MODE === 'development'
    },
    isAdmin() {
      // 检查是否为管理员用户
      return this.$root.user && this.$root.user.role === 'admin'
    }
  }
}
</script>

<style scoped>
.health-check {
  position: fixed;
  top: 10px;
  right: 10px;
  z-index: 1000;
  background: rgba(255, 255, 255, 0.9);
  border-radius: 8px;
  padding: 8px 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  font-size: 12px;
  backdrop-filter: blur(10px);
}

.health-status {
  display: flex;
  align-items: center;
  gap: 6px;
}

.status-icon {
  font-size: 14px;
}

.status-text {
  font-weight: 500;
}

.refresh-btn {
  background: none;
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 2px 6px;
  font-size: 10px;
  cursor: pointer;
  transition: all 0.2s;
}

.refresh-btn:hover:not(:disabled) {
  background: #f5f5f5;
}

.refresh-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.health-details {
  margin-top: 4px;
  color: #666;
  font-size: 10px;
}

.healthy {
  color: #52c41a;
}

.unhealthy {
  color: #ff4d4f;
}

.error {
  color: #fa8c16;
}

.unknown {
  color: #8c8c8c;
}

/* 暗色主题适配 */
.dark .health-check {
  background: rgba(0, 0, 0, 0.8);
  color: #fff;
}

.dark .refresh-btn {
  border-color: #555;
  color: #fff;
}

.dark .refresh-btn:hover:not(:disabled) {
  background: #333;
}

.dark .health-details {
  color: #ccc;
}
</style>