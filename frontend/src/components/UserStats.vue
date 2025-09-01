<template>
  <div class="user-stats">
    <div class="stats-header">
      <h3 class="stats-title">
        <i class="icon-chart"></i>
        用户统计分析
      </h3>
      <div class="stats-actions">
        <button @click="refreshStats" class="btn btn-primary" :disabled="loading">
          <i class="icon-refresh" :class="{ spinning: loading }"></i>
          刷新数据
        </button>
      </div>
    </div>
    
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>加载统计数据中...</p>
    </div>
    
    <div v-else-if="stats" class="stats-content">
      <!-- 基础统计 -->
      <div class="stats-section">
        <h4 class="section-title">基础统计</h4>
        <div class="stats-grid">
          <div class="stat-card primary">
            <div class="stat-icon">
              <i class="icon-users"></i>
            </div>
            <div class="stat-content">
              <div class="stat-number">{{ stats.basic.total_users }}</div>
              <div class="stat-label">总用户数</div>
            </div>
          </div>
          
          <div class="stat-card success">
            <div class="stat-icon">
              <i class="icon-user-check"></i>
            </div>
            <div class="stat-content">
              <div class="stat-number">{{ stats.basic.active_users }}</div>
              <div class="stat-label">活跃用户</div>
              <div class="stat-percentage">{{ getPercentage(stats.basic.active_users, stats.basic.total_users) }}%</div>
            </div>
          </div>
          
          <div class="stat-card warning">
            <div class="stat-icon">
              <i class="icon-user-x"></i>
            </div>
            <div class="stat-content">
              <div class="stat-number">{{ stats.basic.inactive_users }}</div>
              <div class="stat-label">禁用用户</div>
              <div class="stat-percentage">{{ getPercentage(stats.basic.inactive_users, stats.basic.total_users) }}%</div>
            </div>
          </div>
          
          <div class="stat-card info">
            <div class="stat-icon">
              <i class="icon-crown"></i>
            </div>
            <div class="stat-content">
              <div class="stat-number">{{ stats.basic.admin_users }}</div>
              <div class="stat-label">管理员</div>
              <div class="stat-percentage">{{ getPercentage(stats.basic.admin_users, stats.basic.total_users) }}%</div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 用户活动统计 -->
      <div class="stats-section">
        <h4 class="section-title">用户活动</h4>
        <div class="activity-stats">
          <div class="activity-grid">
            <div class="activity-card">
              <div class="activity-header">
                <h5>最近注册用户</h5>
                <span class="activity-count">{{ stats.basic.recent_registrations }}</span>
              </div>
              <div class="activity-desc">过去7天内注册的用户数量</div>
            </div>
            
            <div class="activity-card">
              <div class="activity-header">
                <h5>最近活跃用户</h5>
                <span class="activity-count">{{ stats.basic.recent_active }}</span>
              </div>
              <div class="activity-desc">过去7天内有登录记录的用户</div>
            </div>
            
            <div class="activity-card">
              <div class="activity-header">
                <h5>总登录次数</h5>
                <span class="activity-count">{{ stats.activity.total_logins }}</span>
              </div>
              <div class="activity-desc">所有用户的累计登录次数</div>
            </div>
            
            <div class="activity-card">
              <div class="activity-header">
                <h5>平均登录次数</h5>
                <span class="activity-count">{{ stats.activity.avg_logins_per_user }}</span>
              </div>
              <div class="activity-desc">每个用户的平均登录次数</div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 每日注册统计图表 -->
      <div class="stats-section">
        <h4 class="section-title">每日注册趋势</h4>
        <div class="chart-container">
          <div v-if="stats.daily_registrations && stats.daily_registrations.length > 0" class="registration-chart">
            <div class="chart-bars">
              <div 
                v-for="(day, index) in stats.daily_registrations" 
                :key="index"
                class="chart-bar"
                :style="{ height: getBarHeight(day.count, getMaxRegistrations()) + '%' }"
                :title="`${day.date}: ${day.count} 人注册`"
              >
                <div class="bar-value">{{ day.count }}</div>
              </div>
            </div>
            <div class="chart-labels">
              <div 
                v-for="(day, index) in stats.daily_registrations" 
                :key="index"
                class="chart-label"
              >
                {{ formatChartDate(day.date) }}
              </div>
            </div>
          </div>
          <div v-else class="empty-chart">
            <p>暂无注册数据</p>
          </div>
        </div>
      </div>
      
      <!-- 用户内容统计 -->
      <div class="stats-section">
        <h4 class="section-title">内容贡献排行</h4>
        <div class="content-stats">
          <div v-if="stats.user_content && stats.user_content.length > 0" class="content-ranking">
            <div class="ranking-header">
              <div class="rank-col">排名</div>
              <div class="user-col">用户</div>
              <div class="content-col">时光轴</div>
              <div class="content-col">留言</div>
              <div class="content-col">评论</div>
              <div class="total-col">总计</div>
            </div>
            <div class="ranking-list">
              <div 
                v-for="(user, index) in stats.user_content" 
                :key="user.user_id"
                class="ranking-item"
                :class="{ 'top-user': index < 3 }"
              >
                <div class="rank-col">
                  <span class="rank-number" :class="getRankClass(index)">
                    {{ index + 1 }}
                  </span>
                </div>
                <div class="user-col">
                  <div class="user-info">
                    <img 
                      :src="user.avatar_url || '/default-avatar.png'" 
                      :alt="user.username"
                      class="user-avatar"
                    >
                    <span class="username">{{ user.username }}</span>
                  </div>
                </div>
                <div class="content-col">{{ user.timeline_count }}</div>
                <div class="content-col">{{ user.message_count }}</div>
                <div class="content-col">{{ user.comment_count }}</div>
                <div class="total-col">
                  <span class="total-content">{{ user.total_content }}</span>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="empty-ranking">
            <p>暂无内容数据</p>
          </div>
        </div>
      </div>
    </div>
    
    <div v-else class="error-state">
      <div class="error-icon">
        <i class="icon-alert"></i>
      </div>
      <p>加载统计数据失败</p>
      <button @click="refreshStats" class="btn btn-primary">
        重试
      </button>
    </div>
  </div>
