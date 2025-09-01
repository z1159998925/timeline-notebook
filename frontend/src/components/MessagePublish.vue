<template>
  <div class="message-publish">
    <!-- 页面标题 -->
    <div class="header">
      <button @click="goBack" class="back-btn">
        ← 返回
      </button>
      <h1 class="title">发布留言</h1>
    </div>

    <!-- 发布表单 -->
    <div class="publish-form">
      <form @submit.prevent="publishMessage">
        <!-- 文字内容输入 -->
        <div class="form-group">
          <label for="content" class="form-label">留言内容</label>
          <textarea
            id="content"
            v-model="form.content"
            class="content-input"
            placeholder="分享你的想法..."
            rows="6"
            maxlength="1000"
            required
          ></textarea>
          <div class="char-count">
            {{ form.content.length }}/1000
          </div>
        </div>

        <!-- 图片上传 -->
        <div class="form-group">
          <label class="form-label">图片 (可选)</label>
          <div class="upload-area">
            <!-- 上传按钮 -->
            <div class="upload-trigger" @click="triggerFileInput">
              <input
                ref="fileInput"
                type="file"
                multiple
                accept="image/*"
                @change="handleFileSelect"
                style="display: none;"
              >
              <div class="upload-icon">📷</div>
              <p class="upload-text">点击选择图片</p>
              <p class="upload-hint">支持 JPG、PNG 格式，最多 5 张</p>
            </div>

            <!-- 已选择的图片预览 -->
            <div v-if="selectedImages.length > 0" class="image-preview-list">
              <div
                v-for="(image, index) in selectedImages"
                :key="index"
                class="image-preview-item"
              >
                <img :src="image.preview" :alt="image.file.name" />
                <div class="image-info">
                  <p class="image-name">{{ image.file.name }}</p>
                  <p class="image-size">{{ formatFileSize(image.file.size) }}</p>
                </div>
                <button
                  type="button"
                  @click="removeImage(index)"
                  class="remove-btn"
                  title="删除图片"
                >
                  ×
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 发布按钮 -->
        <div class="form-actions">
          <button
            type="button"
            @click="goBack"
            class="cancel-btn"
            :disabled="publishing"
          >
            取消
          </button>
          <button
            type="submit"
            class="submit-btn"
            :disabled="!canSubmit || publishing"
          >
            <span v-if="publishing" class="loading-spinner"></span>
            {{ publishing ? '发布中...' : '发布留言' }}
          </button>
        </div>
      </form>
    </div>

    <!-- 发布提示 -->
    <div class="publish-tips">
      <h3>发布须知</h3>
      <ul>
        <li>请文明发言，遵守社区规范</li>
        <li>不得发布违法、暴力、色情等不当内容</li>
        <li>图片大小不超过 5MB，格式支持 JPG、PNG</li>
        <li>留言发布后可以删除，但无法修改</li>
      </ul>
    </div>
  </div>
</template>

<script>
import api from '../axios.js'

export default {
  name: 'MessagePublish',
  data() {
    return {
      form: {
        content: ''
      },
      selectedImages: [],
      publishing: false,
      maxImages: 5,
      maxFileSize: 5 * 1024 * 1024 // 5MB
    }
  },
  computed: {
    canSubmit() {
      return this.form.content.trim().length > 0 && !this.publishing
    }
  },
  methods: {
    // 返回上一页
    goBack() {
      this.$router.go(-1)
    },

    // 触发文件选择
    triggerFileInput() {
      this.$refs.fileInput.click()
    },

    // 处理文件选择
    handleFileSelect(event) {
      const files = Array.from(event.target.files)
      
      // 检查文件数量限制
      if (this.selectedImages.length + files.length > this.maxImages) {
        this.$toast?.warning(`最多只能选择 ${this.maxImages} 张图片`)
        return
      }

      // 处理每个文件
      files.forEach(file => {
        // 检查文件类型
        if (!file.type.startsWith('image/')) {
          this.$toast?.warning(`文件 ${file.name} 不是有效的图片格式`)
          return
        }

        // 检查文件大小
        if (file.size > this.maxFileSize) {
          this.$toast?.warning(`文件 ${file.name} 大小超过 5MB 限制`)
          return
        }

        // 创建预览
        const reader = new FileReader()
        reader.onload = (e) => {
          this.selectedImages.push({
            file: file,
            preview: e.target.result
          })
        }
        reader.readAsDataURL(file)
      })

      // 清空文件输入
      event.target.value = ''
    },

    // 删除图片
    removeImage(index) {
      this.selectedImages.splice(index, 1)
    },

    // 格式化文件大小
    formatFileSize(bytes) {
      if (bytes === 0) return '0 B'
      const k = 1024
      const sizes = ['B', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    },

    // 发布留言
    async publishMessage() {
      if (!this.canSubmit) return

      this.publishing = true

      try {
        // 创建 FormData
        const formData = new FormData()
        formData.append('content', this.form.content.trim())

        // 添加图片文件
        this.selectedImages.forEach((image, index) => {
          formData.append('images', image.file)
        })

        // 发送请求
        const response = await api.post('/messages', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })

        this.$toast?.success('留言发布成功！')
        
        // 跳转到留言详情页或返回列表
        if (response.data.id) {
          this.$router.push(`/messages/${response.data.id}`)
        } else {
          this.$router.push('/messages')
        }

      } catch (error) {
        console.error('发布留言失败:', error)
        
        if (error.response?.data?.message) {
          this.$toast?.error(error.response.data.message)
        } else {
          this.$toast?.error('发布失败，请稍后重试')
        }
      } finally {
        this.publishing = false
      }
    },

    // 检查登录状态
    async checkLoginStatus() {
      try {
        const response = await api.get('/login-status')
        if (!response.data.is_logged_in) {
          this.$toast?.warning('请先登录')
          this.$router.push('/admin-login')
        }
      } catch (error) {
        console.error('检查登录状态失败:', error)
        this.$router.push('/admin-login')
      }
    }
  },

  async mounted() {
    await this.checkLoginStatus()
  }
}
</script>

