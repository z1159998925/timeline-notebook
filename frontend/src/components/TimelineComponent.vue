<template>
  <div class="timeline-container">
    <div class="timeline-header">
      <h2>我的时光轴</h2>
      <div class="search-container">
        <input
          type="text"
          v-model="searchQuery"
          placeholder="搜索笔记..."
          class="search-input"
          @input="debounceSearch"
        >
      </div>
      <!-- 简化按钮条件判断 -->
    <!-- 已删除与/create-entry关联的新建笔记按钮 -->
    <!-- 调试信息已移除 -->
    </div>
    <div class="timeline-content">
      <div v-for="entry in displayedEntries" :key="entry.id" class="timeline-item">
        <div class="timeline-dot"></div>
        <div class="timeline-card">
          <div class="timeline-date">{{ formatDate(entry.created_at) }}</div>
          <h3 class="timeline-title">{{ entry.title }}</h3>
          <p class="timeline-text" v-if="entry.content">{{ entry.content }}</p>
          
          <div v-if="entry.media_type === 'image'" class="timeline-media">
            <img 
              :src="getMediaUrl(entry.media_url)"
              alt="{{ entry.title }}"
              class="timeline-image"
              @error="handleImageError(getMediaUrl(entry.media_url), entry.media_url)"
              @load="handleImageLoad(getMediaUrl(entry.media_url))"
              @click="viewOriginalImage(getMediaUrl(entry.media_url))"
            >
            <div v-if="imageErrors[getMediaUrl(entry.media_url)]" class="image-error">
                图片加载失败: {{ getMediaUrl(entry.media_url) }}
                <p>错误信息: {{ imageErrorMessages[getMediaUrl(entry.media_url)] }}</p>
              </div>
          </div>
          
          <div v-if="entry.media_type === 'video'" class="timeline-media">
            <video :src="entry.media_url" controls class="timeline-video"></video>
          </div>
          
          <div v-if="entry.media_type === 'file'" class="timeline-media">
            <a :href="entry.media_url" target="_blank" class="timeline-file-link">
              <i class="fas fa-file"></i> 下载文件
            </a>
          </div>
          
          <div class="timeline-actions">

            <button @click="likeEntry(entry.id)" class="like-button">
              <i class="fas fa-heart"></i> 点赞 ({{ entry.likes || 0 }})
            </button>
            <button @click="toggleComments(entry.id)" class="comment-button">
              <i class="fas fa-comment"></i> 评论
            </button>
            <button v-if="isLoggedIn && user && user.role === 'admin'" @click="deleteEntry(entry.id)" class="delete-button">删除</button>
          </div>

          <div v-if="showComments[entry.id]" class="comments-section">
            <div class="comment-form">
              <textarea v-model="newComment[entry.id]" placeholder="添加评论..." class="comment-input"></textarea>
              <button @click="addComment(entry.id)" class="submit-comment-button">提交</button>
            </div>
            <div class="comments-list">
              <div v-for="comment in comments[entry.id]" :key="comment.id" class="comment-item">
                <div class="comment-date">{{ formatDate(comment.created_at) }}</div>
                <p class="comment-content">{{ comment.content }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import api from '../axios.js';
import moment from 'moment';

export default {
  name: 'TimelineComponent',
  data() {
    return {
      timelineEntries: [],
      filteredEntries: [],
      searchQuery: '',
      searchTimeout: null,
      showComments: {},
      comments: {},
      newComment: {},
      imageErrors: {},
      imageLoaded: {},
      imageErrorMessages: {},
      user: null,
      isLoggedIn: false,
      loginCheckInterval: null,
      // 添加开发环境标志
      isDev: import.meta.env.MODE === 'development',
      // 管理员标志
      isAdmin: false
    };
  },
  created() {
    // 在组件创建时就检查登录状态
    this.checkLoginStatus();
  },
  computed: {
    // 计算过滤后的条目
    displayedEntries() {
      if (!this.searchQuery.trim()) {
        return this.timelineEntries;
      }
      return this.filteredEntries;
    }
  },
  mounted() {
    this.fetchTimelineEntries();
    // 再次检查登录状态，确保没有延迟
    this.checkLoginStatus();
    // 添加定时器定期检查登录状态
    this.loginCheckInterval = setInterval(() => {
      this.checkLoginStatus();
    }, 5000);
  },
  beforeUnmount() {
    // 清除定时器
    if (this.loginCheckInterval) {
      clearInterval(this.loginCheckInterval);
    }
  },
  methods: {
    // 获取媒体文件URL，根据环境动态生成
    getMediaUrl(mediaUrl) {
      if (!mediaUrl) return '';
      
      // 如果是开发环境，使用localhost
      if (this.isDev) {
        return `http://localhost:5000${mediaUrl}`;
      }
      
      // 生产环境，使用相对路径或当前域名
      if (mediaUrl.startsWith('/')) {
        return mediaUrl; // 相对路径，浏览器会自动使用当前域名
      }
      
      return mediaUrl;
    },
    // 防抖搜索
    debounceSearch() {
      if (this.searchTimeout) {
        clearTimeout(this.searchTimeout);
      }
      this.searchTimeout = setTimeout(() => {
        this.searchEntries();
      }, 300);
    },
    // 执行搜索
    searchEntries() {
      const query = this.searchQuery.toLowerCase().trim();
      if (!query) {
        this.filteredEntries = [];
        return;
      }
      this.filteredEntries = this.timelineEntries.filter(entry => {
        return (
          entry.title.toLowerCase().includes(query) ||
          (entry.content && entry.content.toLowerCase().includes(query))
        );
      });
    },
    createNewEntry() {
      if (this.isLoggedIn && this.user && this.user.role === 'admin') {
        window.location.href = '/create-entry';
      } else {
        // 未登录或非管理员，跳转到登录页面
        window.location.href = '/admin-login';
      }
      },
    handleImageError(fullUrl, originalMediaUrl, event) {
      console.error('图片加载失败:', fullUrl);
      console.error('原始media_url:', originalMediaUrl);
      console.error('错误事件:', event);
      // 在Vue 3中，直接修改响应式对象即可
      this.imageErrors = Object.assign({}, this.imageErrors, {[fullUrl]: true});
      this.imageLoaded = Object.assign({}, this.imageLoaded, {[fullUrl]: false});
      this.imageErrorMessages = Object.assign({}, this.imageErrorMessages, {[fullUrl]: '无法加载图片' + (event && event.type ? '，事件类型: ' + event.type : '')});
      // 输出完整的图片URL，帮助调试
      
      // 尝试重新加载图片
      setTimeout(() => {

        const img = new Image();
        img.onload = () => {

          this.imageErrors = Object.assign({}, this.imageErrors);
          delete this.imageErrors[fullUrl];
          this.imageLoaded = Object.assign({}, this.imageLoaded, {[fullUrl]: true});
          this.imageErrorMessages = Object.assign({}, this.imageErrorMessages);
          delete this.imageErrorMessages[fullUrl];
        };

        img.onerror = () => {
          console.error('图片重新加载失败:', fullUrl);
        };
        img.src = fullUrl + '?t=' + new Date().getTime();
      }, 2000);
    },
    handleImageLoad(url) {

      // 在Vue 3中，直接修改响应式对象即可
      const newImageErrors = Object.assign({}, this.imageErrors);
      delete newImageErrors[url];
      this.imageErrors = newImageErrors;
      this.imageLoaded = Object.assign({}, this.imageLoaded, {[url]: true});
    },

    viewOriginalImage(url) {
      // 在新窗口打开原图
      window.open(url, '_blank');
    },
    fetchTimelineEntries() {
      api.get('/timeline')
        .then(response => {
          this.timelineEntries = response.data;
          // 为每个条目初始化评论状态
          this.timelineEntries.forEach(entry => {
            this.showComments[entry.id] = false;
            this.newComment[entry.id] = '';
            this.fetchComments(entry.id);
          });
        })
        .catch(error => {
          console.error('获取时光轴数据失败:', error);
        });
    },
    formatDate(dateString) {
      // 明确指定时间为 UTC 时间，然后转换为本地时间
      return moment.utc(dateString).local().format('YYYY-MM-DD HH:mm:ss');
    },
    checkLoginStatus() {

      api.get('/login-status')
        .then(response => {
          
          // 明确设置登录状态
          this.isLoggedIn = Boolean(response.data.is_logged_in);
          // 确保用户对象有效
          this.user = response.data.user !== undefined ? response.data.user : null;
          // 更新管理员标志
          this.isAdmin = this.isLoggedIn && this.user && this.user.role === 'admin';
          
        })
        .catch(error => {
          console.error('获取登录状态失败:', error);
          // 确保错误情况下登录状态为false
          this.isLoggedIn = false;
          this.user = null;
          this.isAdmin = false;
          
        });
    },

    deleteEntry(id) {
         if (confirm('确定要删除这条记录吗？')) {
          
          const url = `/timeline/${id}`;
          
          
          api.delete(url)
            .then(response => {
              
              alert('删除成功！');
              this.fetchTimelineEntries();
              this.$emit('entryDeleted');
            })
            .catch(error => {
               alert('删除失败，请重试！');
             });
        }
    },
    toggleComments(id) {
      this.showComments[id] = !this.showComments[id];
      if (this.showComments[id]) {
        this.fetchComments(id);
      }
    },
    fetchComments(id) {
      api.get(`/timeline/${id}/comments`)
        .then(response => {
          this.comments[id] = response.data;
        })
        .catch(error => {
          console.error('获取评论失败:', error);
        });
    },
    likeEntry(id) {
      api.post(`/timeline/${id}/like`)
        .then(response => {
          // 查找并更新点赞数
          const entry = this.timelineEntries.find(e => e.id === id);
          if (entry) {
            entry.likes = response.data.likes;
          }
        })
        .catch(error => {
          console.error('点赞失败:', error);
        });
    },
    addComment(id) {
      const content = this.newComment[id];
      if (!content.trim()) {
        alert('评论内容不能为空');
        return;
      }

      api.post(`/timeline/${id}/comments`, { content })
        .then(response => {
          if (!this.comments[id]) {
            this.comments[id] = [];
          }
          this.comments[id].unshift(response.data.comment);
          this.newComment[id] = '';
        })
        .catch(error => {
          console.error('添加评论失败:', error);
        });
    }
  }
};
</script>

<style scoped>
@import '@fortawesome/fontawesome-free/css/all.css';

.timeline-container {
  color: var(--text-color);
  width: 100%;
  max-width: 1000px;
  margin: 0 auto;
  padding: 15px;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .timeline-container {
    padding: 10px;
  }
}

.timeline-header {
  text-align: center;
  margin-bottom: 30px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 15px;
}

.search-container {
  width: 100%;
  max-width: 500px;
}

.search-input {
  width: 100%;
  padding: 10px 15px;
  border: 1px solid var(--border-color);
  border-radius: 20px;
  background-color: var(--card-bg);
  color: var(--text-color);
  font-size: 0.95rem;
  box-sizing: border-box;
}

.search-input:focus {
  outline: none;
  border-color: var(--link-color);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
}

.create-button {
  padding: 8px 16px;
  background-color: #42b983;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.fixed-button {
  position: fixed;
  bottom: 20px;
  right: 20px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
  z-index: 1000;
}

.create-button:hover {
  background-color: #3aa876;
}

.timeline-content {
  position: relative;
}

.timeline-content::before {
  content: '';
  position: absolute;
  width: 4px;
  background-color: var(--timeline-line);
  top: 0;
  bottom: 0;
  left: 20px;
  margin-left: -2px;
}

@media (max-width: 768px) {
  .timeline-content::before {
    left: 15px;
  }
}

.timeline-item {
  padding: 10px 30px;
  position: relative;
  background-color: inherit;
  width: 100%;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .timeline-item {
    padding: 10px 25px;
  }
}

.timeline-dot {
  position: absolute;
  width: 18px;
  height: 18px;
  background-color: #42b983;
  border-radius: 50%;
  left: 13px;
  top: 15px;
  z-index: 1;
}

@media (max-width: 768px) {
  .timeline-dot {
    left: 8px;
    width: 16px;
    height: 16px;
  }
}

.timeline-card {
  padding: 15px;
  background-color: var(--card-bg);
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .timeline-card {
    padding: 12px;
  }
}

.timeline-date {
  color: #666;
  font-size: 0.85rem;
  margin-bottom: 5px;
}

.timeline-title {
  margin-top: 0;
  color: var(--text-color);
  font-size: 1.2rem;
}

@media (max-width: 768px) {
  .timeline-title {
    font-size: 1.1rem;
  }
}

.timeline-text {
  color: var(--text-color);
  line-height: 1.6;
  font-size: 0.95rem;
}

@media (max-width: 768px) {
  .timeline-text {
    font-size: 0.9rem;
  }
}

.timeline-media {
  margin-top: 15px;
}

.timeline-image {
  max-width: 100%;
  max-height: 200px;
  height: auto;
  border-radius: 4px;
  cursor: pointer;
  transition: transform 0.2s;
  display: block;
  margin: 0 auto;
}

.timeline-image:hover {
  transform: scale(1.02);
}

.image-error {
  color: #ef4444;
  background-color: #fef2f2;
  padding: 8px;
  border-radius: 4px;
  margin-top: 5px;
  font-size: 0.9rem;
}

.timeline-video {
  max-width: 100%;
  border-radius: 4px;
}

.timeline-file-link {
  display: inline-block;
  padding: 8px 12px;
  background-color: #f0f0f0;
  color: #333;
  text-decoration: none;
  border-radius: 4px;
  margin-top: 5px;
}

.timeline-file-link:hover {
  background-color: #e0e0e0;
}

.timeline-actions {
  display: flex;
  gap: 10px;
  margin-top: 15px;
}

.like-button, .comment-button, .delete-button, .submit-comment-button {
  padding: 6px 12px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.like-button {
  background-color: #f0f7ff;
  color: #3b82f6;
}

.like-button:hover {
  background-color: #e0e7ff;
}

.comment-button {
  background-color: #f0fdf4;
  color: #22c55e;
}

.comment-button:hover {
  background-color: #dcfce7;
}

.delete-button {
  background-color: #fef2f2;
  color: #ef4444;
}

.delete-button:hover {
  background-color: #fee2e2;
}

.comments-section {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid #eee;
}

.comment-form {
  margin-bottom: 15px;
}

.comment-input {
  width: 100%;
  padding: 8px;
  border: 1px solid var(--border-color);
  border-radius: 4px;
  resize: vertical;
  min-height: 60px;
  box-sizing: border-box;
  background-color: var(--card-bg);
  color: var(--text-color);
}

.submit-comment-button {
  margin-top: 8px;
  background-color: #3b82f6;
  color: white;
}

.submit-comment-button:hover {
  background-color: #2563eb;
}

.comments-list {
  margin-top: 15px;
}

.comment-item {
  padding: 10px 0;
  border-bottom: 1px solid #eee;
}

.comment-date {
  color: #999;
  font-size: 0.8rem;
  margin-bottom: 3px;
}

.comment-content {
  color: #444;
  font-size: 0.9rem;
  margin: 0;
}

@media (max-width: 768px) {
  .timeline-actions {
    flex-wrap: wrap;
  }

  .like-button, .comment-button, .delete-button {
    flex: 1;
    min-width: 120px;
  }
}
</style>