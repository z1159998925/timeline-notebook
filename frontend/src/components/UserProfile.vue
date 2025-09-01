<template>
  <div class="profile-container">
    <div class="profile-header">
      <div class="avatar-section">
        <UserAvatar 
          :avatar-url="user.avatar_url" 
          :username="user.username"
          size="large"
          class="avatar"
        />
        <button @click="showEditProfile = true" class="edit-btn">
          编辑资料
        </button>
      </div>
      
      <div class="user-info">
        <h1>{{ user.username }}</h1>
        <p class="bio">{{ user.bio || '这个人很懒，什么都没有留下...' }}</p>
        <p class="join-date">加入时间：{{ formatDate(user.created_at) }}</p>
      </div>
    </div>
    
    <div class="profile-stats">
      <div class="stat-item">
        <span class="stat-number">{{ stats.messageCount }}</span>
        <span class="stat-label">留言</span>
      </div>
      <div class="stat-item">
        <span class="stat-number">{{ stats.likeCount }}</span>
        <span class="stat-label">获赞</span>
      </div>
      <div class="stat-item">
        <span class="stat-number">{{ stats.commentCount }}</span>
        <span class="stat-label">评论</span>
      </div>
    </div>
    
    <div class="profile-tabs">
      <button 
        v-for="tab in tabs" 
        :key="tab.key"
        @click="activeTab = tab.key"
        :class="['tab-btn', { active: activeTab === tab.key }]"
      >
        {{ tab.label }}
      </button>
    </div>
    
    <div class="tab-content">
      <!-- 我的留言 -->
      <div v-if="activeTab === 'messages'" class="messages-list">
        <div v-if="userMessages.length === 0" class="empty-state">
          <p>还没有发布任何留言</p>
          <router-link to="/messages/publish" class="publish-btn">
            发布第一条留言
          </router-link>
        </div>
        <div v-else>
          <div 
            v-for="message in userMessages" 
            :key="message.id"
            class="message-item"
          >
            <div class="message-content">
              <p>{{ message.content }}</p>
              <div class="message-meta">
                <span>{{ formatDate(message.created_at) }}</span>
                <span>{{ message.like_count }} 赞</span>
                <span>{{ message.comment_count }} 评论</span>
              </div>
            </div>
            <div class="message-actions">
              <router-link :to="`/messages/${message.id}`" class="view-btn">
                查看
              </router-link>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 我的评论 -->
      <div v-if="activeTab === 'comments'" class="comments-list">
        <div v-if="userComments.length === 0" class="empty-state">
          <p>还没有发表任何评论</p>
        </div>
        <div v-else>
          <div 
            v-for="comment in userComments" 
            :key="comment.id"
            class="comment-item"
          >
            <div class="comment-content">
              <p>{{ comment.content }}</p>
              <div class="comment-meta">
                <span>{{ formatDate(comment.created_at) }}</span>
                <router-link :to="`/messages/${comment.message_id}`">
                  查看原留言
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 编辑资料弹窗 -->
    <div v-if="showEditProfile" class="modal-overlay" @click="showEditProfile = false">
      <div class="modal-content" @click.stop>
        <UserEdit 
          :user="user" 
          @close="showEditProfile = false"
          @updated="handleUserUpdated"
        />
      </div>
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api/config.js'
import UserEdit from './UserEdit.vue'
import UserAvatar from './UserAvatar.vue'

