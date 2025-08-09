<template>
  <div class="admin-dashboard">
    <div class="header">
      <h1>管理员后台</h1>
      <div class="header-actions">
        <button @click="goToHome" class="home-button">返回首页</button>
        <button @click="logout" class="logout-button">退出登录</button>
      </div>
    </div>

    <!-- 标签页导航 -->
    <div class="tab-navigation">
      <button 
        @click="activeTab = 'timeline'" 
        :class="['tab-button', { active: activeTab === 'timeline' }]"
      >
        📝 时光轴管理
      </button>
      <button 
        @click="activeTab = 'capsules'" 
        :class="['tab-button', { active: activeTab === 'capsules' }]"
      >
        ⏰ 时间胶囊管理
      </button>
      <button 
        @click="activeTab = 'backup'" 
        :class="['tab-button', { active: activeTab === 'backup' }]"
      >
        💾 数据管理
      </button>
    </div>

    <!-- 时光轴管理 -->
    <div v-if="activeTab === 'timeline'" class="tab-content">
      <div class="actions">
        <button @click="showAddModal = true" class="add-button">添加笔记</button>
      </div>
    </div>

    <!-- 时间胶囊管理 -->
    <div v-if="activeTab === 'capsules'" class="tab-content">
      <div class="actions">
        <button @click="fetchTimeCapsules" class="refresh-button">刷新列表</button>
      </div>
      
      <!-- 时间胶囊列表 -->
      <div class="capsule-list">
        <div v-for="capsule in timeCapsules" :key="capsule.id" class="capsule-item">
          <div class="capsule-header">
            <h3>{{ capsule.title }}</h3>
            <div class="capsule-status">
              <span :class="['status-badge', capsule.is_unlocked ? 'unlocked' : 'locked']">
                {{ capsule.is_unlocked ? '已解锁' : '未解锁' }}
              </span>
            </div>
            <div class="item-actions">
              <button @click="openEditCapsuleModal(capsule)" class="edit-button">修改密码</button>
              <button @click="deleteCapsule(capsule.id)" class="delete-button">删除</button>
            </div>
          </div>
          <div class="capsule-content">
            <p><strong>内容:</strong> {{ capsule.content || '无内容' }}</p>
            <p><strong>问题:</strong> {{ capsule.question }}</p>
            <p><strong>创建时间:</strong> {{ formatDate(capsule.created_at) }}</p>
            <p><strong>解锁时间:</strong> {{ formatDate(capsule.unlock_date) }}</p>
            <p v-if="capsule.has_media"><strong>附件:</strong> {{ capsule.media_type }}</p>
            <p v-if="!capsule.can_unlock && !capsule.is_unlocked">
              <strong>剩余时间:</strong> {{ formatCountdown(capsule.remaining_time) }}
            </p>
          </div>
        </div>
        <div v-if="timeCapsules.length === 0" class="empty-state">
          <p>暂无时间胶囊</p>
        </div>
      </div>
    </div>

    <!-- 数据管理 -->
    <div v-if="activeTab === 'backup'" class="tab-content">
      <div class="backup-section">
        <h2>数据备份与还原</h2>
        
        <!-- 备份功能 -->
        <div class="backup-card">
          <div class="card-header">
            <h3>📦 数据备份</h3>
            <p>导出所有数据到备份文件</p>
          </div>
          <div class="card-content">
            <div class="backup-info">
              <div class="info-item">
                <span class="label">时光轴条目:</span>
                <span class="value">{{ timelineEntries.length }} 条</span>
              </div>
              <div class="info-item">
                <span class="label">时间胶囊:</span>
                <span class="value">{{ timeCapsules.length }} 个</span>
              </div>
              <div class="info-item">
                <span class="label">用户账户:</span>
                <span class="value">{{ userCount }} 个</span>
              </div>
            </div>
            <div class="backup-actions">
              <button @click="createBackup" :disabled="isBackingUp" class="backup-button">
                <span v-if="isBackingUp">🔄 备份中...</span>
                <span v-else>💾 创建备份</span>
              </button>
            </div>
          </div>
        </div>

        <!-- 还原功能 -->
        <div class="restore-card">
          <div class="card-header">
            <h3>📥 数据还原</h3>
            <p>从备份文件还原数据</p>
          </div>
          <div class="card-content">
            <div class="restore-warning">
              <p>⚠️ <strong>警告:</strong> 还原操作将覆盖当前所有数据，此操作不可逆！</p>
            </div>
            <div class="restore-actions">
              <input 
                type="file" 
                ref="backupFileInput" 
                @change="handleBackupFileSelect" 
                accept=".json"
                style="display: none"
              >
              <button @click="selectBackupFile" class="select-file-button">
                📁 选择备份文件
              </button>
              <button 
                @click="restoreFromBackup" 
                :disabled="!selectedBackupFile || isRestoring" 
                class="restore-button"
              >
                <span v-if="isRestoring">🔄 还原中...</span>
                <span v-else>📥 开始还原</span>
              </button>
            </div>
            <div v-if="selectedBackupFile" class="selected-file">
              <p>已选择文件: {{ selectedBackupFile.name }}</p>
            </div>
          </div>
        </div>

        <!-- 备份历史 -->
        <div class="backup-history">
          <h3>📋 备份历史</h3>
          <div v-if="backupHistory.length === 0" class="empty-state">
            <p>暂无备份记录</p>
          </div>
          <div v-else class="history-list">
            <div v-for="backup in backupHistory" :key="backup.id" class="history-item">
              <div class="history-info">
                <span class="backup-name">{{ backup.filename }}</span>
                <span class="backup-date">{{ formatDate(backup.created_at) }}</span>
                <span class="backup-size">{{ formatFileSize(backup.size) }}</span>
              </div>
              <div class="history-actions">
                <button @click="downloadBackup(backup.id)" class="download-button">下载</button>
                <button @click="deleteBackup(backup.id)" class="delete-button">删除</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 时光轴列表 -->
    <div v-if="activeTab === 'timeline'" class="timeline-list">
      <div v-for="entry in timelineEntries" :key="entry.id" class="timeline-item">
        <div class="timeline-header">
          <h3>{{ entry.title }}</h3>
          <div class="item-actions">
            <button @click="openEditModal(entry)" class="edit-button">编辑</button>
            <button @click="deleteEntry(entry.id)" class="delete-button">删除</button>
          </div>
        </div>
        <div class="timeline-content">
          <p>{{ entry.content }}</p>
          <!-- 调试信息已移除 -->
          <div v-if="entry.media_type && entry.media_type.includes('image')">
              <img :src="normalizeUrl(entry.media_url)" alt="{{ entry.title }}" class="preview-image" @error="handleImageError($event, entry.id)">
              <p v-if="imageErrors[entry.id]" class="error-message">图片加载失败: {{ imageErrors[entry.id] }}</p>
            </div>
            <div v-else-if="entry.media_url">
              <p>媒体URL存在，但媒体类型不是图片: {{ entry.media_type }}</p>
              <img :src="entry.media_url" alt="尝试显示媒体" class="preview-image" onerror="this.style.display='none'">
            </div>
          <div v-else-if="entry.media_type">
            <p>媒体类型: {{ entry.media_type }}, 路径: {{ entry.media_url }}</p>
          </div>
          <div class="timeline-meta">
            <span>{{ entry.created_at }}</span>
            <span>点赞数: {{ entry.likes || 0 }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 添加笔记模态框 -->
    <div v-if="showAddModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h2>添加新笔记</h2>
          <button @click="showAddModal = false" class="close-button">&times;</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label for="title">标题</label>
            <input type="text" id="title" v-model="newEntry.title" placeholder="输入标题">
          </div>
          <div class="form-group">
            <label for="content">内容</label>
            <textarea id="content" v-model="newEntry.content" placeholder="输入内容"></textarea>
          </div>
          <div class="form-group">
            <label for="media">上传媒体</label>
            <input type="file" id="media" @change="handleFileChange">
          </div>
        </div>
        <div class="modal-footer">
          <button @click="showAddModal = false" class="cancel-button">取消</button>
          <button @click="addEntry" class="submit-button">提交</button>
        </div>
      </div>
    </div>

    <!-- 编辑笔记模态框 -->
    <div v-if="showEditModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h2>编辑笔记</h2>
          <button @click="showEditModal = false" class="close-button">&times;</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label for="editTitle">标题</label>
            <input type="text" id="editTitle" v-model="editEntry.title" placeholder="输入标题">
          </div>
          <div class="form-group">
            <label for="editContent">内容</label>
            <textarea id="editContent" v-model="editEntry.content" placeholder="输入内容"></textarea>
          </div>
          <div class="form-group">
            <label>当前媒体</label>
            <div v-if="editEntry.media_type === 'image'">
              <img :src="normalizeUrl(editEntry.media_url)" alt="{{ editEntry.title }}" class="preview-image">
            </div>
            <div v-else-if="editEntry.media_type">
              <p>已上传: {{ editEntry.media_type }}</p>
            </div>
            <div v-else>
              <p>无媒体文件</p>
            </div>
            <input type="file" @change="handleEditFileChange">
          </div>
        </div>
        <div class="modal-footer">
          <button @click="showEditModal = false" class="cancel-button">取消</button>
          <button @click="updateEntry" class="submit-button">更新</button>
        </div>
      </div>
    </div>

    <!-- 修改时间胶囊密码模态框 -->
    <div v-if="showEditCapsuleModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h2>修改时间胶囊密码</h2>
          <button @click="showEditCapsuleModal = false" class="close-button">&times;</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label>胶囊标题</label>
            <input type="text" :value="editCapsule.title" readonly class="readonly-input">
          </div>
          <div class="form-group">
            <label>当前问题</label>
            <input type="text" v-model="editCapsule.question" placeholder="输入新问题">
          </div>
          <div class="form-group">
            <label>新答案</label>
            <input type="text" v-model="newCapsuleAnswer" placeholder="输入新答案">
          </div>
        </div>
        <div class="modal-footer">
          <button @click="showEditCapsuleModal = false" class="cancel-button">取消</button>
          <button @click="updateCapsulePassword" class="submit-button">更新密码</button>
        </div>
      </div>
    </div>

    <!-- 隐藏的文件输入 -->
    <input 
      ref="backupFileInput" 
      type="file" 
      accept=".json" 
      style="display: none" 
      @change="handleBackupFileSelect"
    />
  </div>
</template>

<script>
import api from '../axios.js';

export default {
  name: 'AdminDashboard',
  data() {
    return {
      activeTab: 'timeline', // 默认显示时光轴管理
      timelineEntries: [],
      timeCapsules: [],
      showAddModal: false,
      showEditModal: false,
      showEditCapsuleModal: false,
      newEntry: {
        title: '',
        content: ''
      },
      editEntry: {},
      editCapsule: {},
      newCapsuleAnswer: '',
      selectedFile: null,
      editFile: null,
      imageErrors: {},
      // 备份相关数据
      userCount: 0,
      isBackingUp: false,
      isRestoring: false,
      selectedBackupFile: null,
      backupHistory: []
    };
  },
  mounted() {
    this.fetchTimelineEntries();
    this.fetchTimeCapsules();
    this.fetchUserCount();
    this.fetchBackupHistory();
  },
  methods: {
    // 处理URL中的反斜杠和URL编码的反斜杠
    normalizeUrl(url) {
      if (!url) return url;
      // 替换URL编码的反斜杠(%5C)
      url = url.replace(/%5C/g, '/');
      // 替换普通反斜杠
      return url.replace(/\\/g, '/');
    },
    fetchTimelineEntries() {
      api.get('/api/timeline')
        .then(response => {
          this.timelineEntries = response.data;
        })
        .catch(error => {
          console.error('获取笔记失败:', error);
        });
    },

    logout() {
      api.post('/api/logout')
        .then(() => {
          this.$router.push('/admin-login');
        })
        .catch(error => {
          console.error('登出失败:', error);
        });
    },
    goToHome() {
      this.$router.push('/');
    },

    addEntry() {
      if (!this.newEntry.title) {
        alert('标题不能为空');
        return;
      }

      const formData = new FormData();
      formData.append('title', this.newEntry.title);
      formData.append('content', this.newEntry.content);
      if (this.selectedFile) {
        formData.append('media', this.selectedFile);
      }

      api.post('/api/timeline', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      })
      .then(() => {
        this.showAddModal = false;
        this.newEntry = { title: '', content: '' };
        this.selectedFile = null;
        this.fetchTimelineEntries();
      })
      .catch(error => {
        console.error('添加笔记失败:', error);
        alert('添加笔记失败: ' + (error.response?.data?.message || error.message));
      });
    },

    openEditModal(entry) {
      this.editEntry = { ...entry };
      this.showEditModal = true;
      this.editFile = null;
    },

    updateEntry() {
      if (!this.editEntry.title) {
        alert('标题不能为空');
        return;
      }

      const formData = new FormData();
      formData.append('title', this.editEntry.title);
      formData.append('content', this.editEntry.content);
      if (this.editFile) {
        formData.append('media', this.editFile);
      }

      api.put(`/api/timeline/${this.editEntry.id}`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      })
      .then(() => {
        this.showEditModal = false;
        this.editFile = null;
        this.fetchTimelineEntries();
      })
      .catch(error => {
        console.error('更新笔记失败:', error);
        alert('更新笔记失败: ' + (error.response?.data?.message || error.message));
      });
    },

    deleteEntry(id) {
      if (confirm('确定要删除这条笔记吗？')) {
        api.delete(`/api/timeline/${id}`)
          .then(() => {
            this.fetchTimelineEntries();
          })
          .catch(error => {
            console.error('删除笔记失败:', error);
            alert('删除笔记失败: ' + (error.response?.data?.message || error.message));
          });
      }
    },

    handleFileChange(event) {
      this.selectedFile = event.target.files[0];
    },

    handleEditFileChange(event) {
      this.editFile = event.target.files[0];
    },

    handleImageError(event, entryId) {
      // 在Vue 3中，直接修改响应式对象即可
      this.imageErrors = {
        ...this.imageErrors,
        [entryId]: event.target.src
      };
      console.error('图片加载失败:', event.target.src);
    },

    // 时间胶囊管理方法
    fetchTimeCapsules() {
      api.get('/api/time-capsules')
        .then(response => {
          this.timeCapsules = response.data;
        })
        .catch(error => {
          console.error('获取时间胶囊失败:', error);
        });
    },

    deleteCapsule(id) {
      if (confirm('确定要删除这个时间胶囊吗？此操作不可撤销！')) {
        api.delete(`/api/time-capsules/${id}`)
          .then(() => {
            alert('时间胶囊删除成功');
            this.fetchTimeCapsules();
          })
          .catch(error => {
            console.error('删除时间胶囊失败:', error);
            alert('删除失败: ' + (error.response?.data?.message || error.message));
          });
      }
    },

    openEditCapsuleModal(capsule) {
      this.editCapsule = { ...capsule };
      this.newCapsuleAnswer = '';
      this.showEditCapsuleModal = true;
    },

    updateCapsulePassword() {
      if (!this.editCapsule.question.trim()) {
        alert('问题不能为空');
        return;
      }
      if (!this.newCapsuleAnswer.trim()) {
        alert('新答案不能为空');
        return;
      }

      const updateData = {
        question: this.editCapsule.question,
        answer: this.newCapsuleAnswer
      };

      api.put(`/api/time-capsules/${this.editCapsule.id}/password`, updateData)
        .then(() => {
          alert('时间胶囊密码更新成功');
          this.showEditCapsuleModal = false;
          this.fetchTimeCapsules();
        })
        .catch(error => {
          console.error('更新密码失败:', error);
          alert('更新失败: ' + (error.response?.data?.message || error.message));
        });
    },

    // 格式化日期
    formatDate(dateString) {
      return new Date(dateString).toLocaleString('zh-CN');
    },

    // 格式化倒计时
    formatCountdown(seconds) {
      if (seconds <= 0) return '已可解锁';
      
      const days = Math.floor(seconds / 86400);
      const hours = Math.floor((seconds % 86400) / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);

      if (days > 0) {
        return `${days}天 ${hours}小时 ${minutes}分钟`;
      } else if (hours > 0) {
        return `${hours}小时 ${minutes}分钟`;
      } else {
        return `${minutes}分钟`;
      }
    },

    // 备份和还原相关方法
    fetchUserCount() {
      api.get('/api/admin/users/count')
        .then(response => {
          this.userCount = response.data.count;
        })
        .catch(error => {
          console.error('获取用户数量失败:', error);
          this.userCount = 0;
        });
    },

    fetchBackupHistory() {
      api.get('/api/admin/backups')
        .then(response => {
          this.backupHistory = response.data;
        })
        .catch(error => {
          console.error('获取备份历史失败:', error);
          this.backupHistory = [];
        });
    },

    createBackup() {
      if (this.isBackingUp) return;
      
      this.isBackingUp = true;
      api.post('/api/admin/backup')
        .then(response => {
          alert('备份创建成功！');
          this.fetchBackupHistory();
          // 自动下载备份文件
          const link = document.createElement('a');
          link.href = response.data.download_url;
          link.download = response.data.filename;
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
        })
        .catch(error => {
          console.error('创建备份失败:', error);
          alert('创建备份失败: ' + (error.response?.data?.message || error.message));
        })
        .finally(() => {
          this.isBackingUp = false;
        });
    },

    selectBackupFile() {
      this.$refs.backupFileInput.click();
    },

    handleBackupFileSelect(event) {
      const file = event.target.files[0];
      if (file) {
        if (file.type !== 'application/json' && !file.name.endsWith('.json')) {
          alert('请选择有效的JSON备份文件');
          return;
        }
        this.selectedBackupFile = file;
      }
    },

    restoreFromBackup() {
      if (!this.selectedBackupFile || this.isRestoring) return;
      
      if (!confirm('确定要从备份文件还原数据吗？这将覆盖当前所有数据，此操作不可逆！')) {
        return;
      }

      this.isRestoring = true;
      const formData = new FormData();
      formData.append('backup_file', this.selectedBackupFile);

      api.post('/api/admin/restore', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      })
      .then(response => {
        alert('数据还原成功！页面将刷新以显示最新数据。');
        // 刷新所有数据
        this.fetchTimelineEntries();
        this.fetchTimeCapsules();
        this.fetchUserCount();
        this.fetchBackupHistory();
        this.selectedBackupFile = null;
        this.$refs.backupFileInput.value = '';
      })
      .catch(error => {
        console.error('数据还原失败:', error);
        alert('数据还原失败: ' + (error.response?.data?.message || error.message));
      })
      .finally(() => {
        this.isRestoring = false;
      });
    },

    downloadBackup(backupId) {
      api.get(`/api/admin/backups/${backupId}/download`, {
        responseType: 'blob'
      })
      .then(response => {
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.download = `backup_${backupId}.json`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
      })
      .catch(error => {
        console.error('下载备份失败:', error);
        alert('下载备份失败: ' + (error.response?.data?.message || error.message));
      });
    },

    deleteBackup(backupId) {
      if (confirm('确定要删除这个备份吗？')) {
        api.delete(`/api/admin/backups/${backupId}`)
          .then(() => {
            alert('备份删除成功');
            this.fetchBackupHistory();
          })
          .catch(error => {
            console.error('删除备份失败:', error);
            alert('删除备份失败: ' + (error.response?.data?.message || error.message));
          });
      }
    },

    formatFileSize(bytes) {
      if (bytes === 0) return '0 Bytes';
      const k = 1024;
      const sizes = ['Bytes', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
  }
};
</script>

