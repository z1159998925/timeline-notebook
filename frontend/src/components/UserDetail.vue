<template>
  <div class="user-detail-modal" @click="closeModal">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>用户详情</h3>
        <button @click="closeModal" class="close-btn">
          <i class="icon-x"></i>
        </button>
      </div>
      
      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>加载中...</p>
      </div>
      
      <div v-else-if="user" class="modal-body">
        <!-- 用户基本信息 -->
        <div class="info-section">
          <h4 class="section-title">基本信息</h4>
          <div class="user-profile">
            <UserAvatar 
              :avatar-url="user.avatar_url" 
              :username="user.username"
              size="large"
              class="user-avatar"
            />
            <div class="user-info">
              <div class="info-row">
                <span class="label">用户名:</span>
                <span class="value">{{ user.username }}</span>
              </div>
              <div class="info-row">
                <span class="label">邮箱:</span>
                <span class="value">{{ user.email || '未设置' }}</span>
              </div>
              <div class="info-row">
                <span class="label">角色:</span>
                <span class="value role-badge" :class="user.role">
                  {{ user.role === 'admin' ? '管理员' : '普通用户' }}
                </span>
              </div>
              <div class="info-row">
                <span class="label">状态:</span>
                <span class="value status-badge" :class="{ active: user.is_active, inactive: !user.is_active }">
                  {{ user.is_active ? '活跃' : '禁用' }}
                </span>
              </div>
              <div class="info-row">
                <span class="label">个人简介:</span>
                <span class="value">{{ user.bio || '暂无简介' }}</span>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 账户信息 -->
        <div class="info-section">
          <h4 class="section-title">账户信息</h4>
          <div class="account-info">
            <div class="info-row">
              <span class="label">注册时间:</span>
              <span class="value">{{ formatDate(user.created_at) }}</span>
            </div>
            <div class="info-row">
              <span class="label">最后更新:</span>
              <span class="value">{{ formatDate(user.updated_at) }}</span>
            </div>
            <div class="info-row">
              <span class="label">最后登录:</span>
              <span class="value">{{ formatDate(user.last_login) || '从未登录' }}</span>
            </div>
            <div class="info-row">
              <span class="label">登录次数:</span>
              <span class="value">{{ user.login_count || 0 }} 次</span>
            </div>
          </div>
        </div>
        
        <!-- 内容统计 -->
        <div class="info-section">
          <h4 class="section-title">内容统计</h4>
          <div class="stats-grid">
            <div class="stat-card">
              <div class="stat-number">{{ user.timeline_count || 0 }}</div>
              <div class="stat-label">时光轴条目</div>
            </div>
            <div class="stat-card">
              <div class="stat-number">{{ user.message_count || 0 }}</div>
              <div class="stat-label">留言</div>
            </div>
            <div class="stat-card">
              <div class="stat-number">{{ user.comment_count || 0 }}</div>
              <div class="stat-label">评论</div>
            </div>
            <div class="stat-card">
              <div class="stat-number">{{ user.total_content || 0 }}</div>
              <div class="stat-label">总内容</div>
            </div>
          </div>
        </div>
        
        <!-- 用户权限 -->
        <div class="info-section">
          <h4 class="section-title">
            用户权限
            <button @click="editPermissions" class="btn btn-sm btn-primary">
              <i class="icon-edit"></i> 编辑权限
            </button>
          </h4>
          <div v-if="user.permissions && user.permissions.length > 0" class="permissions-list">
            <div 
              v-for="permission in user.permissions" 
              :key="permission.id"
              class="permission-item"
            >
              <span class="permission-name">{{ permission.name }}</span>
              <span class="permission-desc">{{ permission.description }}</span>
              <span class="permission-category">{{ permission.category }}</span>
            </div>
          </div>
          <div v-else class="empty-permissions">
            <p>该用户暂无特殊权限</p>
          </div>
        </div>
        
        <!-- 活动记录 -->
        <div class="info-section">
          <h4 class="section-title">最近活动记录</h4>
          <div v-if="user.activities && user.activities.length > 0" class="activities-list">
            <div 
              v-for="activity in user.activities" 
              :key="activity.id"
              class="activity-item"
            >
              <div class="activity-icon" :class="getActivityIconClass(activity.action_type)">
                <i :class="getActivityIcon(activity.action_type)"></i>
              </div>
              <div class="activity-content">
                <div class="activity-description">{{ activity.description }}</div>
                <div class="activity-meta">
                  <span class="activity-time">{{ formatDate(activity.created_at) }}</span>
                  <span class="activity-ip" v-if="activity.ip_address">IP: {{ activity.ip_address }}</span>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="empty-activities">
            <p>暂无活动记录</p>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button @click="closeModal" class="btn btn-secondary">
          关闭
        </button>
        <button @click="editUser" class="btn btn-primary">
          <i class="icon-edit"></i> 编辑用户
        </button>
        <button 
          @click="toggleUserStatus"
          class="btn"
          :class="user && user.is_active ? 'btn-warning' : 'btn-success'"
          :disabled="user && user.role === 'admin'"
        >
          <i :class="user && user.is_active ? 'icon-pause' : 'icon-play'"></i>
          {{ user && user.is_active ? '禁用用户' : '启用用户' }}
        </button>
        <button 
          @click="deleteUser"
          class="btn btn-danger"
          :disabled="user && user.role === 'admin'"
        >
          <i class="icon-trash"></i> 删除用户
        </button>
      </div>
    </div>
    
    <!-- 权限编辑弹窗 -->
    <PermissionEdit 
      v-if="showPermissionEdit"
      :user-id="userId"
      :current-permissions="user ? user.permissions : []"
      @close="closePermissionEdit"
      @refresh="loadUserDetail"
    />
  </div>
