import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 开发环境配置
export default defineConfig({
  plugins: [vue()],
  
  // 🏗️ 开发构建配置
  build: {
    outDir: 'dist',
    target: 'es2020',
    minify: false, // 开发环境不压缩
    cssCodeSplit: true,
    sourcemap: true, // 开发环境启用sourcemap
    
    // 基础代码分割
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['vue', 'vue-router'],
          utils: ['axios', 'moment']
        }
      }
    },
    
    // 开发环境构建配置
    reportCompressedSize: true,
    chunkSizeWarningLimit: 2000,
    assetsInlineLimit: 4096
  },
  
  // 🔧 开发环境定义
  define: {
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: true, // 开发环境启用devtools
    'process.env.NODE_ENV': '"development"'
  },
  
  // 📦 依赖优化
  optimizeDeps: {
    include: ['vue', 'vue-router', 'axios', 'moment'],
    exclude: []
  },
  
  // 🌐 基础路径配置
  base: '/',
  
  // 📁 静态资源处理
  assetsInclude: ['**/*.svg', '**/*.png', '**/*.jpg', '**/*.jpeg', '**/*.gif'],
  
  // 🚀 开发服务器配置
  server: {
    host: '0.0.0.0',
    port: 5173,
    open: false,
    cors: true,
    
    // HMR配置
    hmr: {
      port: 5173
    },
    
    // 代理配置 - 连接到后端API
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true,
        secure: false,
        ws: true,
        configure: (proxy, _options) => {
          proxy.on('error', (err, _req, _res) => {
            console.log('proxy error', err);
          });
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            console.log('Sending Request to the Target:', req.method, req.url);
          });
          proxy.on('proxyRes', (proxyRes, req, _res) => {
            console.log('Received Response from the Target:', proxyRes.statusCode, req.url);
          });
        }
      }
    },
    
    // 监听文件变化
    watch: {
      usePolling: true,
      interval: 1000
    }
  },
  
  // 🎯 环境变量
  envPrefix: 'VITE_',
  
  // 📱 CSS配置
  css: {
    devSourcemap: true,
    preprocessorOptions: {
      scss: {
        additionalData: `@import "@/styles/variables.scss";`
      }
    }
  },
  
  // 🔍 路径解析
  resolve: {
    alias: {
      '@': '/src'
    }
  },
  
  // 🐛 调试配置
  esbuild: {
    drop: [] // 开发环境保留console.log
  }
})