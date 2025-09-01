<template>
  <div class="add-entry-container">
    <h2>添加新记录</h2>
    
    <!-- 自动保存状态提示 -->
    <div class="auto-save-status" v-if="autoSaveStatus">
      <i :class="autoSaveIcon"></i>
      <span>{{ autoSaveStatus }}</span>
    </div>
    
    <form @submit.prevent="addEntry">
      <div class="form-group">
        <label for="title">标题 *</label>
        <input 
          type="text" 
          id="title" 
          v-model="title" 
          @input="onInputChange"
          required 
          placeholder="输入标题"
        >
      </div>
      
      <div class="form-group">
        <label for="content">内容</label>
        <textarea 
          id="content" 
          v-model="content" 
          @input="onInputChange"
          rows="4" 
          placeholder="输入内容"
        ></textarea>
      </div>
      
      <div class="form-group">
        <label for="media">上传媒体文件 (图片/视频/文档)</label>
        <input type="file" id="media" @change="handleFileChange">
      </div>
      
      <div class="form-actions">
        <button type="button" class="clear-button" @click="clearDraft" v-if="hasDraft">
          清除草稿
        </button>
        <button type="submit" class="submit-button">保存记录</button>
      </div>
    </form>
  </div>
</template>

<script>
import api from '../axios.js';

export default {
  name: 'AddEntryComponent',
  data() {
    return {
      title: '',
      content: '',
      file: null,
      autoSaveStatus: '',
      autoSaveTimer: null,
      lastSaveTime: null,
      hasDraft: false
    };
  },
  computed: {
    autoSaveIcon() {
      if (this.autoSaveStatus.includes('保存中')) {
        return 'fas fa-spinner fa-spin';
      } else if (this.autoSaveStatus.includes('已保存')) {
        return 'fas fa-check-circle';
      } else if (this.autoSaveStatus.includes('失败')) {
        return 'fas fa-exclamation-triangle';
      }
      return '';
    }
  },
  mounted() {
    // 页面加载时恢复草稿
    this.loadDraft();
    
    // 页面关闭前保存草稿
    window.addEventListener('beforeunload', this.saveDraft);
  },
  beforeUnmount() {
    // 清理定时器和事件监听器
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer);
    }
    window.removeEventListener('beforeunload', this.saveDraft);
  },
  methods: {
    // 输入变化时触发自动保存
    onInputChange() {
      // 清除之前的定时器
      if (this.autoSaveTimer) {
        clearTimeout(this.autoSaveTimer);
      }
      
      // 设置新的定时器，延迟500ms保存
      this.autoSaveTimer = setTimeout(() => {
        this.saveDraft();
      }, 500);
    },
    
    // 保存草稿到localStorage
    saveDraft() {
      const draftData = {
        title: this.title,
        content: this.content,
        timestamp: new Date().toISOString()
      };
      
      // 只有当有内容时才保存
      if (this.title.trim() || this.content.trim()) {
        try {
          localStorage.setItem('timeline_draft', JSON.stringify(draftData));
          this.hasDraft = true;
          this.lastSaveTime = new Date();
          this.showAutoSaveStatus('草稿已保存', 'success');
        } catch (error) {
          console.error('保存草稿失败:', error);
          this.showAutoSaveStatus('草稿保存失败', 'error');
        }
      } else {
        // 如果内容为空，清除草稿
        this.clearDraft();
      }
    },
    
    // 从localStorage加载草稿
    loadDraft() {
      try {
        const draftData = localStorage.getItem('timeline_draft');
        if (draftData) {
          const draft = JSON.parse(draftData);
          this.title = draft.title || '';
          this.content = draft.content || '';
          this.hasDraft = true;
          
          // 显示恢复提示
          const saveTime = new Date(draft.timestamp);
          const timeAgo = this.getTimeAgo(saveTime);
          this.showAutoSaveStatus(`已恢复 ${timeAgo} 的草稿`, 'info');
        }
      } catch (error) {
        console.error('加载草稿失败:', error);
        localStorage.removeItem('timeline_draft');
      }
    },
    
    // 清除草稿
    clearDraft() {
      localStorage.removeItem('timeline_draft');
      this.hasDraft = false;
      this.title = '';
      this.content = '';
      this.file = null;
      document.getElementById('media').value = '';
      this.showAutoSaveStatus('草稿已清除', 'info');
    },
    
    // 显示自动保存状态
    showAutoSaveStatus(message, type = 'info') {
      this.autoSaveStatus = message;
      
      // 3秒后自动隐藏状态提示
      setTimeout(() => {
        this.autoSaveStatus = '';
      }, 3000);
    },
    
    // 计算时间差
    getTimeAgo(date) {
      const now = new Date();
      const diff = now - date;
      const minutes = Math.floor(diff / 60000);
      const hours = Math.floor(diff / 3600000);
      
      if (minutes < 1) {
        return '刚刚';
      } else if (minutes < 60) {
        return `${minutes}分钟前`;
      } else if (hours < 24) {
        return `${hours}小时前`;
      } else {
        return '很久前';
      }
    },
    
    handleFileChange(event) {
      this.file = event.target.files[0];
    },
    
    addEntry() {
      if (!this.title) {
        alert('标题不能为空');
        return;
      }
      
      this.showAutoSaveStatus('保存中...', 'loading');
      
      

      const formData = new FormData();
      formData.append('title', this.title);
      formData.append('content', this.content);
      if (this.file) {
        formData.append('media', this.file);
      }

      api.post('/timeline', formData)
        .then(() => {
          // 成功后清除草稿和表单
          localStorage.removeItem('timeline_draft');
          this.title = '';
          this.content = '';
          this.file = null;
          this.hasDraft = false;
          document.getElementById('media').value = '';
          
          this.showAutoSaveStatus('记录保存成功！', 'success');
          this.$emit('entryAdded');
        })
        .catch(error => {
          console.error('添加记录失败:', error);
          this.showAutoSaveStatus('保存失败，请重试', 'error');
          alert('添加记录失败，请重试');
        });
    }
  }
};
</script>

