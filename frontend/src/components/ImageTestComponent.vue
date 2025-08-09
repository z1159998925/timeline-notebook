<template>
  <div class="image-test-container">
    <h2>图片加载测试组件</h2>
    <div class="debug-info">
      <p>测试图片URL: {{ imageUrl }}</p>
      <p>图片加载状态: {{ isLoaded ? '已加载' : '未加载' }}</p>
      <p v-if="isError">图片加载错误: {{ errorMessage }}</p>
    </div>
    <div class="image-container">
      <img 
        :src="imageUrl"
        alt="测试图片"
        class="test-image"
        @load="handleLoad"
        @error="handleError"
      >
    </div>
    <button @click="reloadImage" class="reload-button">重新加载图片</button>
  </div>
</template>

<script>
import api from '../axios.js';

export default {
  name: 'ImageTestComponent',
  data() {
    return {
      imageUrl: null,
      isLoaded: false,
      isError: false,
      errorMessage: '',
      timelineEntries: []
    };
  },
  methods: {
    // 获取媒体文件URL，根据环境动态生成
    getMediaUrl(mediaUrl) {
      if (!mediaUrl) return '';
      
      // 如果是开发环境，使用localhost
      if (import.meta.env.MODE === 'development') {
        return `http://localhost:5000${mediaUrl}`;
      }
      
      // 生产环境，使用相对路径或当前域名
      if (mediaUrl.startsWith('/')) {
        return mediaUrl; // 相对路径，浏览器会自动使用当前域名
      }
      
      return mediaUrl;
    },
    handleLoad() {
      console.log('图片加载成功:', this.imageUrl);
      this.isLoaded = true;
      this.isError = false;
    },
    handleError(event) {
      console.error('图片加载失败:', this.imageUrl);
      console.error('错误事件:', event);
      this.isLoaded = false;
      this.isError = true;
      this.errorMessage = '无法加载图片' + (event && event.type ? '，事件类型: ' + event.type : '');
    },
    reloadImage() {
      console.log('重新加载图片:', this.imageUrl);
      this.isLoaded = false;
      this.isError = false;
      // 添加时间戳防止缓存
      if (this.imageUrl) {
        const baseUrl = this.imageUrl.split('?')[0];
        this.imageUrl = baseUrl + '?t=' + new Date().getTime();
      }
    },
    fetchTimelineEntries() {
      api.get('/api/timeline')
        .then(response => {
          this.timelineEntries = response.data;
          console.log('获取到的笔记:', this.timelineEntries);
          // 查找第一个有图片的笔记
          for (const entry of this.timelineEntries) {
            if (entry.media_type === 'image' && entry.media_url) {
              this.imageUrl = this.getMediaUrl(entry.media_url);
              console.log('找到图片URL:', this.imageUrl);
              break;
            }
          }
        })
        .catch(error => {
          console.error('获取笔记失败:', error);
          this.isError = true;
          this.errorMessage = '获取笔记失败: ' + error.message;
        });
    }
  },
  mounted() {
    console.log('图片测试组件已挂载');
    this.fetchTimelineEntries();
  }
};
</script>

<style scoped>
.image-test-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  font-family: Arial, sans-serif;
}

.debug-info {
  background-color: #f0f0f0;
  padding: 10px;
  border-radius: 4px;
  margin-bottom: 20px;
}

.image-container {
  border: 1px solid #ddd;
  padding: 10px;
  border-radius: 4px;
  margin-bottom: 20px;
  text-align: center;
}

.test-image {
  max-width: 100%;
  height: auto;
}

.reload-button {
  padding: 8px 16px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.reload-button:hover {
  background-color: #2563eb;
}
</style>