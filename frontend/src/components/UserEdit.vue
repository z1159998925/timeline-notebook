<template>
  <div class="edit-profile">
    <div class="edit-header">
      <h2>编辑个人资料</h2>
      <button @click="$emit('close')" class="close-btn">&times;</button>
    </div>
    
    <form @submit.prevent="handleSubmit" class="edit-form">
      <!-- 头像上传 -->
      <div class="form-group">
        <label>头像</label>
        <div class="avatar-upload">
          <UserAvatar 
            :avatar-url="form.avatar_url" 
            :username="form.username"
            size="large"
            class="avatar-preview"
          />
          <div class="upload-controls">
            <input 
              ref="fileInput"
              type="file" 
              accept="image/*" 
              @change="handleFileSelect"
              style="display: none"
            />
            <button type="button" @click="$refs.fileInput.click()" class="upload-btn">
              选择图片
            </button>
            <p class="upload-hint">支持 JPG、PNG 格式，文件大小不超过 2MB</p>
          </div>
        </div>
      </div>
      
      <!-- 用户名 -->
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
      
      <!-- 邮箱 -->
      <div class="form-group">
        <label for="email">邮箱</label>
        <input
          id="email"
          v-model="form.email"
          type="email"
          placeholder="请输入邮箱"
        />
      </div>
      
      <!-- 个人简介 -->
      <div class="form-group">
        <label for="bio">个人简介</label>
        <textarea
          id="bio"
          v-model="form.bio"
          rows="4"
          placeholder="介绍一下自己吧..."
          maxlength="200"
        ></textarea>
        <div class="char-count">{{ (form.bio || '').length }}/200</div>
      </div>
      
      <!-- 密码修改 -->
      <div class="form-section">
        <h3>修改密码</h3>
        <div class="form-group">
          <label for="currentPassword">当前密码</label>
          <input
            id="currentPassword"
            v-model="form.currentPassword"
            type="password"
            placeholder="请输入当前密码"
          />
        </div>
        
        <div class="form-group">
          <label for="newPassword">新密码</label>
          <input
            id="newPassword"
            v-model="form.newPassword"
            type="password"
            placeholder="请输入新密码"
          />
        </div>
        
        <div class="form-group">
          <label for="confirmPassword">确认新密码</label>
          <input
            id="confirmPassword"
            v-model="form.confirmPassword"
            type="password"
            placeholder="请再次输入新密码"
          />
        </div>
      </div>
      
      <div v-if="message" class="message" :class="messageType">
        {{ message }}
      </div>
      
      <div class="form-actions">
        <button type="button" @click="$emit('close')" class="cancel-btn">
          取消
        </button>
        <button type="submit" :disabled="loading" class="save-btn">
          {{ loading ? '保存中...' : '保存' }}
        </button>
      </div>
    </form>
  </div>
</template>

<script>
import { ref, reactive, onMounted } from 'vue'
import api from '../api/config.js'
import UserAvatar from './UserAvatar.vue'

