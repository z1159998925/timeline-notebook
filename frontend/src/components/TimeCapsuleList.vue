<template>
  <div class="time-capsule-container">
    <div class="header-section">
      <h2>⏰ 时间胶囊</h2>
      <p class="subtitle">将珍贵的回忆封存，等待未来的自己开启</p>
      <button @click="showCreateForm = true" class="create-btn">
        ✨ 创建时间胶囊
      </button>
    </div>

    <!-- 创建胶囊表单 -->
    <div v-if="showCreateForm" class="create-form-overlay" @click="closeCreateForm">
      <div class="create-form" @click.stop>
        <h3>创建时间胶囊</h3>
        <form @submit.prevent="createCapsule">
          <div class="form-group">
            <label>标题 *</label>
            <input 
              v-model="newCapsule.title" 
              type="text" 
              placeholder="给你的时间胶囊起个名字..."
              required
            >
          </div>
          
          <div class="form-group">
            <label>内容</label>
            <textarea 
              v-model="newCapsule.content" 
              placeholder="写下你想对未来说的话..."
              rows="4"
            ></textarea>
          </div>
          
          <div class="form-group">
            <label>解锁问题 *</label>
            <input 
              v-model="newCapsule.question" 
              type="text" 
              placeholder="例如：我最喜欢的颜色是什么？"
              required
            >
          </div>
          
          <div class="form-group">
            <label>问题答案 *</label>
            <input 
              v-model="newCapsule.answer" 
              type="text" 
              placeholder="输入问题的答案"
              required
            >
          </div>
          
          <div class="form-group">
            <label>解锁时间 *</label>
            <input 
              v-model="newCapsule.unlockDate" 
              type="datetime-local" 
              :min="minDateTime"
              required
            >
          </div>
          
          <div class="form-group">
            <label>上传文件（可选）</label>
            <input 
              @change="handleFileSelect" 
              type="file" 
              accept="image/*,video/*,.pdf,.txt"
            >
            <small>支持图片、视频、PDF、文本文件，最大16MB</small>
          </div>
          
          <div class="form-actions">
            <button type="button" @click="closeCreateForm" class="cancel-btn">取消</button>
            <button type="submit" :disabled="isCreating" class="submit-btn">
              {{ isCreating ? '创建中...' : '创建胶囊' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- 胶囊列表 -->
    <div class="capsules-grid">
      <!-- 加载状态 -->
      <div v-if="loading" class="loading-state">
        <div class="loading-spinner"></div>
        <p>正在加载时间胶囊...</p>
      </div>
      
      <!-- 错误状态 -->
      <div v-else-if="error" class="error-state">
        <div class="error-icon">⚠️</div>
        <h3>加载失败</h3>
        <p>{{ error }}</p>
        <div class="error-actions">
          <button @click="retryLoadCapsules" class="retry-btn">
            🔄 重试 {{ retryCount > 0 ? `(${retryCount})` : '' }}
          </button>
          <button @click="$router.push('/admin')" class="admin-btn">
            🔧 管理员登录
          </button>
        </div>
      </div>
      
      <!-- 空数据状态 -->
      <div v-else-if="capsules.length === 0" class="empty-state">
        <div class="empty-icon">📦</div>
        <p>还没有时间胶囊</p>
        <p class="empty-subtitle">创建你的第一个时间胶囊，封存珍贵回忆</p>
      </div>
      
      <div 
        v-for="capsule in capsules" 
        :key="capsule.id" 
        class="capsule-card"
        :class="{ 'unlockable': capsule.can_unlock && !capsule.is_unlocked }"
      >
        <div class="capsule-header">
          <h3>{{ capsule.title }}</h3>
          <div class="capsule-status">
            <span v-if="capsule.is_unlocked" class="status-unlocked">已解锁</span>
            <span v-else-if="capsule.can_unlock" class="status-ready">可解锁</span>
            <span v-else class="status-locked">锁定中</span>
          </div>
        </div>
        
        <div class="capsule-info">
          <p v-if="capsule.created_at"><strong>创建时间：</strong>{{ formatDate(capsule.created_at) }}</p>
          <p v-if="capsule.unlock_date"><strong>解锁时间：</strong>{{ formatDate(capsule.unlock_date) }}</p>
          <p class="capsule-question" v-if="capsule.can_unlock && !capsule.is_unlocked && capsule.question">
            <strong>解锁问题：</strong>{{ capsule.question }}
          </p>
          <p v-if="capsule.has_media" class="media-indicator">
            📎 包含附件
          </p>
        </div>
        
        <!-- 倒计时 -->
        <div v-if="!capsule.is_unlocked && !capsule.can_unlock && capsule.remaining_time != null && capsule.remaining_time > 0" class="countdown">
          <div class="countdown-title">距离解锁还有：</div>
          <div class="countdown-time">{{ formatCountdown(capsule.remaining_time) }}</div>
        </div>
        
        <!-- 解锁按钮 -->
        <div class="capsule-actions">
          <button 
            v-if="capsule.can_unlock && !capsule.is_unlocked"
            @click="showUnlockDialog(capsule)"
            class="unlock-btn"
          >
            🔓 解锁胶囊
          </button>
          <button 
            v-if="capsule.is_unlocked"
            @click="viewCapsule(capsule.id)"
            class="view-btn"
          >
            👁️ 查看内容
          </button>
          <span v-if="!capsule.can_unlock && !capsule.is_unlocked" class="locked-text">
            ⏳ 等待解锁时间
          </span>
        </div>
      </div>
    </div>

    <!-- 解锁对话框 -->
    <div v-if="showUnlockForm" class="unlock-overlay" @click="closeUnlockForm">
      <div class="unlock-form" @click.stop>
        <h3>解锁时间胶囊</h3>
        <p>{{ selectedCapsule?.title }}</p>
        <div class="unlock-question">
          <p><strong>问题：</strong>{{ selectedCapsule?.question }}</p>
        </div>
        <div class="form-group">
          <label>请输入答案：</label>
          <input 
            v-model="unlockAnswer" 
            type="text" 
            placeholder="输入问题的答案"
            @keyup.enter="unlockCapsule"
          >
        </div>
        <div class="form-actions">
          <button @click="closeUnlockForm" class="cancel-btn">取消</button>
          <button @click="unlockCapsule" :disabled="!unlockAnswer || isUnlocking" class="unlock-btn">
            {{ isUnlocking ? '解锁中...' : '解锁' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 查看胶囊内容对话框 -->
    <div v-if="showViewDialog" class="view-overlay" @click="closeViewDialog">
      <div class="view-dialog" @click.stop>
        <div class="view-header">
          <h3>{{ viewingCapsule?.title }}</h3>
          <button @click="closeViewDialog" class="close-btn">×</button>
        </div>
        <div class="view-content">
          <div class="capsule-meta">
            <p><strong>创建时间：</strong>{{ formatDate(viewingCapsule?.created_at) }}</p>
            <p><strong>解锁时间：</strong>{{ formatDate(viewingCapsule?.unlock_date) }}</p>
          </div>
          
          <div v-if="viewingCapsule?.content" class="capsule-text">
            <h4>内容：</h4>
            <p>{{ viewingCapsule.content }}</p>
          </div>
          
          <div v-if="viewingCapsule?.media_url" class="capsule-media">
            <h4>附件：</h4>
            <img 
              v-if="viewingCapsule.media_type === 'image'" 
              :src="getMediaUrl(viewingCapsule.media_url)" 
              alt="胶囊图片"
              class="media-image"
            >
            <video 
              v-else-if="viewingCapsule.media_type === 'video'" 
              :src="getMediaUrl(viewingCapsule.media_url)" 
              controls
              class="media-video"
            ></video>
            <a 
              v-else 
              :href="getMediaUrl(viewingCapsule.media_url)" 
              target="_blank"
              class="media-file"
            >
              📎 下载附件
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, onMounted, onUnmounted } from 'vue'
import api from '../axios.js'

export default {
  name: 'TimeCapsuleList',
  setup() {
    const capsules = ref([])
    const showCreateForm = ref(false)
    const showUnlockForm = ref(false)
    const showViewDialog = ref(false)
    const selectedCapsule = ref(null)
    const viewingCapsule = ref(null)
    const unlockAnswer = ref('')
    const isCreating = ref(false)
    const isUnlocking = ref(false)
    const selectedFile = ref(null)
    const countdownInterval = ref(null)
    const loading = ref(false)
    const error = ref('')
    const retryCount = ref(0)

    const newCapsule = ref({
      title: '',
      content: '',
      question: '',
      answer: '',
      unlockDate: ''
    })

    // 获取最小日期时间（当前时间）
    const minDateTime = ref('')
    const updateMinDateTime = () => {
      const now = new Date()
      now.setMinutes(now.getMinutes() + 1) // 至少1分钟后
      minDateTime.value = now.toISOString().slice(0, 16)
    }

    // 加载胶囊列表
    const loadCapsules = async () => {
      loading.value = true
      error.value = ''
      try {
        const response = await api.get('/time-capsules')
        capsules.value = response.data
        retryCount.value = 0
      } catch (err) {
        console.error('加载时间胶囊失败:', err)
        if (err.response) {
          if (err.response.status === 404) {
            error.value = '时间胶囊服务暂时不可用，请稍后重试'
          } else if (err.response.status >= 500) {
            error.value = '服务器错误，请稍后重试'
          } else {
            error.value = '加载时间胶囊失败，请检查网络连接'
          }
        } else if (err.request) {
          error.value = '网络连接失败，请检查网络设置后重试'
        } else {
          error.value = '加载时间胶囊时发生未知错误'
        }
      } finally {
        loading.value = false
      }
    }

    // 重试加载数据
    const retryLoadCapsules = () => {
      retryCount.value++
      loadCapsules()
    }

    // 创建胶囊
    const createCapsule = async () => {
      isCreating.value = true
      try {
        const formData = new FormData()
        formData.append('title', newCapsule.value.title)
        formData.append('content', newCapsule.value.content)
        formData.append('question', newCapsule.value.question)
        formData.append('answer', newCapsule.value.answer)
        formData.append('unlock_date', newCapsule.value.unlockDate)
        
        if (selectedFile.value) {
          formData.append('media', selectedFile.value)
        }

        await api.post('/time-capsules', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })

        alert('时间胶囊创建成功！')
        closeCreateForm()
        loadCapsules()
      } catch (error) {
        alert(error.response?.data?.message || '创建失败')
      } finally {
        isCreating.value = false
      }
    }

    // 解锁胶囊
    const unlockCapsule = async () => {
      if (!selectedCapsule.value || !unlockAnswer.value) return
      
      isUnlocking.value = true
      try {
        const response = await api.post(`/time-capsules/${selectedCapsule.value.id}/unlock`, {
          answer: unlockAnswer.value
        })

        alert('解锁成功！')
        viewingCapsule.value = response.data.capsule
        closeUnlockForm()
        showViewDialog.value = true
        loadCapsules()
      } catch (error) {
        alert(error.response?.data?.message || '解锁失败')
      } finally {
        isUnlocking.value = false
      }
    }

    // 查看胶囊
    const viewCapsule = async (capsuleId) => {
      try {
        const response = await api.get(`/time-capsules/${capsuleId}`)
        viewingCapsule.value = response.data
        showViewDialog.value = true
      } catch (error) {
        alert(error.response?.data?.message || '查看失败')
      }
    }

    // 文件选择
    const handleFileSelect = (event) => {
      const file = event.target.files[0]
      if (file) {
        // 检查文件大小（16MB = 16 * 1024 * 1024 bytes）
        const maxSize = 16 * 1024 * 1024
        if (file.size > maxSize) {
          alert(`文件大小不能超过 16MB，当前文件大小为 ${(file.size / 1024 / 1024).toFixed(2)}MB`)
          event.target.value = '' // 清空文件选择
          selectedFile.value = null
          return
        }
        selectedFile.value = file
      }
    }

    // 显示解锁对话框
    const showUnlockDialog = (capsule) => {
      selectedCapsule.value = capsule
      unlockAnswer.value = ''
      showUnlockForm.value = true
    }

    // 关闭表单
    const closeCreateForm = () => {
      showCreateForm.value = false
      newCapsule.value = {
        title: '',
        content: '',
        question: '',
        answer: '',
        unlockDate: ''
      }
      selectedFile.value = null
    }

    const closeUnlockForm = () => {
      showUnlockForm.value = false
      selectedCapsule.value = null
      unlockAnswer.value = ''
    }

    const closeViewDialog = () => {
      showViewDialog.value = false
      viewingCapsule.value = null
    }

    // 格式化日期
    const formatDate = (dateString) => {
      if (!dateString) {
        return '未知时间'
      }
      
      const date = new Date(dateString)
      if (isNaN(date.getTime())) {
        return '无效日期'
      }
      
      return date.toLocaleString('zh-CN')
    }

    // 格式化倒计时
    const formatCountdown = (seconds) => {
      // 检查参数是否为有效数字
      if (typeof seconds !== 'number' || isNaN(seconds)) {
        return '计算中...'
      }
      
      if (seconds <= 0) return '已可解锁'
      
      const days = Math.floor(seconds / 86400)
      const hours = Math.floor((seconds % 86400) / 3600)
      const minutes = Math.floor((seconds % 3600) / 60)
      const secs = Math.floor(seconds % 60)

      if (days > 0) {
        return `${days}天 ${hours}小时 ${minutes}分钟`
      } else if (hours > 0) {
        return `${hours}小时 ${minutes}分钟 ${secs}秒`
      } else if (minutes > 0) {
        return `${minutes}分钟 ${secs}秒`
      } else {
        return `${secs}秒`
      }
    }

    // 获取媒体文件URL，根据环境动态生成
    const getMediaUrl = (mediaUrl) => {
      if (!mediaUrl) return ''
      
      // 如果是开发环境，使用localhost
      if (import.meta.env.MODE === 'development') {
        return `http://localhost:5000${mediaUrl}`
      }
      
      // 生产环境，使用相对路径或当前域名
      if (mediaUrl.startsWith('/')) {
        return mediaUrl // 相对路径，浏览器会自动使用当前域名
      }
      
      return mediaUrl
    }

    // 启动倒计时更新
    const startCountdown = () => {
      countdownInterval.value = setInterval(() => {
        loadCapsules() // 重新加载数据以更新倒计时
      }, 1000)
    }

    onMounted(() => {
      updateMinDateTime()
      loadCapsules()
      startCountdown()
    })

    onUnmounted(() => {
      if (countdownInterval.value) {
        clearInterval(countdownInterval.value)
      }
    })

    return {
      capsules,
      showCreateForm,
      showUnlockForm,
      showViewDialog,
      selectedCapsule,
      viewingCapsule,
      unlockAnswer,
      isCreating,
      isUnlocking,
      newCapsule,
      minDateTime,
      loading,
      error,
      retryCount,
      createCapsule,
      unlockCapsule,
      viewCapsule,
      handleFileSelect,
      showUnlockDialog,
      closeCreateForm,
      closeUnlockForm,
      closeViewDialog,
      formatDate,
      formatCountdown,
      getMediaUrl,
      retryLoadCapsules
    }
  }
}
</script>

<style scoped>
.time-capsule-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header-section {
  text-align: center;
  margin-bottom: 40px;
}

.header-section h2 {
  font-size: 2.5rem;
  margin-bottom: 10px;
  color: var(--text-color);
}

.subtitle {
  color: var(--text-color);
  opacity: 0.8;
  margin-bottom: 20px;
}

.create-btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 25px;
  font-size: 1rem;
  cursor: pointer;
  transition: transform 0.2s;
}

.create-btn:hover {
  transform: translateY(-2px);
}

/* 表单样式 */
.create-form-overlay, .unlock-overlay, .view-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.create-form, .unlock-form {
  background: var(--card-bg);
  padding: 30px;
  border-radius: 15px;
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
}

.view-dialog {
  background: var(--card-bg);
  padding: 30px;
  border-radius: 15px;
  width: 90%;
  max-width: 700px;
  max-height: 90vh;
  overflow-y: auto;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 15px;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--text-color);
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: bold;
  color: var(--text-color);
}