<style scoped>
.message-publish {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  background: #f8fafc;
  min-height: 100vh;
}

.header {
  display: flex;
  align-items: center;
  margin-bottom: 30px;
  gap: 16px;
}

.back-btn {
  background: white;
  border: 1px solid #e2e8f0;
  padding: 8px 16px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.9rem;
  color: #4a5568;
  transition: all 0.2s ease;
}

.back-btn:hover {
  background: #f7fafc;
  border-color: #cbd5e0;
}

.title {
  font-size: 2rem;
  font-weight: bold;
  color: #1a202c;
  margin: 0;
}

.publish-form {
  background: white;
  border-radius: 12px;
  padding: 30px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  margin-bottom: 30px;
}

.form-group {
  margin-bottom: 24px;
}

.form-label {
  display: block;
  font-size: 1rem;
  font-weight: 600;
  color: #2d3748;
  margin-bottom: 8px;
}

.content-input {
  width: 100%;
  padding: 12px 16px;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 1rem;
  line-height: 1.5;
  resize: vertical;
  transition: border-color 0.2s ease;
  font-family: inherit;
}

.content-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.char-count {
  text-align: right;
  font-size: 0.8rem;
  color: #718096;
  margin-top: 4px;
}

.upload-area {
  border: 2px dashed #e2e8f0;
  border-radius: 8px;
  padding: 20px;
  transition: all 0.2s ease;
}

.upload-area:hover {
  border-color: #cbd5e0;
  background: #f7fafc;
}

.upload-trigger {
  text-align: center;
  cursor: pointer;
  padding: 20px;
}

.upload-icon {
  font-size: 3rem;
  margin-bottom: 12px;
}

.upload-text {
  font-size: 1.1rem;
  font-weight: 600;
  color: #4a5568;
  margin: 0 0 4px 0;
}

.upload-hint {
  font-size: 0.9rem;
  color: #718096;
  margin: 0;
}

.image-preview-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 16px;
  margin-top: 20px;
}

.image-preview-item {
  position: relative;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.image-preview-item img {
  width: 100%;
  height: 150px;
  object-fit: cover;
}

.image-info {
  padding: 12px;
}

.image-name {
  font-size: 0.9rem;
  font-weight: 500;
  color: #2d3748;
  margin: 0 0 4px 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.image-size {
  font-size: 0.8rem;
  color: #718096;
  margin: 0;
}

.remove-btn {
  position: absolute;
  top: 8px;
  right: 8px;
  background: rgba(0, 0, 0, 0.7);
  color: white;
  border: none;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  cursor: pointer;
  font-size: 1.2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s ease;
}

.remove-btn:hover {
  background: rgba(0, 0, 0, 0.9);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 30px;
  padding-top: 20px;
  border-top: 1px solid #e2e8f0;
}

.cancel-btn {
  background: white;
  border: 1px solid #e2e8f0;
  color: #4a5568;
  padding: 10px 20px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.9rem;
  transition: all 0.2s ease;
}

.cancel-btn:hover:not(:disabled) {
  background: #f7fafc;
  border-color: #cbd5e0;
}

.submit-btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 10px 24px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.9rem;
  font-weight: 600;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 8px;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.submit-btn:disabled {
  background: #cbd5e0;
  cursor: not-allowed;
  transform: none;
  box-shadow: none;
}

.loading-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid transparent;
  border-top: 2px solid currentColor;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.publish-tips {
  background: white;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.publish-tips h3 {
  font-size: 1.2rem;
  font-weight: 600;
  color: #2d3748;
  margin: 0 0 16px 0;
}

.publish-tips ul {
  margin: 0;
  padding-left: 20px;
}

.publish-tips li {
  font-size: 0.9rem;
  color: #4a5568;
  line-height: 1.6;
  margin-bottom: 8px;
}

@media (max-width: 768px) {
  .message-publish {
    padding: 16px;
  }
  
  .header {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }
  
  .title {
    font-size: 1.5rem;
  }
  
  .publish-form {
    padding: 20px;
  }
  
  .image-preview-list {
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  }
  
  .form-actions {
    flex-direction: column;
  }
  
  .cancel-btn,
  .submit-btn {
    width: 100%;
    justify-content: center;
  }
}
</style>