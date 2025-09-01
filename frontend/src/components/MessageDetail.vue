<template>
  <div class="message-detail">
    <!-- 页面标题 -->
    <div class="header">
      <button @click="goBack" class="back-btn">
        ← 返回
      </button>
      <h1 class="title">留言详情</h1>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner"></div>
      <p>加载中...</p>
    </div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="error-container">
      <div class="error-icon">⚠️</div>
      <h3>加载失败</h3>
      <p>{{ error }}</p>
      <button @click="loadMessage" class="retry-btn">重试</button>
    </div>

    <!-- 留言详情 -->
    <div v-else-if="message" class="message-content">
      <!-- 留言主体 -->
      <div class="message-card">
        <!-- 用户信息 -->
        <div class="message-header">
          <div class="user-info">
            <div class="user-avatar">
              <img v-if="message.user.avatar_url" :src="message.user.avatar_url" :alt="message.user.username" />
              <div v-else class="default-avatar">{{ message.user.username.charAt(0).toUpperCase() }}</div>
            </div>
            <div class="user-details">
              <h3 class="username">{{ message.user.username }}</h3>
              <p class="message-time">{{ formatTime(message.created_at) }}</p>
            </div>
          </div>
          
          <!-- 置顶标识 -->
          <div v-if="message.is_pinned" class="pin-badge">
            📌 置顶
          </div>
          
          <!-- 管理员操作 -->
          <div v-if="isAdmin" class="admin-actions">
            <button @click="togglePin" class="action-btn" :disabled="actionLoading">
              {{ message.is_pinned ? '取消置顶' : '置顶' }}
            </button>
            <button @click="deleteMessage" class="action-btn delete-btn" :disabled="actionLoading">
              删除
            </button>
          </div>
        </div>

        <!-- 留言内容 -->
        <div class="message-body">
          <p class="message-text">{{ message.content }}</p>
          
          <!-- 图片展示 -->
          <div v-if="message.images && message.images.length > 0" class="message-images">
            <div 
              v-for="(image, index) in message.images" 
              :key="index"
              class="image-item"
              @click="openImageModal(index)"
            >
              <img :src="image.image_url" :alt="`图片 ${index + 1}`" />
            </div>
          </div>
        </div>

        <!-- 留言统计 -->
        <div class="message-stats">
          <button 
            @click="toggleLike" 
            class="stat-btn like-btn"
            :class="{ 'liked': message.user_liked }"
            :disabled="!isLoggedIn || likeLoading"
          >
            <span class="icon">{{ message.user_liked ? '❤️' : '🤍' }}</span>
            <span class="count">{{ message.like_count }}</span>
          </button>
          
          <div class="stat-item">
            <span class="icon">💬</span>
            <span class="count">{{ comments.length }}</span>
          </div>
        </div>
      </div>

      <!-- 评论区 -->
      <div class="comments-section">
        <h2 class="section-title">评论 ({{ comments.length }})</h2>
        
        <!-- 发表评论 -->
        <div v-if="isLoggedIn" class="comment-form">
          <form @submit.prevent="submitComment">
            <div class="form-group">
              <textarea
                v-model="commentForm.content"
                class="comment-input"
                placeholder="写下你的评论..."
                rows="3"
                maxlength="500"
                required
              ></textarea>
              <div class="char-count">{{ commentForm.content.length }}/500</div>
            </div>
            <div class="form-actions">
              <button 
                type="submit" 
                class="submit-btn"
                :disabled="!commentForm.content.trim() || commentSubmitting"
              >
                <span v-if="commentSubmitting" class="loading-spinner"></span>
                {{ commentSubmitting ? '发布中...' : '发表评论' }}
              </button>
            </div>
          </form>
        </div>
        
        <div v-else class="login-prompt">
          <p>请先 <router-link to="/admin-login" class="login-link">登录</router-link> 后发表评论</p>
        </div>

        <!-- 评论列表 -->
        <div class="comments-list">
          <div v-if="commentsLoading" class="loading-container">
            <div class="loading-spinner"></div>
            <p>加载评论中...</p>
          </div>
          
          <div v-else-if="comments.length === 0" class="empty-comments">
            <div class="empty-icon">💭</div>
            <p>暂无评论，快来抢沙发吧！</p>
          </div>
          
          <div v-else>
            <div 
              v-for="comment in comments" 
              :key="comment.id"
              class="comment-item"
            >
              <div class="comment-header">
                <div class="user-info">
                  <UserAvatar 
                    :avatar-url="comment.user.avatar_url" 
                    :username="comment.user.username"
                    size="small"
                    class="user-avatar"
                  />
                  <div class="user-details">
                    <h4 class="username">{{ comment.user.username }}</h4>
                    <p class="comment-time">{{ formatTime(comment.created_at) }}</p>
                  </div>
                </div>
                
                <!-- 删除按钮 -->
                <button 
                  v-if="isAdmin || (currentUser && currentUser.id === comment.user.id)"
                  @click="deleteComment(comment.id)"
                  class="delete-comment-btn"
                  title="删除评论"
                >
                  🗑️
                </button>
              </div>
              
              <div class="comment-content">
                <p>{{ comment.content }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 图片预览模态框 -->
    <div v-if="showImageModal" class="image-modal" @click="closeImageModal">
      <div class="modal-content" @click.stop>
        <button @click="closeImageModal" class="close-btn">×</button>
        <img :src="currentImage" alt="预览图片" />
        <div class="image-nav">
          <button 
            @click="prevImage" 
            class="nav-btn"
            :disabled="currentImageIndex === 0"
          >
            ← 上一张
          </button>
          <span class="image-counter">
            {{ currentImageIndex + 1 }} / {{ message.images.length }}
          </span>
          <button 
            @click="nextImage" 
            class="nav-btn"
            :disabled="currentImageIndex === message.images.length - 1"
          >
            下一张 →
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import api from '../axios.js'
import UserAvatar from './UserAvatar.vue'

export default {
  name: 'MessageDetail',
  components: {
    UserAvatar
  },
  data() {
    return {
      message: null,
      comments: [],
      loading: true,
      commentsLoading: false,
      error: null,
      isLoggedIn: false,
      isAdmin: false,
      currentUser: null,
      actionLoading: false,
      likeLoading: false,
      commentSubmitting: false,
      commentForm: {
        content: ''
      },
      showImageModal: false,
      currentImageIndex: 0
    }
  },
  computed: {
    messageId() {
      return this.$route.params.id
    },
    currentImage() {
      if (this.message?.images && this.message.images[this.currentImageIndex]) {
        return this.message.images[this.currentImageIndex].image_url
      }
      return ''
    }
  },
  methods: {
    // 返回上一页
    goBack() {
      this.$router.go(-1)
    },

    // 加载留言详情
    async loadMessage() {
      this.loading = true
      this.error = null
      
      try {
        const response = await api.get(`/messages/${this.messageId}`)
        this.message = response.data
        await this.loadComments()
      } catch (error) {
        console.error('加载留言详情失败:', error)
        if (error.response?.status === 404) {
          this.error = '留言不存在或已被删除'
        } else {
          this.error = '加载失败，请稍后重试'
        }
      } finally {
        this.loading = false
      }
    },

    // 加载评论列表
    async loadComments() {
      this.commentsLoading = true
      
      try {
        const response = await api.get(`/messages/${this.messageId}/comments`)
        this.comments = response.data
      } catch (error) {
        console.error('加载评论失败:', error)
      } finally {
        this.commentsLoading = false
      }
    },

    // 检查登录状态
    async checkLoginStatus() {
      try {
        const response = await api.get('/login-status')
        this.isLoggedIn = response.data.is_logged_in
        this.isAdmin = response.data.is_admin
        this.currentUser = response.data.user
      } catch (error) {
        console.error('检查登录状态失败:', error)
        this.isLoggedIn = false
        this.isAdmin = false
        this.currentUser = null
      }
    },

    // 切换点赞状态
    async toggleLike() {
      if (!this.isLoggedIn || this.likeLoading) return
      
      this.likeLoading = true
      
      try {
        const response = await api.post(`/messages/${this.messageId}/like`)
        
        // 更新点赞状态
        this.message.user_liked = response.data.liked
        this.message.like_count = response.data.like_count
        
      } catch (error) {
        console.error('点赞操作失败:', error)
        this.$toast?.error('操作失败，请稍后重试')
      } finally {
        this.likeLoading = false
      }
    },

    // 切换置顶状态
    async togglePin() {
      if (!this.isAdmin || this.actionLoading) return
      
      this.actionLoading = true
      
      try {
        const response = await api.post(`/messages/${this.messageId}/pin`)
        this.message.is_pinned = response.data.is_pinned
        
        this.$toast?.success(response.data.is_pinned ? '置顶成功' : '取消置顶成功')
      } catch (error) {
        console.error('置顶操作失败:', error)
        this.$toast?.error('操作失败，请稍后重试')
      } finally {
        this.actionLoading = false
      }
    },

    // 删除留言
    async deleteMessage() {
      if (!this.isAdmin || this.actionLoading) return
      
      if (!confirm('确定要删除这条留言吗？此操作不可撤销。')) {
        return
      }
      
      this.actionLoading = true
      
      try {
        await api.delete(`/messages/${this.messageId}`)
        this.$toast?.success('留言删除成功')
        this.$router.push('/messages')
      } catch (error) {
        console.error('删除留言失败:', error)
        this.$toast?.error('删除失败，请稍后重试')
      } finally {
        this.actionLoading = false
      }
    },

    // 提交评论
    async submitComment() {
      if (!this.commentForm.content.trim() || this.commentSubmitting) return
      
      this.commentSubmitting = true
      
      try {
        const response = await api.post(`/messages/${this.messageId}/comments`, {
          content: this.commentForm.content.trim()
        })
        
        // 添加新评论到列表
        this.comments.unshift(response.data)
        
        // 清空表单
        this.commentForm.content = ''
        
        this.$toast?.success('评论发表成功')
      } catch (error) {
        console.error('发表评论失败:', error)
        if (error.response?.data?.message) {
          this.$toast?.error(error.response.data.message)
        } else {
          this.$toast?.error('发表失败，请稍后重试')
        }
      } finally {
        this.commentSubmitting = false
      }
    },

    // 删除评论
    async deleteComment(commentId) {
      if (!confirm('确定要删除这条评论吗？')) {
        return
      }
      
      try {
        await api.delete(`/messages/${this.messageId}/comments/${commentId}`)
        
        // 从列表中移除评论
        this.comments = this.comments.filter(comment => comment.id !== commentId)
        
        this.$toast?.success('评论删除成功')
      } catch (error) {
        console.error('删除评论失败:', error)
        this.$toast?.error('删除失败，请稍后重试')
      }
    },

    // 打开图片模态框
    openImageModal(index) {
      this.currentImageIndex = index
      this.showImageModal = true
      document.body.style.overflow = 'hidden'
    },

    // 关闭图片模态框
    closeImageModal() {
      this.showImageModal = false
      document.body.style.overflow = 'auto'
    },

    // 上一张图片
    prevImage() {
      if (this.currentImageIndex > 0) {
        this.currentImageIndex--
      }
    },

    // 下一张图片
    nextImage() {
      if (this.currentImageIndex < this.message.images.length - 1) {
        this.currentImageIndex++
      }
    },

    // 格式化时间
    formatTime(timestamp) {
      const date = new Date(timestamp)
      const now = new Date()
      const diff = now - date
      
      const minutes = Math.floor(diff / 60000)
      const hours = Math.floor(diff / 3600000)
      const days = Math.floor(diff / 86400000)
      
      if (minutes < 1) {
        return '刚刚'
      } else if (minutes < 60) {
        return `${minutes}分钟前`
      } else if (hours < 24) {
        return `${hours}小时前`
      } else if (days < 7) {
        return `${days}天前`
      } else {
        return date.toLocaleDateString('zh-CN', {
          year: 'numeric',
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        })
      }
    }
  },

  async mounted() {
    await this.checkLoginStatus()
    await this.loadMessage()
  },

  beforeUnmount() {
    // 确保页面卸载时恢复滚动
    document.body.style.overflow = 'auto'
  }
}
</script>

<style scoped>
.message-detail {
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

.loading-container,
.error-container {
  text-align: center;
  padding: 60px 20px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #e2e8f0;
  border-top: 4px solid #667eea;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 16px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.error-icon {
  font-size: 3rem;
  margin-bottom: 16px;
}

.retry-btn {
  background: #667eea;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 8px;
  cursor: pointer;
  margin-top: 16px;
}

.message-card {
  background: white;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  margin-bottom: 30px;
}

.message-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  overflow: hidden;
  background: #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
}

.user-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.default-avatar {
  font-size: 1.2rem;
  font-weight: bold;
  color: #4a5568;
}

.username {
  font-size: 1.1rem;
  font-weight: 600;
  color: #2d3748;
  margin: 0 0 4px 0;
}

.message-time {
  font-size: 0.9rem;
  color: #718096;
  margin: 0;
}

.pin-badge {
  background: linear-gradient(135deg, #ffd89b 0%, #19547b 100%);
  color: white;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 0.8rem;
  font-weight: 600;
}

.admin-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  background: white;
  border: 1px solid #e2e8f0;
  color: #4a5568;
  padding: 6px 12px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.8rem;
  transition: all 0.2s ease;
}

.action-btn:hover:not(:disabled) {
  background: #f7fafc;
  border-color: #cbd5e0;
}

.delete-btn {
  color: #e53e3e;
  border-color: #fed7d7;
}

.delete-btn:hover:not(:disabled) {
  background: #fed7d7;
  border-color: #feb2b2;
}

.message-text {
  font-size: 1.1rem;
  line-height: 1.6;
  color: #2d3748;
  margin: 0 0 16px 0;
  white-space: pre-wrap;
}

.message-images {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}

.image-item {
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.image-item:hover {
  transform: scale(1.02);
}

.image-item img {
  width: 100%;
  height: 200px;
  object-fit: cover;
}

.message-stats {
  display: flex;
  align-items: center;
  gap: 20px;
  padding-top: 16px;
  border-top: 1px solid #e2e8f0;
}

.stat-btn,
.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.9rem;
  color: #718096;
}

.like-btn {
  background: none;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
}

.like-btn:hover:not(:disabled) {
  color: #e53e3e;
}

.like-btn.liked {
  color: #e53e3e;
}

.like-btn:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.comments-section {
  background: white;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.section-title {
  font-size: 1.3rem;
  font-weight: 600;
  color: #2d3748;
  margin: 0 0 20px 0;
}

.comment-form {
  margin-bottom: 30px;
  padding-bottom: 20px;
  border-bottom: 1px solid #e2e8f0;
}

.comment-input {
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

.comment-input:focus {
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

.form-actions {
  margin-top: 12px;
}

.submit-btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 10px 20px;
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

.login-prompt {
  text-align: center;
  padding: 20px;
  background: #f7fafc;
  border-radius: 8px;
  margin-bottom: 20px;
}

.login-link {
  color: #667eea;
  text-decoration: none;
  font-weight: 600;
}

.login-link:hover {
  text-decoration: underline;
}

.empty-comments {
  text-align: center;
  padding: 40px 20px;
  color: #718096;
}

.empty-icon {
  font-size: 3rem;
  margin-bottom: 12px;
}

.comment-item {
  padding: 16px 0;
  border-bottom: 1px solid #f1f5f9;
}

.comment-item:last-child {
  border-bottom: none;
}

.comment-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.comment-header .user-avatar {
  width: 36px;
  height: 36px;
}

.comment-header .username {
  font-size: 1rem;
  margin: 0 0 2px 0;
}

.comment-time {
  font-size: 0.8rem;
  color: #a0aec0;
  margin: 0;
}

.delete-comment-btn {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 1.2rem;
  color: #a0aec0;
  transition: color 0.2s ease;
}

.delete-comment-btn:hover {
  color: #e53e3e;
}

.comment-content {
  margin-left: 48px;
  font-size: 0.95rem;
  line-height: 1.5;
  color: #4a5568;
}

.comment-content p {
  margin: 0;
  white-space: pre-wrap;
}

/* 图片模态框 */
.image-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.9);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  position: relative;
  max-width: 90vw;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.modal-content img {
  max-width: 100%;
  max-height: 80vh;
  object-fit: contain;
  border-radius: 8px;
}

.close-btn {
  position: absolute;
  top: -40px;
  right: 0;
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  cursor: pointer;
  font-size: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.image-nav {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-top: 16px;
  color: white;
}

.nav-btn {
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.2s ease;
}

.nav-btn:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.3);
}

.nav-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.image-counter {
  font-size: 0.9rem;
}

@media (max-width: 768px) {
  .message-detail {
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
  
  .message-card,
  .comments-section {
    padding: 16px;
  }
  
  .message-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }
  
  .admin-actions {
    width: 100%;
    justify-content: flex-end;
  }
  
  .message-images {
    grid-template-columns: 1fr;
  }
  
  .comment-content {
    margin-left: 0;
    margin-top: 8px;
  }
  
  .modal-content {
    max-width: 95vw;
  }
  
  .image-nav {
    flex-direction: column;
    gap: 8px;
  }
}
</style>