<style scoped>
.add-entry-container {
  width: 100%;
  max-width: 100%;
  margin: 0;
  padding: 0;
  background-color: transparent;
  border-radius: 0;
  box-shadow: none;
  box-sizing: border-box;
}

.add-entry-container h2 {
  text-align: center;
  margin-top: 0;
  margin-bottom: 20px;
  color: #333;
}

.form-group {
  margin-bottom: 15px;
}

@media (max-width: 768px) {
  .form-group {
    margin-bottom: 12px;
  }
}

label {
  display: block;
  margin-bottom: 6px;
  font-weight: bold;
  color: #333;
  font-size: 0.95rem;
}

@media (max-width: 768px) {
  label {
    font-size: 0.9rem;
  }
}

input[type="text"], textarea {
  width: 100%;
  padding: 9px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.95rem;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  input[type="text"], textarea {
    padding: 8px;
    font-size: 0.9rem;
  }
  
  /* 删除了无效的CSS rows属性 */
}

input[type="file"] {
  margin-top: 8px;
}

.submit-button {
  background-color: #42b983;
  color: white;
  border: none;
  padding: 9px 18px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
  transition: background-color 0.3s;
  width: 100%;
}

@media (max-width: 768px) {
  .submit-button {
    padding: 8px 16px;
    font-size: 0.9rem;
  }
}

.submit-button:hover {
  background-color: #3aa876;
}

/* 自动保存状态提示 */
.auto-save-status {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  margin-bottom: 15px;
  border-radius: 4px;
  font-size: 0.9rem;
  background-color: #e8f5e8;
  color: #2d5a2d;
  border: 1px solid #c3e6c3;
  transition: all 0.3s ease;
}

.auto-save-status i {
  font-size: 0.9rem;
}

.auto-save-status i.fa-spinner {
  color: #007bff;
}

.auto-save-status i.fa-check-circle {
  color: #28a745;
}

.auto-save-status i.fa-exclamation-triangle {
  color: #dc3545;
}

/* 表单操作按钮区域 */
.form-actions {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
}

.clear-button {
  background-color: #6c757d;
  color: white;
  border: none;
  padding: 9px 18px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
  transition: background-color 0.3s;
  flex: 0 0 auto;
}

.clear-button:hover {
  background-color: #5a6268;
}

.submit-button {
  flex: 1;
  min-width: 120px;
}

@media (max-width: 768px) {
  .form-actions {
    flex-direction: column;
    gap: 8px;
  }
  
  .clear-button {
    width: 100%;
    padding: 8px 16px;
    font-size: 0.9rem;
  }
  
  .submit-button {
    width: 100%;
  }
  
  .auto-save-status {
    font-size: 0.85rem;
    padding: 6px 10px;
  }
}

/* 暗色主题适配 */
.dark .add-entry-container h2 {
  color: var(--text-color);
}

.dark label {
  color: var(--text-color);
}

.dark input[type="text"], 
.dark textarea {
  background-color: var(--card-bg);
  border-color: var(--border-color);
  color: var(--text-color);
}

.dark input[type="text"]:focus, 
.dark textarea:focus {
  border-color: var(--link-color);
  outline: none;
}

.dark .auto-save-status {
  background-color: var(--card-bg);
  border-color: var(--border-color);
  color: var(--text-color);
}
</style>