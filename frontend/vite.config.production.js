import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 生产环境专用配置
export default defineConfig({
  plugins: [vue()],
  
  // 🏗️ 生产构建优化
  build: {
    outDir: 'dist',
    target: 'es2020',
    minify: 'terser',
    cssCodeSplit: true,
    sourcemap: false, // 生产环境关闭sourcemap
    
    // 代码分割优化
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['vue', 'vue-router'],
          utils: ['axios', 'moment'],
          ui: ['@fortawesome/fontawesome-free']
        },
        // 文件名优化
        chunkFileNames: 'assets/js/[name]-[hash].js',
        entryFileNames: 'assets/js/[name]-[hash].js',
        assetFileNames: 'assets/[ext]/[name]-[hash].[ext]'
      }
    },
    
    // 压缩配置
    terserOptions: {
      compress: {
        drop_console: true, // 移除console.log
        drop_debugger: true, // 移除debugger
        pure_funcs: ['console.log', 'console.info', 'console.debug'],
        // 生产优化
        passes: 2,
        unsafe: true,
        unsafe_comps: true,
        unsafe_math: true,
        unsafe_proto: true
      },
      mangle: {
        safari10: true
      },
      format: {
        comments: false
      }
    },
    
    // 构建优化
    reportCompressedSize: false,
    chunkSizeWarningLimit: 1000,
    // 生产优化配置
    assetsInlineLimit: 4096,
    cssMinify: true,
    modulePreload: {
      polyfill: true
    }
  },
  
  // 🔧 生产环境定义
  define: {
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: false, // 生产环境关闭devtools
    'process.env.NODE_ENV': '"production"'
  },
  
  // 📦 依赖优化
  optimizeDeps: {
    include: ['vue', 'vue-router', 'axios', 'moment'],
    exclude: ['@fortawesome/fontawesome-free']
  },
  
  // 🌐 基础路径配置
  base: '/',
  
  // 📁 静态资源处理
  assetsInclude: ['**/*.svg', '**/*.png', '**/*.jpg', '**/*.jpeg', '**/*.gif'],
  
  // 🔒 安全配置
  server: {
    // 生产环境不使用开发服务器
    hmr: false
  },
  
  // 📱 PWA配置（如果需要）
  // 可以添加PWA插件配置
  
  // 🎯 环境变量
  envPrefix: 'VITE_',
  
  // 📊 构建分析（可选）
  // build.rollupOptions.plugins: [
  //   import('rollup-plugin-analyzer').then(({ default: analyzer }) => 
  //     analyzer({ summaryOnly: true })
  //   )
  // ]
})