export default {
  name: 'UserProfile',
  components: {
    UserEdit,
    UserAvatar
  },
  setup() {
    const router = useRouter()
    
    const user = ref({})
    const stats = ref({
      messageCount: 0,
      likeCount: 0,
      commentCount: 0
    })
    const userMessages = ref([])
    const userComments = ref([])
    const activeTab = ref('messages')
    const showEditProfile = ref(false)
    const loading = ref(true)
    
    const tabs = [
      { key: 'messages', label: '我的留言' },
      { key: 'comments', label: '我的评论' }
    ]
    
    const formatDate = (dateString) => {
      if (!dateString) {
        return '未知时间'
      }
      
      const date = new Date(dateString)
      if (isNaN(date.getTime())) {
        return '未知时间'
      }
      
      return date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
      })
    }
    
    const loadUserData = async () => {
      try {
        const response = await api.get('/login-status')
        if (response.data.is_logged_in && response.data.user) {
          user.value = response.data.user
          return true
        }
        return false
      } catch (error) {
        console.error('获取用户数据失败:', error)
        return false
      }
    }
    
    const fetchUserStats = async () => {
      try {
        const response = await api.get('/user/stats')
        // 映射后端字段名到前端字段名
        stats.value = {
          messageCount: response.data.message_count || 0,
          likeCount: response.data.like_count || 0,
          commentCount: response.data.comment_count || 0
        }
      } catch (error) {
        console.error('获取用户统计失败:', error)
      }
    }
    
    const fetchUserMessages = async () => {
      try {
        const response = await api.get('/user/messages')
        userMessages.value = response.data.messages || []
      } catch (error) {
        console.error('获取用户留言失败:', error)
        userMessages.value = []
      }
    }
    
    const fetchUserComments = async () => {
      try {
        const response = await api.get('/user/comments')
        userComments.value = response.data.comments || []
      } catch (error) {
        console.error('获取用户评论失败:', error)
        userComments.value = []
      }
    }
    
    const handleUserUpdated = (updatedUser) => {
      user.value = { ...user.value, ...updatedUser }
      showEditProfile.value = false
    }
    
    onMounted(async () => {
      const hasUserData = await loadUserData()
      if (hasUserData) {
        await Promise.all([
          fetchUserStats(),
          fetchUserMessages(),
          fetchUserComments()
        ])
      }
      loading.value = false
    })
    
    return {
      user,
      stats,
      userMessages,
      userComments,
      activeTab,
      showEditProfile,
      loading,
      tabs,
      formatDate,
      handleUserUpdated
    }
  }
}
</script>

<style scoped>
.profile-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.profile-header {
  display: flex;
  gap: 20px;
  margin-bottom: 30px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.avatar-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}

.avatar {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  object-fit: cover;
  border: 3px solid #e9ecef;
}

.edit-btn {
  padding: 8px 16px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: background-color 0.3s;
}

.edit-btn:hover {
  background: #0056b3;
}

.user-info {
  flex: 1;
}

.user-info h1 {
  margin: 0 0 10px 0;
  color: #333;
  font-size: 24px;
}

.bio {
  color: #666;
  margin: 10px 0;
  line-height: 1.5;
}

.join-date {
  color: #999;
  font-size: 14px;
  margin: 0;
}

.profile-stats {
  display: flex;
  gap: 20px;
  margin-bottom: 30px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.stat-item {
  flex: 1;
  text-align: center;
}

.stat-number {
  display: block;
  font-size: 24px;
  font-weight: bold;
  color: #007bff;
  margin-bottom: 5px;
}

.stat-label {
  color: #666;
  font-size: 14px;
}

.profile-tabs {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid #e9ecef;
}

.tab-btn {
  padding: 12px 24px;
  background: none;
  border: none;
  cursor: pointer;
  color: #666;
  font-size: 16px;
  border-bottom: 2px solid transparent;
  transition: all 0.3s;
}

.tab-btn.active {
  color: #007bff;
  border-bottom-color: #007bff;
}

.tab-btn:hover {
  color: #007bff;
}

.tab-content {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  min-height: 300px;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #666;
}

.publish-btn {
  display: inline-block;
  margin-top: 20px;
  padding: 10px 20px;
  background: #007bff;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  transition: background-color 0.3s;
}

.publish-btn:hover {
  background: #0056b3;
}

.message-item,
.comment-item {
  padding: 20px;
  border-bottom: 1px solid #e9ecef;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.message-item:last-child,
.comment-item:last-child {
  border-bottom: none;
}

.message-content,
.comment-content {
  flex: 1;
}

.message-content p,
.comment-content p {
  margin: 0 0 10px 0;
  line-height: 1.5;
}

.message-meta,
.comment-meta {
  display: flex;
  gap: 15px;
  font-size: 14px;
  color: #666;
}

.message-meta a,
.comment-meta a {
  color: #007bff;
  text-decoration: none;
}

.message-meta a:hover,
.comment-meta a:hover {
  text-decoration: underline;
}

.message-actions {
  margin-left: 20px;
}

.view-btn {
  padding: 6px 12px;
  background: #f8f9fa;
  color: #007bff;
  text-decoration: none;
  border-radius: 4px;
  font-size: 14px;
  transition: background-color 0.3s;
}

.view-btn:hover {
  background: #e9ecef;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 8px;
  max-width: 500px;
  width: 90%;
  max-height: 80vh;
  overflow-y: auto;
}

@media (max-width: 768px) {
  .profile-header {
    flex-direction: column;
    text-align: center;
  }
  
  .profile-stats {
    flex-direction: column;
    gap: 10px;
  }
  
  .message-item,
  .comment-item {
    flex-direction: column;
    gap: 10px;
  }
  
  .message-actions {
    margin-left: 0;
    align-self: flex-start;
  }
}
</style>