export default {
  name: 'UserEdit',
  components: {
    UserAvatar
  },
  props: {
    user: {
      type: Object,
      required: true
    }
  },
  emits: ['close', 'updated'],
  setup(props, { emit }) {
    const form = reactive({
      username: '',
      email: '',
      bio: '',
      avatar_url: '',
      currentPassword: '',
      newPassword: '',
      confirmPassword: ''
    })
    
    const loading = ref(false)
    const message = ref('')
    const messageType = ref('')
    const selectedFile = ref(null)
    
    const initForm = () => {
      form.username = props.user.username || ''
      form.email = props.user.email || ''
      form.bio = props.user.bio || ''
      form.avatar_url = props.user.avatar_url || ''
    }
    
    const handleFileSelect = (event) => {
      const file = event.target.files[0]
      if (!file) return
      
      // 验证文件类型
      if (!file.type.startsWith('image/')) {
        message.value = '请选择图片文件'
        messageType.value = 'error'
        return
      }
      
      // 验证文件大小 (2MB)
      if (file.size > 2 * 1024 * 1024) {
        message.value = '图片大小不能超过 2MB'
        messageType.value = 'error'
        return
      }
      
      selectedFile.value = file
      
      // 预览图片
      const reader = new FileReader()
      reader.onload = (e) => {
        form.avatar_url = e.target.result
      }
      reader.readAsDataURL(file)
      
      message.value = ''
    }
    
    const uploadAvatar = async () => {
      if (!selectedFile.value) return null
      
      const formData = new FormData()
      formData.append('avatar', selectedFile.value)
      
      try {
        const response = await api.post('/user/avatar', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })
        return response.data.avatar_url
      } catch (error) {
        console.error('头像上传失败:', error)
        throw new Error('头像上传失败')
      }
    }
    
    const validateForm = () => {
      // 验证密码
      if (form.newPassword || form.confirmPassword || form.currentPassword) {
        if (!form.currentPassword) {
          message.value = '请输入当前密码'
          messageType.value = 'error'
          return false
        }
        
        if (!form.newPassword) {
          message.value = '请输入新密码'
          messageType.value = 'error'
          return false
        }
        
        if (form.newPassword !== form.confirmPassword) {
          message.value = '两次输入的新密码不一致'
          messageType.value = 'error'
          return false
        }
        
        if (form.newPassword.length < 6) {
          message.value = '新密码长度至少为6位'
          messageType.value = 'error'
          return false
        }
      }
      
      return true
    }
    
    const handleSubmit = async () => {
      if (!validateForm()) return
      
      loading.value = true
      message.value = ''
      
      try {
        // 上传头像
        let avatarUrl = form.avatar_url
        if (selectedFile.value) {
          avatarUrl = await uploadAvatar()
        }
        
        // 准备更新数据
        const updateData = {
          username: form.username,
          email: form.email,
          bio: form.bio,
          avatar_url: avatarUrl
        }
        
        // 如果要修改密码
        if (form.newPassword) {
          updateData.current_password = form.currentPassword
          updateData.new_password = form.newPassword
        }
        
        const response = await api.put('/user/profile', updateData)
        
        message.value = '保存成功！'
        messageType.value = 'success'
        
        // 通知父组件更新
        emit('updated', response.data.user)
        
        // 延迟关闭
        setTimeout(() => {
          emit('close')
        }, 1000)
        
      } catch (error) {
        console.error('保存失败:', error)
        message.value = error.response?.data?.message || '保存失败，请重试'
        messageType.value = 'error'
      } finally {
        loading.value = false
      }
    }
    
    onMounted(() => {
      initForm()
    })
    
    return {
      form,
      loading,
      message,
      messageType,
      handleFileSelect,
      handleSubmit
    }
  }
}
</script>

<style scoped>
.edit-profile {
  padding: 20px;
}

.edit-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 15px;
  border-bottom: 1px solid #e9ecef;
}

.edit-header h2 {
  margin: 0;
  color: #333;
}

.close-btn {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: #666;
  padding: 0;
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.close-btn:hover {
  color: #333;
}

.edit-form {
  max-height: 60vh;
  overflow-y: auto;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  color: #555;
  font-weight: 500;
}

.form-group input,
.form-group textarea {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
  transition: border-color 0.3s;
}

.form-group input:focus,
.form-group textarea:focus {
  outline: none;
  border-color: #007bff;
}

.avatar-upload {
  display: flex;
  gap: 20px;
  align-items: flex-start;
}

.avatar-preview {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  object-fit: cover;
  border: 2px solid #e9ecef;
}

.upload-controls {
  flex: 1;
}

.upload-btn {
  padding: 8px 16px;
  background: #f8f9fa;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: background-color 0.3s;
}

.upload-btn:hover {
  background: #e9ecef;
}

.upload-hint {
  margin: 8px 0 0 0;
  font-size: 12px;
  color: #666;
}

.char-count {
  text-align: right;
  font-size: 12px;
  color: #666;
  margin-top: 5px;
}

.form-section {
  margin-top: 30px;
  padding-top: 20px;
  border-top: 1px solid #e9ecef;
}

.form-section h3 {
  margin: 0 0 15px 0;
  color: #333;
  font-size: 16px;
}

.message {
  padding: 10px;
  border-radius: 4px;
  margin-bottom: 20px;
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

.form-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  padding-top: 20px;
  border-top: 1px solid #e9ecef;
}

.cancel-btn {
  padding: 10px 20px;
  background: #f8f9fa;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: background-color 0.3s;
}

.cancel-btn:hover {
  background: #e9ecef;
}

.save-btn {
  padding: 10px 20px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: background-color 0.3s;
}

.save-btn:hover:not(:disabled) {
  background: #0056b3;
}

.save-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .avatar-upload {
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  
  .form-actions {
    flex-direction: column;
  }
  
  .form-actions button {
    width: 100%;
  }
}
</style>