</template>

<script>
export default {
  name: 'UserStats',
  data() {
    return {
      stats: null,
      loading: false
    }
  },
  mounted() {
    this.loadStats()
  },
  methods: {
    async loadStats() {
      this.loading = true
      try {
        const response = await fetch('/api/admin/users/stats', {
          credentials: 'include'
        })
        
        if (response.ok) {
          this.stats = await response.json()
        } else {
          console.error('加载统计数据失败')
          this.stats = null
        }
      } catch (error) {
        console.error('加载统计数据时发生错误:', error)
        this.stats = null
      } finally {
        this.loading = false
      }
    },
    
    refreshStats() {
      this.loadStats()
    },
    
    getPercentage(value, total) {
      if (total === 0) return 0
      return Math.round((value / total) * 100)
    },
    
    getMaxRegistrations() {
      if (!this.stats.daily_registrations || this.stats.daily_registrations.length === 0) {
        return 1
      }
      return Math.max(...this.stats.daily_registrations.map(day => day.count))
    },
    
    getBarHeight(value, max) {
      if (max === 0) return 0
      return Math.max((value / max) * 100, 5) // 最小高度5%
    },
    
    formatChartDate(dateString) {
      const date = new Date(dateString)
      return `${date.getMonth() + 1}/${date.getDate()}`
    },
    
    getRankClass(index) {
      if (index === 0) return 'gold'
      if (index === 1) return 'silver'
      if (index === 2) return 'bronze'
      return ''
    }
  }
}
</script>

<style scoped>
.user-stats {
  padding: 20px;
  background: #f8f9fa;
  min-height: 100vh;
}

.stats-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.stats-title {
  margin: 0;
  color: #333;
  font-size: 24px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 10px;
}

.stats-actions {
  display: flex;
  gap: 10px;
}

