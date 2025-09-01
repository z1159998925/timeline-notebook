<template>
  <div class="message-wall">
    <!-- 页面标题 -->
    <div class="header">
      <h1 class="title">留言墙</h1>
      <p class="subtitle">分享你的想法，记录美好时光</p>
    </div>

    <!-- 发布留言按钮 -->
    <div class="publish-section">
      <button 
        @click="goToPublish" 
        class="publish-btn"
        :disabled="!isLoggedIn"
      >
        <i class="icon">✏️</i>
        {{ isLoggedIn ? '发布留言' : '请先登录' }}
      </button>
      <div v-if="!isLoggedIn" class="login-hint">
        <router-link to="/admin-login" class="login-link">点击登录</router-link>
      </div>
    </div>

    <!-- 留言列表 -->
    <div class="messages-container">
      <!-- 加载状态 -->
      <div v-if="loading" class="loading">
        <div class="spinner"></div>
        <p>加载中...</p>
      </div>

      <!-- 留言列表 -->
      <div v-else-if="messages.length > 0" class="messages-list">
        <div 
          v-for="message in messages" 
          :key="message.id" 
          class="message-card"
          :class="{ 'pinned': message.is_pinned }"
        >
          <!-- 置顶标识 -->
          <div v-if="message.is_pinned" class="pin-badge">
            📌 置顶
          </div>

          <!-- 用户信息 -->
          <div class="message-header">
            <div class="user-info">
              <UserAvatar 
                :username="message.user.username"
                :avatar-url="message.user.avatar_url"
                size="medium"
              />
              <div class="user-details">
                <h3 class="username">{{ message.user.username }}</h3>
                <p class="timestamp">{{ formatTime(message.created_at) }}</p>
              </div>
            </div>
            
            <!-- 操作按钮 -->
            <div class="message-actions">
              <button 
                v-if="canManageMessage(message)" 
                @click="togglePin(message)"
                class="action-btn pin-btn"
                :title="message.is_pinned ? '取消置顶' : '置顶留言'"
              >
                📌
              </button>
              <button 
                v-if="canDeleteMessage(message)" 
                @click="deleteMessage(message.id)"
                class="action-btn delete-btn"
                title="删除留言"
              >
                🗑️
              </button>
            </div>
          </div>

          <!-- 留言内容 -->
          <div class="message-content">
            <p class="content-text">{{ message.content }}</p>
            
            <!-- 图片展示 -->
            <div v-if="message.images && message.images.length > 0" class="images-grid">
              <div 
                v-for="image in message.images" 
                :key="image.id"
                class="image-item"
                @click="previewImage(image.url)"
              >
                <img :src="image.url" :alt="image.name" />
              </div>
            </div>
          </div>

          <!-- 互动区域 -->
          <div class="message-footer">
            <div class="interactions">
              <button 
                @click="toggleLike(message)"
                class="interaction-btn like-btn"
                :class="{ 'liked': message.is_liked }"
                :disabled="!isLoggedIn"
              >
                <span class="icon">{{ message.is_liked ? '❤️' : '🤍' }}</span>
                <span class="count">{{ message.like_count }}</span>
              </button>
              
              <button 
                @click="goToDetail(message.id)"
                class="interaction-btn comment-btn"
              >
                <span class="icon">💬</span>
                <span class="count">{{ message.comment_count }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 空状态 -->
      <div v-else class="empty-state">
        <div class="empty-icon">📝</div>
        <h3>还没有留言</h3>
        <p>成为第一个分享想法的人吧！</p>
        <button 
          v-if="isLoggedIn" 
          @click="goToPublish" 
          class="empty-action-btn"
        >
          发布第一条留言
        </button>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="pagination.pages > 1" class="pagination">
      <button 
        @click="loadPage(pagination.page - 1)"
        :disabled="!pagination.has_prev"
        class="page-btn"
      >
        上一页
      </button>
      
      <span class="page-info">
        第 {{ pagination.page }} 页，共 {{ pagination.pages }} 页
      </span>
      
      <button 
        @click="loadPage(pagination.page + 1)"
        :disabled="!pagination.has_next"
        class="page-btn"
      >
        下一页
      </button>
    </div>

    <!-- 图片预览模态框 -->
    <div v-if="previewImageUrl" class="image-preview-modal" @click="closeImagePreview">
      <div class="preview-content" @click.stop>
        <img :src="previewImageUrl" alt="预览图片" />
        <button @click="closeImagePreview" class="close-btn">×</button>
      </div>
    </div>
  </div>
</template>

<script>
import api from '../axios.js'
import UserAvatar from './UserAvatar.vue'

export default {
  name: 'MessageWall',
  components: {
    UserAvatar
  },
  data() {
    return {
      messages: [],
      loading: false,
      isLoggedIn: false,
      currentUser: null,
      pagination: {
        page: 1,
        pages: 1,
        total: 0,
        has_next: false,
        has_prev: false
      },
      previewImageUrl: null
    }
  },
  async mounted() {
    await this.checkLoginStatus()
    await this.loadMessages()
  },
  methods: {
    // 检查登录状态
    async checkLoginStatus() {
      try {
        const response = await api.get('/login-status')
        this.isLoggedIn = response.data.is_logged_in
        this.currentUser = response.data.user
      } catch (error) {
        console.error('检查登录状态失败:', error)
        this.isLoggedIn = false
        this.currentUser = null
      }
    },

    // 加载留言列表
    async loadMessages(page = 1) {
      this.loading = true
      try {
        const response = await api.get('/messages', {
          params: {
            page: page,
            per_page: 10
          }
        })
        
        this.messages = response.data.messages
        this.pagination = response.data.pagination
        
        // 检查当前用户对每条留言的点赞状态
        if (this.isLoggedIn) {
          await this.checkLikeStatus()
        }
      } catch (error) {
        console.error('加载留言失败:', error)
        this.$toast?.error('加载留言失败')
      } finally {
        this.loading = false
      }
    },

    // 检查点赞状态
    async checkLikeStatus() {
      for (let message of this.messages) {
        try {
          const response = await api.get(`/messages/${message.id}`)
          message.is_liked = response.data.is_liked
        } catch (error) {
          console.error(`检查留言 ${message.id} 点赞状态失败:`, error)
        }
      }
    },

    // 分页加载
    async loadPage(page) {
      if (page >= 1 && page <= this.pagination.pages) {
        await this.loadMessages(page)
      }
    },

    // 跳转到发布页面
    goToPublish() {
      if (this.isLoggedIn) {
        this.$router.push('/messages/publish')
      }
    },

    // 跳转到详情页面
    goToDetail(messageId) {
      this.$router.push(`/messages/${messageId}`)
    },

    // 切换点赞
    async toggleLike(message) {
      if (!this.isLoggedIn) {
        this.$toast?.warning('请先登录')
        return
      }

      try {
        const response = await api.post(`/messages/${message.id}/like`)
        message.is_liked = response.data.is_liked
        message.like_count = response.data.like_count
        this.$toast?.success(response.data.message)
      } catch (error) {
        console.error('点赞操作失败:', error)
        this.$toast?.error('操作失败')
      }
    },

    // 置顶/取消置顶
    async togglePin(message) {
      try {
        const response = await api.post(`/messages/${message.id}/pin`)
        message.is_pinned = response.data.is_pinned
        this.$toast?.success(response.data.message)
        // 重新加载列表以更新排序
        await this.loadMessages(this.pagination.page)
      } catch (error) {
        console.error('置顶操作失败:', error)
        this.$toast?.error('操作失败')
      }
    },

    // 删除留言
    async deleteMessage(messageId) {
      if (!confirm('确定要删除这条留言吗？')) {
        return
      }

      try {
        await api.delete(`/messages/${messageId}`)
        this.$toast?.success('留言删除成功')
        // 重新加载当前页
        await this.loadMessages(this.pagination.page)
      } catch (error) {
        console.error('删除留言失败:', error)
        this.$toast?.error('删除失败')
      }
    },

    // 检查是否可以管理留言（置顶）
    canManageMessage(message) {
      return this.currentUser && this.currentUser.role === 'admin'
    },

    // 检查是否可以删除留言
    canDeleteMessage(message) {
      if (!this.currentUser) return false
      return this.currentUser.role === 'admin' || this.currentUser.id === message.user.id
    },

    // 格式化时间
    formatTime(timeString) {
      const date = new Date(timeString)
      const now = new Date()
      const diff = now - date
      
      if (diff < 60000) { // 1分钟内
        return '刚刚'
      } else if (diff < 3600000) { // 1小时内
        return `${Math.floor(diff / 60000)}分钟前`
      } else if (diff < 86400000) { // 1天内
        return `${Math.floor(diff / 3600000)}小时前`
      } else {
        return date.toLocaleDateString('zh-CN', {
          year: 'numeric',
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        })
      }
    },

    // 预览图片
    previewImage(url) {
      this.previewImageUrl = url
    },

    // 关闭图片预览
    closeImagePreview() {
      this.previewImageUrl = null
    }
  }
}
</script>

<style scoped>
.message-wall {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  background: #f8fafc;
  min-height: 100vh;
}

.header {
  text-align: center;
  margin-bottom: 30px;
}

.title {
  font-size: 2.5rem;
  font-weight: bold;
  color: #1a202c;
  margin-bottom: 8px;
}

.subtitle {
  font-size: 1.1rem;
  color: #718096;
  margin: 0;
}

.publish-section {
  text-align: center;
  margin-bottom: 30px;
}

.publish-btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 25px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.publish-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(102, 126, 234, 0.3);
}