.form-group input,
.form-group textarea {
  width: 100%;
  padding: 10px;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-color);
  color: var(--text-color);
  box-sizing: border-box;
}

.form-group small {
  color: var(--text-color);
  opacity: 0.7;
  font-size: 0.9rem;
}

.form-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
}

.cancel-btn, .submit-btn, .unlock-btn {
  padding: 10px 20px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 1rem;
}

.cancel-btn {
  background: var(--border-color);
  color: var(--text-color);
}

.submit-btn, .unlock-btn {
  background: var(--button-bg);
  color: white;
}

.submit-btn:disabled, .unlock-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* 胶囊网格 */
.capsules-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 20px;
}

/* 加载状态 */
.loading-state {
  grid-column: 1 / -1;
  text-align: center;
  padding: 60px 20px;
  color: var(--text-color);
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 4px solid var(--border-color);
  border-top: 4px solid var(--button-bg);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 20px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

/* 错误状态 */
.error-state {
  grid-column: 1 / -1;
  text-align: center;
  padding: 60px 20px;
  color: var(--text-color);
}

.error-icon {
  font-size: 4rem;
  margin-bottom: 20px;
}

.error-state h3 {
  color: #e74c3c;
  margin-bottom: 15px;
}

.error-state p {
  margin-bottom: 25px;
  opacity: 0.8;
}

.error-actions {
  display: flex;
  gap: 15px;
  justify-content: center;
  flex-wrap: wrap;
}

.retry-btn, .admin-btn {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 1rem;
  transition: transform 0.2s, box-shadow 0.2s;
}

.retry-btn {
  background: var(--button-bg);
  color: white;
}

.admin-btn {
  background: #6c757d;
  color: white;
}

.retry-btn:hover, .admin-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.empty-state {
  grid-column: 1 / -1;
  text-align: center;
  padding: 60px 20px;
  color: var(--text-color);
  opacity: 0.6;
}

.empty-icon {
  font-size: 4rem;
  margin-bottom: 20px;
}

.empty-subtitle {
  font-size: 0.9rem;
  opacity: 0.8;
}

/* 胶囊卡片 */
.capsule-card {
  background: var(--card-bg);
  border: 1px solid var(--border-color);
  border-radius: 15px;
  padding: 20px;
  transition: transform 0.2s, box-shadow 0.2s;
}

.capsule-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.capsule-card.unlockable {
  border-color: #4CAF50;
  box-shadow: 0 0 10px rgba(76, 175, 80, 0.3);
}

.capsule-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.capsule-header h3 {
  margin: 0;
  color: var(--text-color);
}

.capsule-status {
  font-size: 0.8rem;
  padding: 4px 8px;
  border-radius: 12px;
  font-weight: bold;
}

.status-unlocked {
  background: #4CAF50;
  color: white;
}

.status-ready {
  background: #FF9800;
  color: white;
}

.status-locked {
  background: var(--border-color);
  color: var(--text-color);
}

.capsule-info {
  margin-bottom: 15px;
  color: var(--text-color);
  opacity: 0.8;
}

.capsule-info p {
  margin: 5px 0;
  font-size: 0.9rem;
}

.media-indicator {
  color: var(--link-color);
  font-weight: bold;
}

.countdown {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 15px;
  border-radius: 10px;
  text-align: center;
  margin-bottom: 15px;
}

.countdown-title {
  font-size: 0.9rem;
  margin-bottom: 5px;
  opacity: 0.9;
}

.countdown-time {
  font-size: 1.1rem;
  font-weight: bold;
}

.capsule-actions {
  text-align: center;
}

.view-btn {
  background: var(--button-bg);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 1rem;
}

.locked-text {
  color: var(--text-color);
  opacity: 0.6;
  font-style: italic;
}

/* 查看内容样式 */
.view-content {
  color: var(--text-color);
}

.capsule-meta {
  background: var(--bg-color);
  padding: 15px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.capsule-text {
  margin-bottom: 20px;
}

.capsule-text h4,
.capsule-media h4 {
  margin-bottom: 10px;
  color: var(--text-color);
}

.capsule-text p {
  line-height: 1.6;
  white-space: pre-wrap;
}

.media-image {
  max-width: 100%;
  border-radius: 8px;
}

.media-video {
  max-width: 100%;
  border-radius: 8px;
}

.media-file {
  display: inline-block;
  padding: 10px 15px;
  background: var(--button-bg);
  color: white;
  text-decoration: none;
  border-radius: 8px;
}

.unlock-question {
  background: #f8f9fa;
  padding: 1rem;
  border-radius: 8px;
  margin: 1rem 0;
  border-left: 4px solid #007bff;
}

.unlock-question p {
  margin: 0;
  color: #495057;
}

.capsule-question {
  background: #e3f2fd;
  padding: 0.5rem;
  border-radius: 4px;
  margin: 0.5rem 0;
  font-style: italic;
}

@media (max-width: 768px) {
  .capsules-grid {
    grid-template-columns: 1fr;
  }
  
  .create-form, .unlock-form, .view-dialog {
    width: 95%;
    padding: 20px;
  }
  
  .header-section h2 {
    font-size: 2rem;
  }
  
  .error-actions {
    flex-direction: column;
    align-items: center;
  }
  
  .retry-btn, .admin-btn {
    width: 200px;
  }
}
</style>