</template>

<script>
import PermissionEdit from './PermissionEdit.vue'
import UserAvatar from './UserAvatar.vue'

export default {
  name: 'UserDetail',
  components: {
    PermissionEdit,
    UserAvatar
  },
  props: {
    userId: {
      type: Number,
      required: true
    }
  },
  data() {
    return {
      user: null,
      loading: false,
      showPermissionEdit: false
    }
  },
  mounted() {
    this.loadUserDetail()
  },
  methods: {
    async loadUserDetail() {
      this.loading = true
      try {
        const response = await fetch(`/api/admin/users/${this.userId}`, {
          credentials: 'include'
        })
        
        if (response.ok) {
          this.user = await response.json()
        } else {
          console.error('加载用户详情失败')
          this.closeModal()
        }
      } catch (error) {
        console.error('加载用户详情时发生错误:', error)
        this.closeModal()
      } finally {
        this.loading = false
      }
    },
    
    closeModal() {
      this.$emit('close')
    },
    
    editUser() {
      this.$emit('edit', this.user)
      this.closeModal()
    },
    
    async toggleUserStatus() {
      if (!this.user) return
      
      try {
        const response = await fetch(`/api/admin/users/${this.user.id}/toggle-status`, {
          method: 'POST',
          credentials: 'include'
        })
        
        if (response.ok) {
          const data = await response.json()
          this.user.is_active = data.is_active
          alert(data.message)
          this.$emit('refresh')
        } else {
          const error = await response.json()
          alert(error.message)
        }
      } catch (error) {
        console.error('切换用户状态时发生错误:', error)
        alert('操作失败')
      }
    },
    
    async deleteUser() {
      if (!this.user) return
      
      if (!confirm(`确定要删除用户 "${this.user.username}" 吗？此操作不可恢复。`)) {
        return
      }
      
      try {
        const response = await fetch(`/api/admin/users/${this.user.id}`, {
          method: 'DELETE',
          credentials: 'include'
        })
        
        if (response.ok) {
          alert('用户删除成功')
          this.$emit('refresh')
          this.closeModal()
        } else {
          const error = await response.json()
          alert(error.message)
        }
      } catch (error) {
        console.error('删除用户时发生错误:', error)
        alert('删除失败')
      }
    },
    
    editPermissions() {
      this.showPermissionEdit = true
    },
    
    closePermissionEdit() {
      this.showPermissionEdit = false
    },
    
    formatDate(dateString) {
      if (!dateString) return ''
      const date = new Date(dateString)
      return date.toLocaleString('zh-CN')
    },
    
    getActivityIcon(actionType) {
      const iconMap = {
        'login': 'icon-login',
        'logout': 'icon-logout',
        'register': 'icon-user-plus',
        'profile_update': 'icon-edit',
        'password_change': 'icon-key',
        'admin_update': 'icon-admin',
        'status_change': 'icon-toggle',
        'permission_update': 'icon-shield',
        'batch_operation': 'icon-layers',
        'content_create': 'icon-plus',
        'content_update': 'icon-edit',
        'content_delete': 'icon-trash'
      }
      return iconMap[actionType] || 'icon-activity'
    },
    
    getActivityIconClass(actionType) {
      const classMap = {
        'login': 'success',
        'logout': 'info',
        'register': 'primary',
        'profile_update': 'warning',
        'password_change': 'warning',
        'admin_update': 'danger',
        'status_change': 'warning',
        'permission_update': 'danger',
        'batch_operation': 'info',
        'content_create': 'success',
        'content_update': 'warning',
        'content_delete': 'danger'
      }
      return classMap[actionType] || 'default'
    }
  }
}
</script>

<style scoped>
.user-detail-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 800px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  border-bottom: 1px solid #eee;
  background: #f8f9fa;
}

.modal-header h3 {
  margin: 0;
  color: #333;
  font-size: 20px;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
  color: #666;
  padding: 5px;
  border-radius: 4px;
  transition: background-color 0.2s;
}

.close-btn:hover {
  background: #e9ecef;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
}

.loading-state {
  text-align: center;
  padding: 40px;
  color: #666;
}

