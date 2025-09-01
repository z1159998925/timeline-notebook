import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  
  // 构建配置
  build: {
    target: 'es2020', // 支持现代浏览器
    minify: 'terser',
    cssCodeSplit: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['vue', 'vue-router'],
          utils: ['axios', 'moment']
        }
      }
    }
  },
  
  // 开发服务器配置
  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true
      },
      '/static': {
        target: 'http://localhost:5000',
        changeOrigin: true
      }
    }
  },
  
  // 预览服务器配置
  preview: {
    host: '0.0.0.0',
    port: 4173
  },
  
  // 优化配置
  optimizeDeps: {
    include: ['vue', 'vue-router', 'axios', 'moment']
  }
})
