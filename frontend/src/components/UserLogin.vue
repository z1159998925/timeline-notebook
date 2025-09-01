<template>
  <div class="login-container">
    <div class="login-form">
      <h2>用户登录</h2>
      <form @submit.prevent="handleLogin">
        <div class="form-group">
          <label for="username">用户名</label>
          <input
            id="username"
            v-model="form.username"
            type="text"
            required
            placeholder="请输入用户名"
          />
        </div>
        
        <div class="form-group">
          <label for="password">密码</label>
          <input
            id="password"
            v-model="form.password"
            type="password"
            required
            placeholder="请输入密码"
          />
        </div>
        
        <button type="submit" :disabled="loading" class="login-btn">
          {{ loading ? '登录中...' : '登录' }}
        </button>
      </form>
      
      <div v-if="message" class="message" :class="messageType">
        {{ message }}
      </div>
      
      <div class="register-link">
        <p>还没有账号？<router-link to="/register">立即注册</router-link></p>
      </div>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api/config.js'
import { clearAuthCache } from '../router/index.js'

export default {
  name: 'UserLogin',
  setup() {
    const router = useRouter()
    
    const form = ref({
      username: '',
      password: ''
    })
    
    const loading = ref(false)
    const message = ref('')
    const messageType = ref('')
    
    const handleLogin = async () => {
      loading.value = true
      message.value = ''
      
      try {
        const response = await api.post('/login', {
          username: form.value.username,
          password: form.value.password
        })
        
        message.value = '登录成功！'
        messageType.value = 'success'
        
        // 存储用户信息到localStorage
        if (response.data.user) {
          localStorage.setItem('user', JSON.stringify(response.data.user))
        }
        
        // 清除认证缓存，确保下次访问时重新获取最新状态
        clearAuthCache()
        
        // 清空表单
        form.value = {
          username: '',
          password: ''
        }
        
        // 延迟跳转，让用户看到成功消息
        setTimeout(() => {
          router.push('/')
        }, 1000)
        
      } catch (error) {
        console.error('登录失败:', error)
        message.value = error.response?.data?.message || '登录失败，请检查用户名和密码'
        messageType.value = 'error'
      } finally {
        loading.value = false
      }
    }
    
    return {
      form,
      loading,
      message,
      messageType,
      handleLogin
    }
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  padding: 20px;
}

.login-form {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

.login-form h2 {
  text-align: center;
  margin-bottom: 1.5rem;
  color: #333;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  color: #555;
  font-weight: 500;
}

.form-group input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  transition: border-color 0.3s;
}

.form-group input:focus {
  outline: none;
  border-color: #007bff;
}

.login-btn {
  width: 100%;
  padding: 0.75rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s;
}

.login-btn:hover:not(:disabled) {
  background: #0056b3;
}

.login-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.message {
  margin-top: 1rem;
  padding: 0.75rem;
  border-radius: 4px;
  text-align: center;
}

.message.success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.message.error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

.register-link {
  text-align: center;
  margin-top: 1.5rem;
  padding-top: 1rem;
  border-top: 1px solid #eee;
}

.register-link p {
  margin: 0;
  color: #666;
}

.register-link a {
  color: #007bff;
  text-decoration: none;
  font-weight: 500;
}

.register-link a:hover {
  text-decoration: underline;
}
</style>