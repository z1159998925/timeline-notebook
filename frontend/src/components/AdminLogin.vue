<template>
  <div class="admin-login-container">
    <div class="login-form">
      <h2>管理员登录</h2>
      <div class="form-group">
        <label for="username">用户名</label>
        <input type="text" id="username" v-model="username" placeholder="输入用户名">
      </div>
      <div class="form-group">
        <label for="password">密码</label>
        <input type="password" id="password" v-model="password" placeholder="输入密码">
      </div>
      <button @click="login" class="login-button">登录</button>
      <p v-if="errorMessage" class="error-message">{{ errorMessage }}</p>
    </div>
  </div>
</template>

<script>
import api from '../axios.js';

export default {
  name: 'AdminLogin',
  data() {
    return {
      username: '',
      password: '',
      errorMessage: ''
    };
  },
  methods: {
    login() {
      if (!this.username || !this.password) {
        this.errorMessage = '用户名和密码不能为空';
        return;
      }

      api.post('/login', {
        username: this.username,
        password: this.password
      })
      .then(response => {

        if (response.data.user && response.data.user.role === 'admin') {
          // 登录成功，跳转到管理页面
          try {
            // 立即检查登录状态
            api.get('/login-status')
              .then(statusResponse => {

                this.$router.push('/admin-dashboard');
              })
              .catch(err => {
                console.error('检查登录状态失败:', err);
                this.errorMessage = '检查登录状态失败: ' + err.message;
              });
          } catch (err) {
            console.error('跳转异常:', err);
            this.errorMessage = '跳转异常: ' + err.message;
          }
        } else {
          this.errorMessage = '不是管理员账号';
        }
      })
      .catch(error => {
        console.error('登录请求失败:', error);
        this.errorMessage = '登录失败: ' + (error.response?.data?.message || error.message);
      });
    }
  }
};
</script>

<style scoped>
.admin-login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background-color: #f5f5f5;
}

.login-form {
  background-color: white;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

h2 {
  text-align: center;
  margin-bottom: 20px;
  color: #333;
}

.form-group {
  margin-bottom: 15px;
}

label {
  display: block;
  margin-bottom: 5px;
  color: #555;
}

input {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  box-sizing: border-box;
}

.login-button {
  width: 100%;
  padding: 10px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 16px;
}

.login-button:hover {
  background-color: #2563eb;
}

.error-message {
  color: #ef4444;
  margin-top: 10px;
  text-align: center;
}
</style>