.spinner {
  width: 40px;
  height: 40px;
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

.info-section {
  margin-bottom: 30px;
  padding: 20px;
  background: #f8f9fa;
  border-radius: 8px;
  border-left: 4px solid #2196f3;
}

.section-title {
  margin: 0 0 15px 0;
  color: #333;
  font-size: 16px;
  font-weight: 600;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.user-profile {
  display: flex;
  gap: 20px;
  align-items: flex-start;
}

.user-avatar {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
}

.avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.user-info {
  flex: 1;
}

.info-row {
  display: flex;
  margin-bottom: 10px;
  align-items: center;
}

.label {
  font-weight: 500;
  color: #666;
  min-width: 80px;
  margin-right: 10px;
}

.value {
  color: #333;
  flex: 1;
}

.role-badge {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.role-badge.admin {
  background: #ffebee;
  color: #c62828;
}

.role-badge.user {
  background: #e8f5e8;
  color: #2e7d32;
}

.status-badge {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.status-badge.active {
  background: #e8f5e8;
  color: #2e7d32;
}

.status-badge.inactive {
  background: #fff3e0;
  color: #f57c00;
}

.account-info {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 10px;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 15px;
}

.stat-card {
  text-align: center;
  padding: 15px;
  background: white;
  border-radius: 6px;
  border: 1px solid #e0e0e0;
}

.stat-number {
  font-size: 24px;
  font-weight: 600;
  color: #2196f3;
  margin-bottom: 5px;
}

.stat-label {
  font-size: 12px;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.permissions-list {
  display: grid;
  gap: 10px;
}

.permission-item {
  display: grid;
  grid-template-columns: 1fr 2fr auto;
  gap: 10px;
  padding: 10px;
  background: white;
  border-radius: 6px;
  border: 1px solid #e0e0e0;
  align-items: center;
}

.permission-name {
  font-weight: 500;
  color: #333;
}

.permission-desc {
  color: #666;
  font-size: 14px;
}

.permission-category {
  padding: 2px 6px;
  background: #e3f2fd;
  color: #1976d2;
  border-radius: 4px;
  font-size: 12px;
  text-align: center;
}

.empty-permissions, .empty-activities {
  text-align: center;
  padding: 20px;
  color: #666;
  font-style: italic;
}

.activities-list {
  max-height: 300px;
  overflow-y: auto;
}

.activity-item {
  display: flex;
  gap: 12px;
  padding: 12px;
  background: white;
  border-radius: 6px;
  border: 1px solid #e0e0e0;
  margin-bottom: 8px;
}

.activity-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 14px;
}

.activity-icon.success {
  background: #e8f5e8;
  color: #2e7d32;
}

.activity-icon.info {
  background: #e3f2fd;
  color: #1976d2;
}

.activity-icon.warning {
  background: #fff3e0;
  color: #f57c00;
}

.activity-icon.danger {
  background: #ffebee;
  color: #c62828;
}

.activity-icon.primary {
  background: #e8eaf6;
  color: #3f51b5;
}

.activity-icon.default {
  background: #f5f5f5;
  color: #666;
}

.activity-content {
  flex: 1;
}

.activity-description {
  font-weight: 500;
  color: #333;
  margin-bottom: 4px;
}

.activity-meta {
  display: flex;
  gap: 15px;
  font-size: 12px;
  color: #666;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 20px;
  border-top: 1px solid #eee;
  background: #f8f9fa;
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

.btn-sm {
  padding: 4px 8px;
  font-size: 12px;
}

.btn-primary {
  background: #2196f3;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #1976d2;
}

.btn-secondary {
  background: #6c757d;
  color: white;
}

.btn-secondary:hover:not(:disabled) {
  background: #545b62;
}

.btn-success {
  background: #4caf50;
  color: white;
}

.btn-success:hover:not(:disabled) {
  background: #388e3c;
}

.btn-warning {
  background: #ff9800;
  color: white;
}

.btn-warning:hover:not(:disabled) {
  background: #f57c00;
}

.btn-danger {
  background: #f44336;
  color: white;
}

.btn-danger:hover:not(:disabled) {
  background: #d32f2f;
}

/* 图标样式 */
.icon-x::before { content: '✕'; }
.icon-edit::before { content: '✏️'; }
.icon-pause::before { content: '⏸️'; }
.icon-play::before { content: '▶️'; }
.icon-trash::before { content: '🗑️'; }
.icon-login::before { content: '🔑'; }
.icon-logout::before { content: '🚪'; }
.icon-user-plus::before { content: '👤+'; }
.icon-key::before { content: '🔐'; }
.icon-admin::before { content: '👑'; }
.icon-toggle::before { content: '🔄'; }
.icon-shield::before { content: '🛡️'; }
.icon-layers::before { content: '📚'; }
.icon-plus::before { content: '➕'; }
.icon-activity::before { content: '📊'; }

/* 响应式设计 */
@media (max-width: 768px) {
  .modal-content {
    width: 95%;
    max-height: 95vh;
  }
  
  .user-profile {
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  
  .info-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 5px;
  }
  
  .label {
    min-width: auto;
    margin-right: 0;
  }
  
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .permission-item {
    grid-template-columns: 1fr;
    gap: 5px;
  }
  
  .modal-footer {
    flex-wrap: wrap;
    gap: 5px;
  }
  
  .btn {
    flex: 1;
    justify-content: center;
  }
}
</style>