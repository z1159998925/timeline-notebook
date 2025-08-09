<template>
  <div class="home-page">
    <div class="timeline-container">
      <TimelineComponent ref="timelineComponent" @entryDeleted="refreshTimeline" />
    </div>

    <!-- 添加笔记的弹窗 -->
    <div class="modal-overlay" v-if="showAddModal" @click="closeModal"></div>
    <div class="add-modal" v-if="showAddModal">
      <button class="close-button" @click="closeModal">×</button>
      <AddEntryComponent @entryAdded="handleEntryAdded" />
    </div>

    <!-- 右下角+号按钮 -->
    <button v-if="isLoggedIn && user && user.role === 'admin'" class="add-button" @click="openModal">
      <i class="fas fa-plus"></i>
    </button>
  </div>
</template>

<script>
import AddEntryComponent from './AddEntryComponent.vue';
import TimelineComponent from './TimelineComponent.vue';
import api from '../axios.js';

export default {
  name: 'HomePage',
  components: {
    AddEntryComponent,
    TimelineComponent
  },
  data() {
    return {
      showAddModal: false,
      isLoggedIn: false,
      user: null
    };
  },
  mounted() {
    this.checkLoginStatus();
  },
  methods: {
    checkLoginStatus() {
      api.get('/api/login-status')
        .then(response => {
          this.isLoggedIn = response.data.is_logged_in;
          this.user = response.data.user || null;
        })
        .catch(error => {
          console.error('检查登录状态失败:', error);
          this.isLoggedIn = false;
          this.user = null;
        });
    },
    
    refreshTimeline() {
      // 触发子组件重新加载数据
      this.$refs.timelineComponent.fetchTimelineEntries();
    },
    openModal() {
      if (!this.isLoggedIn || !this.user || this.user.role !== 'admin') {
        this.$router.push('/admin-login');
        return;
      }
      this.showAddModal = true;
      // 阻止页面滚动
      document.body.style.overflow = 'hidden';
    },
    closeModal() {
      this.showAddModal = false;
      // 恢复页面滚动
      document.body.style.overflow = 'auto';
    },
    handleEntryAdded() {
      this.closeModal();
      this.refreshTimeline();
    }
  }
};
</script>

<style scoped>
.home-page {
  width: 100%;
  height: 100%;
}

.timeline-container {
  padding: 20px;
  box-sizing: border-box;
}

/* 添加按钮样式 */
.add-button {
  position: fixed;
  bottom: 30px;
  right: 30px;
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background-color: #42b983;
  color: white;
  border: none;
  font-size: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
  z-index: 100;
  transition: background-color 0.3s;
}

.add-button:hover {
  background-color: #3aa876;
}

/* 弹窗背景 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 1000;
}

/* 弹窗样式 */
.add-modal {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 100%;
  max-width: 600px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 5px 20px rgba(0, 0, 0, 0.2);
  z-index: 1001;
  padding: 20px;
  box-sizing: border-box;
}

/* 关闭按钮 */
.close-button {
  position: absolute;
  top: 10px;
  right: 10px;
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
  color: #666;
}

.close-button:hover {
  color: #333;
}

/* 响应式调整 */
@media (max-width: 768px) {
  .timeline-container {
    padding: 15px 10px;
  }

  .add-button {
    bottom: 20px;
    right: 20px;
    width: 50px;
    height: 50px;
    font-size: 20px;
  }

  .add-modal {
    max-width: 90%;
    padding: 15px;
  }
}
</style>