.publish-btn:disabled {
  background: #cbd5e0;
  cursor: not-allowed;
}

.login-hint {
  margin-top: 10px;
}

.login-link {
  color: #667eea;
  text-decoration: none;
  font-weight: 500;
}

.login-link:hover {
  text-decoration: underline;
}

.messages-container {
  margin-bottom: 30px;
}

.loading {
  text-align: center;
  padding: 40px;
}

.spinner {
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

.messages-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.message-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  transition: all 0.3s ease;
  position: relative;
}

.message-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}

.message-card.pinned {
  border-left: 4px solid #f6ad55;
  background: linear-gradient(135deg, #fff5f5 0%, #ffffff 100%);
}

.pin-badge {
  position: absolute;
  top: -8px;
  right: 20px;
  background: #f6ad55;
  color: white;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 0.8rem;
  font-weight: 600;
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

.avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  overflow: hidden;
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.default-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 1.2rem;
}

.username {
  font-size: 1.1rem;
  font-weight: 600;
  color: #2d3748;
  margin: 0 0 4px 0;
}

.timestamp {
  font-size: 0.9rem;
  color: #718096;
  margin: 0;
}

.message-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  background: none;
  border: none;
  padding: 8px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 1.1rem;
  transition: all 0.2s ease;
}

.action-btn:hover {
  background: #f7fafc;
}