<style scoped>
.admin-dashboard {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 10px;
  border-bottom: 1px solid #eee;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.home-button {
  padding: 8px 16px;
  background-color: #10b981;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.logout-button {
  padding: 8px 16px;
  background-color: #ef4444;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.actions {
  margin-bottom: 20px;
}

.add-button {
  padding: 8px 16px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.timeline-list {
  margin-top: 20px;
}

.timeline-item {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  padding: 15px;
  margin-bottom: 15px;
}

.timeline-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.item-actions {
  display: flex;
  gap: 10px;
}

.edit-button {
  padding: 6px 12px;
  background-color: #fbbf24;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.delete-button {
  padding: 6px 12px;
  background-color: #ef4444;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.timeline-content {
  color: #555;
}

.preview-image {
  max-width: 200px;
  height: auto;
  margin-top: 10px;
  border-radius: 4px;
}

.error-message {
  color: #ef4444;
  font-size: 0.85rem;
  margin-top: 5px;
}

.timeline-meta {
  display: flex;
  justify-content: space-between;
  margin-top: 10px;
  color: #999;
  font-size: 0.85rem;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal {
  background-color: white;
  border-radius: 8px;
  width: 100%;
  max-width: 500px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px;
  border-bottom: 1px solid #eee;
}

.close-button {
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
}

.modal-body {
  padding: 15px;
}

.form-group {
  margin-bottom: 15px;
}

label {
  display: block;
  margin-bottom: 5px;
  color: #555;
}

input, textarea {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  box-sizing: border-box;
}

textarea {
  min-height: 100px;
  resize: vertical;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 15px;
  border-top: 1px solid #eee;
}

.cancel-button {
  padding: 8px 16px;
  background-color: #f3f4f6;
  color: #333;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.submit-button {
  padding: 8px 16px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

/* 标签页样式 */
.tab-navigation {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 2px solid #e5e7eb;
}

.tab-button {
  padding: 12px 24px;
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-size: 16px;
  color: #6b7280;
  transition: all 0.3s ease;
}

.tab-button:hover {
  color: #3b82f6;
}

.tab-button.active {
  color: #3b82f6;
  border-bottom-color: #3b82f6;
  font-weight: 600;
}

.tab-content {
  margin-top: 20px;
}

/* 时间胶囊管理样式 */
.capsule-list {
  margin-top: 20px;
}

.capsule-item {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  padding: 20px;
  margin-bottom: 15px;
  border-left: 4px solid #8b5cf6;
}

.capsule-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
  flex-wrap: wrap;
  gap: 10px;
}

.capsule-status {
  display: flex;
  align-items: center;
}

.status-badge {
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
}

.status-badge.locked {
  background-color: #fef3c7;
  color: #d97706;
}

.status-badge.unlocked {
  background-color: #d1fae5;
  color: #059669;
}

.capsule-content {
  color: #555;
  line-height: 1.6;
}

.capsule-content p {
  margin: 8px 0;
}

.capsule-content strong {
  color: #374151;
}

.refresh-button {
  padding: 8px 16px;
  background-color: #10b981;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.refresh-button:hover {
  background-color: #059669;
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: #9ca3af;
  font-style: italic;
}

.readonly-input {
  background-color: #f9fafb;
  color: #6b7280;
  cursor: not-allowed;
}

/* 数据管理样式 */
.backup-section {
  padding: 20px;
}

.backup-card, .restore-card {
  background: white;
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  border: 1px solid #e5e7eb;
}

.card-header {
  margin-bottom: 20px;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 15px;
}

.card-header h3 {
  margin: 0 0 8px 0;
  color: #333;
  font-size: 1.3em;
  display: flex;
  align-items: center;
  gap: 8px;
}

.card-header p {
  margin: 0;
  color: #666;
  font-size: 0.9em;
}

.backup-info {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 15px;
  margin-bottom: 20px;
}

.info-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 6px;
  border: 1px solid #e9ecef;
}

.info-item .label {
  color: #666;
  font-weight: 500;
}

.info-item .value {
  color: #333;
  font-weight: bold;
  font-size: 1.1em;
}

.backup-actions, .restore-actions {
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
}

.backup-button, .select-file-button, .restore-button {
  padding: 10px 20px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  gap: 8px;
}

.backup-button {
  background-color: #3b82f6;
  color: white;
}

.backup-button:hover:not(:disabled) {
  background-color: #2563eb;
}

.select-file-button {
  background-color: #6b7280;
  color: white;
}

.select-file-button:hover {
  background-color: #4b5563;
}

.restore-button {
  background-color: #10b981;
  color: white;
}

.restore-button:hover:not(:disabled) {
  background-color: #059669;
}

.restore-warning {
  background-color: #fef3c7;
  border: 1px solid #f59e0b;
  border-radius: 6px;
  padding: 15px;
  margin-bottom: 20px;
}

.restore-warning p {
  margin: 0;
  color: #92400e;
}

.selected-file {
  background-color: #d1fae5;
  border: 1px solid #10b981;
  border-radius: 6px;
  padding: 12px;
  margin-top: 15px;
}

.selected-file p {
  margin: 0;
  color: #065f46;
  font-weight: 500;
}

.backup-history {
  background: white;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  border: 1px solid #e5e7eb;
}

.backup-history h3 {
  margin: 0 0 20px 0;
  color: #333;
  font-size: 1.2em;
  display: flex;
  align-items: center;
  gap: 8px;
}

.history-list {
  max-height: 400px;
  overflow-y: auto;
}

.history-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  margin-bottom: 12px;
  background: #f9fafb;
  transition: background-color 0.2s ease;
}

.history-item:hover {
  background: #f3f4f6;
}

.history-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.backup-name {
  font-weight: bold;
  color: #333;
  font-size: 1em;
}

.backup-date {
  color: #666;
  font-size: 0.85em;
}

.backup-size {
  color: #6b7280;
  font-size: 0.8em;
  font-weight: 500;
}

.history-actions {
  display: flex;
  gap: 8px;
}

.download-button {
  padding: 6px 12px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.85em;
  transition: background-color 0.2s ease;
}

.download-button:hover {
  background-color: #2563eb;
}

/* 按钮禁用状态 */
button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .capsule-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .tab-button {
    padding: 8px 16px;
    font-size: 14px;
  }

  .backup-section {
    padding: 15px;
  }

  .backup-info {
    grid-template-columns: 1fr;
  }

  .backup-actions, .restore-actions {
    flex-direction: column;
    align-items: stretch;
  }

  .history-item {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .history-actions {
    justify-content: center;
  }

  .info-item {
    flex-direction: column;
    gap: 8px;
    text-align: center;
  }
}
</style>