.loading-state, .error-state {
  text-align: center;
  padding: 60px 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.spinner {
  width: 50px;
  height: 50px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 20px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.spinning {
  animation: spin 1s linear infinite;
}

.error-icon {
  font-size: 48px;
  color: #f44336;
  margin-bottom: 20px;
}

.stats-content {
  display: flex;
  flex-direction: column;
  gap: 30px;
}

.stats-section {
  background: white;
  border-radius: 8px;
  padding: 25px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.section-title {
  margin: 0 0 20px 0;
  color: #333;
  font-size: 18px;
  font-weight: 600;
  padding-bottom: 10px;
  border-bottom: 2px solid #e0e0e0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 20px;
  border-radius: 8px;
  border-left: 4px solid;
  background: #f8f9fa;
}

.stat-card.primary {
  border-left-color: #2196f3;
  background: linear-gradient(135deg, #e3f2fd 0%, #f8f9fa 100%);
}

.stat-card.success {
  border-left-color: #4caf50;
  background: linear-gradient(135deg, #e8f5e8 0%, #f8f9fa 100%);
}

.stat-card.warning {
  border-left-color: #ff9800;
  background: linear-gradient(135deg, #fff3e0 0%, #f8f9fa 100%);
}

.stat-card.info {
  border-left-color: #9c27b0;
  background: linear-gradient(135deg, #f3e5f5 0%, #f8f9fa 100%);
}

.stat-icon {
  font-size: 32px;
  opacity: 0.8;
}

.stat-content {
  flex: 1;
}

.stat-number {
  font-size: 28px;
  font-weight: 700;
  color: #333;
  line-height: 1;
}

.stat-label {
  font-size: 14px;
  color: #666;
  margin-top: 4px;
}

.stat-percentage {
  font-size: 12px;
  color: #888;
  margin-top: 2px;
}

.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
}

.activity-card {
  padding: 20px;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
}

.activity-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.activity-header h5 {
  margin: 0;
  color: #333;
  font-size: 16px;
  font-weight: 600;
}

.activity-count {
  font-size: 24px;
  font-weight: 700;
  color: #2196f3;
}

.activity-desc {
  font-size: 14px;
  color: #666;
  line-height: 1.4;
}

.chart-container {
  padding: 20px;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
}

.registration-chart {
  width: 100%;
}

.chart-bars {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  height: 200px;
  margin-bottom: 10px;
  padding: 0 10px;
}

.chart-bar {
  flex: 1;
  background: linear-gradient(to top, #2196f3, #64b5f6);
  border-radius: 4px 4px 0 0;
  min-height: 10px;
  position: relative;
  cursor: pointer;
  transition: all 0.3s;
}

.chart-bar:hover {
  background: linear-gradient(to top, #1976d2, #42a5f5);
  transform: translateY(-2px);
}

.bar-value {
  position: absolute;
  top: -25px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 12px;
  font-weight: 600;
  color: #333;
  white-space: nowrap;
}

.chart-labels {
  display: flex;
  gap: 8px;
  padding: 0 10px;
}

.chart-label {
  flex: 1;
  text-align: center;
  font-size: 12px;
  color: #666;
}

.empty-chart, .empty-ranking {
  text-align: center;
  padding: 40px;
  color: #666;
  font-style: italic;
}

.content-ranking {
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  overflow: hidden;
}

.ranking-header {
  display: grid;
  grid-template-columns: 60px 1fr 80px 80px 80px 100px;
  gap: 15px;
  padding: 15px 20px;
  background: #f8f9fa;
  border-bottom: 1px solid #e0e0e0;
  font-weight: 600;
  color: #333;
  font-size: 14px;
}

.ranking-list {
  max-height: 400px;
  overflow-y: auto;
}

.ranking-item {
  display: grid;
  grid-template-columns: 60px 1fr 80px 80px 80px 100px;
  gap: 15px;
  padding: 15px 20px;
  border-bottom: 1px solid #f0f0f0;
  align-items: center;
  transition: background-color 0.2s;
}

.ranking-item:hover {
  background: #f8f9fa;
}

.ranking-item.top-user {
  background: linear-gradient(135deg, #fff9c4 0%, #ffffff 100%);
}

.rank-number {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  font-weight: 700;
  font-size: 14px;
}

.rank-number.gold {
  background: #ffd700;
  color: #b8860b;
}

.rank-number.silver {
  background: #c0c0c0;
  color: #696969;
}

.rank-number.bronze {
  background: #cd7f32;
  color: #8b4513;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  object-fit: cover;
}

.username {
  font-weight: 500;
  color: #333;
}

.content-col, .total-col {
  text-align: center;
  font-weight: 500;
  color: #666;
}

.total-content {
  font-weight: 700;
  color: #2196f3;
  font-size: 16px;
}

/* 按钮样式 */
.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  transition: all 0.2s;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-primary {
  background: #2196f3;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #1976d2;
}

/* 图标样式 */
.icon-chart::before { content: '📊'; }
.icon-refresh::before { content: '🔄'; }
.icon-users::before { content: '👥'; }
.icon-user-check::before { content: '✅'; }
.icon-user-x::before { content: '❌'; }
.icon-crown::before { content: '👑'; }
.icon-alert::before { content: '⚠️'; }

/* 响应式设计 */
@media (max-width: 1024px) {
  .stats-grid {
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  }
  
  .activity-grid {
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  }
  
  .ranking-header, .ranking-item {
    grid-template-columns: 50px 1fr 60px 60px 60px 80px;
    gap: 10px;
    padding: 12px 15px;
  }
}

@media (max-width: 768px) {
  .user-stats {
    padding: 15px;
  }
  
  .stats-header {
    flex-direction: column;
    gap: 15px;
    align-items: flex-start;
  }
  
  .stats-title {
    font-size: 20px;
  }
  
  .stats-grid {
    grid-template-columns: 1fr;
  }
  
  .activity-grid {
    grid-template-columns: 1fr;
  }
  
  .stat-card {
    flex-direction: column;
    text-align: center;
    gap: 10px;
  }
  
  .chart-bars {
    height: 150px;
  }
  
  .ranking-header, .ranking-item {
    grid-template-columns: 40px 1fr 50px 50px 50px 60px;
    gap: 8px;
    padding: 10px;
    font-size: 12px;
  }
  
  .user-avatar {
    width: 24px;
    height: 24px;
  }
  
  .username {
    font-size: 12px;
  }
}
</style>