.delete-btn:hover {
  background: #fed7d7;
}

.content-text {
  font-size: 1rem;
  line-height: 1.6;
  color: #2d3748;
  margin: 0 0 16px 0;
  white-space: pre-wrap;
}

.images-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
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
  height: 150px;
  object-fit: cover;
}

.message-footer {
  border-top: 1px solid #e2e8f0;
  padding-top: 16px;
}

.interactions {
  display: flex;
  gap: 16px;
}

.interaction-btn {
  background: none;
  border: none;
  padding: 8px 12px;
  border-radius: 20px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.9rem;
  color: #718096;
  transition: all 0.2s ease;
}

.interaction-btn:hover:not(:disabled) {
  background: #f7fafc;
  color: #4a5568;
}

.interaction-btn:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.like-btn.liked {
  color: #e53e3e;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #718096;
}

.empty-icon {
  font-size: 4rem;
  margin-bottom: 16px;
}

.empty-state h3 {
  font-size: 1.5rem;
  margin-bottom: 8px;
  color: #4a5568;
}

.empty-action-btn {
  background: #667eea;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 20px;
  cursor: pointer;
  margin-top: 16px;
  transition: all 0.2s ease;
}

.empty-action-btn:hover {
  background: #5a67d8;
}

.pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 16px;
  margin-top: 30px;
}

.page-btn {
  background: white;
  border: 1px solid #e2e8f0;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.page-btn:hover:not(:disabled) {
  background: #f7fafc;
  border-color: #cbd5e0;
}

.page-btn:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.page-info {
  color: #718096;
  font-size: 0.9rem;
}

.image-preview-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.preview-content {
  position: relative;
  max-width: 90vw;
  max-height: 90vh;
}

.preview-content img {
  max-width: 100%;
  max-height: 100%;
  border-radius: 8px;
}

.close-btn {
  position: absolute;
  top: -40px;
  right: 0;
  background: rgba(255, 255, 255, 0.9);
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

@media (max-width: 768px) {
  .message-wall {
    padding: 16px;
  }
  
  .title {
    font-size: 2rem;
  }
  
  .message-card {
    padding: 16px;
  }
  
  .images-grid {
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  }
  
  .image-item img {
    height: 120px;
  }
}
</style>