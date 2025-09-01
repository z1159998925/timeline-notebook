<template>
  <div class="user-management">
    <!-- 页面标题和操作栏 -->
    <div class="header-section">
      <h2 class="page-title">用户管理</h2>
      <div class="action-buttons">
        <button @click="refreshUsers" class="btn btn-primary">
          <i class="icon-refresh"></i> 刷新
        </button>
        <button @click="exportUsers" class="btn btn-secondary">
          <i class="icon-download"></i> 导出
        </button>
      </div>
    </div>

    <!-- 搜索和筛选区域 -->
    <div class="filter-section">
      <div class="search-box">
        <input 
          v-model="searchQuery" 
          @input="handleSearch"
          type="text" 
          placeholder="搜索用户名或邮箱..."
          class="search-input"
        >
        <i class="icon-search"></i>
      </div>
      
      <div class="filter-controls">
        <select v-model="roleFilter" @change="handleFilter" class="filter-select">
          <option value="">所有角色</option>
          <option value="admin">管理员</option>
          <option value="user">普通用户</option>
        </select>
        
        <select v-model="statusFilter" @change="handleFilter" class="filter-select">
          <option value="">所有状态</option>
          <option value="active">活跃</option>
          <option value="inactive">禁用</option>
        </select>
      </div>
    </div>

    <!-- 批量操作区域 -->
    <div v-if="selectedUsers.length > 0" class="batch-actions">
      <div class="selected-info">
        已选择 {{ selectedUsers.length }} 个用户
      </div>
      <div class="batch-buttons">
        <button @click="batchActivate" class="btn btn-success">
          <i class="icon-check"></i> 批量启用
        </button>
        <button @click="batchDeactivate" class="btn btn-warning">
          <i class="icon-x"></i> 批量禁用
        </button>
        <button @click="batchDelete" class="btn btn-danger">
          <i class="icon-trash"></i> 批量删除
        </button>
      </div>
    </div>

    <!-- 用户列表 -->
    <div class="user-list">
      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>加载中...</p>
      </div>
      
      <div v-else-if="users.length === 0" class="empty-state">
        <p>暂无用户数据</p>
      </div>
      
      <div v-else class="user-table">
        <div class="table-header">
          <div class="header-cell checkbox-cell">
            <input 
              type="checkbox" 
              :checked="isAllSelected"
              @change="toggleSelectAll"
              class="checkbox"
            >
          </div>
          <div class="header-cell">用户信息</div>
          <div class="header-cell">角色</div>
          <div class="header-cell">状态</div>
          <div class="header-cell">注册时间</div>
          <div class="header-cell">最后登录</div>
          <div class="header-cell">内容统计</div>
          <div class="header-cell">操作</div>
        </div>
        
        <div 
          v-for="user in users" 
          :key="user.id" 
          class="table-row"
          :class="{ 'selected': selectedUsers.includes(user.id) }"
        >
          <div class="table-cell checkbox-cell">
            <input 
              type="checkbox" 
              :checked="selectedUsers.includes(user.id)"
              @change="toggleUserSelection(user.id)"
              class="checkbox"
            >
          </div>
          
          <div class="table-cell user-info">
            <UserAvatar 
              :avatar-url="user.avatar_url" 
              :username="user.username"
              size="medium"
              class="user-avatar"
            />
            <div class="user-details">
              <div class="username">{{ user.username }}</div>
              <div class="email">{{ user.email || '未设置邮箱' }}</div>
            </div>
          </div>
          
          <div class="table-cell">
            <span class="role-badge" :class="user.role">
              {{ user.role === 'admin' ? '管理员' : '普通用户' }}
            </span>
          </div>
          
          <div class="table-cell">
            <span class="status-badge" :class="{ active: user.is_active, inactive: !user.is_active }">
              {{ user.is_active ? '活跃' : '禁用' }}
            </span>
          </div>
          
          <div class="table-cell">
            <span class="date-text">{{ formatDate(user.created_at) }}</span>
          </div>
          
          <div class="table-cell">
            <span class="date-text">{{ formatDate(user.last_login) || '从未登录' }}</span>
          </div>
          
          <div class="table-cell content-stats">
            <div class="stat-item">
              <span class="stat-label">时光轴:</span>
              <span class="stat-value">{{ user.timeline_count || 0 }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">留言:</span>
              <span class="stat-value">{{ user.message_count || 0 }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">评论:</span>
              <span class="stat-value">{{ user.comment_count || 0 }}</span>
            </div>
          </div>
          
          <div class="table-cell actions">
            <button @click="viewUserDetail(user.id)" class="btn btn-sm btn-info">
              <i class="icon-eye"></i> 详情
            </button>
            <button @click="editUser(user)" class="btn btn-sm btn-primary">
              <i class="icon-edit"></i> 编辑
            </button>
            <button 
              @click="toggleUserStatus(user)"
              class="btn btn-sm"
              :class="user.is_active ? 'btn-warning' : 'btn-success'"
              :disabled="user.role === 'admin'"
            >
              <i :class="user.is_active ? 'icon-pause' : 'icon-play'"></i>
              {{ user.is_active ? '禁用' : '启用' }}
            </button>
            <button 
              @click="deleteUser(user)"
              class="btn btn-sm btn-danger"
              :disabled="user.role === 'admin'"
            >
              <i class="icon-trash"></i> 删除
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="totalPages > 1" class="pagination">
      <button 
        @click="changePage(currentPage - 1)"
        :disabled="currentPage === 1"
        class="btn btn-sm btn-secondary"
      >
        上一页
      </button>
      
      <span class="page-info">
        第 {{ currentPage }} 页，共 {{ totalPages }} 页
      </span>
      
      <button 
        @click="changePage(currentPage + 1)"
        :disabled="currentPage === totalPages"
        class="btn btn-sm btn-secondary"
      >
        下一页
      </button>
    </div>

    <!-- 用户详情弹窗 -->
    <UserDetail 
      v-if="showUserDetail"
      :user-id="selectedUserId"
      @close="closeUserDetail"
      @refresh="refreshUsers"
    />

    <!-- 用户编辑弹窗 -->
    <UserEdit 
      v-if="showUserEdit"
      :user="editingUser"
      @close="closeUserEdit"
      @refresh="refreshUsers"
    />
  </div>
</template>

<script>
import UserDetail from './UserDetail.vue'
import UserEdit from './UserEdit.vue'
import UserAvatar from './UserAvatar.vue'

export default {
  name: 'UserManagement',
  components: {
    UserDetail,
    UserEdit,
    UserAvatar
  },
  data() {
    return {
      users: [],
      loading: false,
      searchQuery: '',
      roleFilter: '',
      statusFilter: '',
      selectedUsers: [],
      currentPage: 1,
      pageSize: 20,
      totalUsers: 0,
      totalPages: 0,
      showUserDetail: false,
      selectedUserId: null,
      showUserEdit: false,
      editingUser: null,
      searchTimeout: null
    }
  },
  computed: {
    isAllSelected() {
      return this.users.length > 0 && this.selectedUsers.length === this.users.length
    }
  },
  mounted() {
    this.loadUsers()
  },
  methods: {
    async loadUsers() {
      this.loading = true
      try {
        const params = new URLSearchParams({
          page: this.currentPage,
          page_size: this.pageSize
        })
        
        if (this.searchQuery) {
          params.append('search', this.searchQuery)
        }
        if (this.roleFilter) {
          params.append('role', this.roleFilter)
        }
        if (this.statusFilter) {
          params.append('status', this.statusFilter)
        }
        
        const response = await fetch(`/api/admin/users?${params}`, {
          credentials: 'include'
        })
        
        if (response.ok) {
          const data = await response.json()
          this.users = data.users
          this.totalUsers = data.total
          this.totalPages = data.pages
          this.currentPage = data.current_page
        } else {
          console.error('加载用户列表失败')
        }
      } catch (error) {
        console.error('加载用户列表时发生错误:', error)
      } finally {
        this.loading = false
      }
    },
    
    handleSearch() {
      if (this.searchTimeout) {
        clearTimeout(this.searchTimeout)
      }
      this.searchTimeout = setTimeout(() => {
        this.currentPage = 1
        this.loadUsers()
      }, 500)
    },
    
    handleFilter() {
      this.currentPage = 1
      this.loadUsers()
    },
    
    refreshUsers() {
      this.selectedUsers = []
      this.loadUsers()
    },
    
    changePage(page) {
      if (page >= 1 && page <= this.totalPages) {
        this.currentPage = page
        this.loadUsers()
      }
    },
    
    toggleSelectAll() {
      if (this.isAllSelected) {
        this.selectedUsers = []
      } else {
        this.selectedUsers = this.users.map(user => user.id)
      }
    },
    
    toggleUserSelection(userId) {
      const index = this.selectedUsers.indexOf(userId)
      if (index > -1) {
        this.selectedUsers.splice(index, 1)
      } else {
        this.selectedUsers.push(userId)
      }
    },
    
    async toggleUserStatus(user) {
      try {
        const response = await fetch(`/api/admin/users/${user.id}/toggle-status`, {
          method: 'POST',
          credentials: 'include'
        })
        
        if (response.ok) {
          const data = await response.json()
          user.is_active = data.is_active
          alert(data.message)
        } else {
          const error = await response.json()
          alert(error.message)
        }
      } catch (error) {
        console.error('切换用户状态时发生错误:', error)
        alert('操作失败')
      }
    },
    
    async deleteUser(user) {
      if (!confirm(`确定要删除用户 "${user.username}" 吗？此操作不可恢复。`)) {
        return
      }
      
      try {
        const response = await fetch(`/api/admin/users/${user.id}`, {
          method: 'DELETE',
          credentials: 'include'
        })
        
        if (response.ok) {
          alert('用户删除成功')
          this.refreshUsers()
        } else {
          const error = await response.json()
          alert(error.message)
        }
      } catch (error) {
        console.error('删除用户时发生错误:', error)
        alert('删除失败')
      }
    },
    
    async batchOperation(action) {
      if (this.selectedUsers.length === 0) {
        alert('请先选择用户')
        return
      }
      
      let confirmMessage = ''
      switch (action) {
        case 'activate':
          confirmMessage = `确定要启用选中的 ${this.selectedUsers.length} 个用户吗？`
          break
        case 'deactivate':
          confirmMessage = `确定要禁用选中的 ${this.selectedUsers.length} 个用户吗？`
          break
        case 'delete':
          confirmMessage = `确定要删除选中的 ${this.selectedUsers.length} 个用户吗？此操作不可恢复。`
          break
      }
      
      if (!confirm(confirmMessage)) {
        return
      }
      
      try {
        const response = await fetch('/api/admin/users/batch', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          credentials: 'include',
          body: JSON.stringify({
            user_ids: this.selectedUsers,
            action: action
          })
        })
        
        if (response.ok) {
          const data = await response.json()
          alert(data.message)
          if (data.errors && data.errors.length > 0) {
            console.warn('批量操作警告:', data.errors)
          }
          this.selectedUsers = []
          this.refreshUsers()
        } else {
          const error = await response.json()
          alert(error.message)
        }
      } catch (error) {
        console.error('批量操作时发生错误:', error)
        alert('操作失败')
      }
    },
    
    batchActivate() {
      this.batchOperation('activate')
    },
    
    batchDeactivate() {
      this.batchOperation('deactivate')
    },
    
    batchDelete() {
      this.batchOperation('delete')
    },
    
    viewUserDetail(userId) {
      this.selectedUserId = userId
      this.showUserDetail = true
    },
    
    closeUserDetail() {
      this.showUserDetail = false
      this.selectedUserId = null
    },
    
    editUser(user) {
      this.editingUser = { ...user }
      this.showUserEdit = true
    },
    
    closeUserEdit() {
      this.showUserEdit = false
      this.editingUser = null
    },
    
    exportUsers() {
      // 导出用户数据功能
      const csvContent = this.generateCSV()
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const link = document.createElement('a')
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `users_${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
    },
    
    generateCSV() {
      const headers = ['用户ID', '用户名', '邮箱', '角色', '状态', '注册时间', '最后登录', '时光轴数量', '留言数量', '评论数量']
      const rows = this.users.map(user => [
        user.id,
        user.username,
        user.email || '',
        user.role === 'admin' ? '管理员' : '普通用户',
        user.is_active ? '活跃' : '禁用',
        this.formatDate(user.created_at),
        this.formatDate(user.last_login) || '从未登录',
        user.timeline_count || 0,
        user.message_count || 0,
        user.comment_count || 0
      ])
      
      return [headers, ...rows].map(row => row.join(',')).join('\n')
    },
    
    formatDate(dateString) {
      if (!dateString) return ''
      const date = new Date(dateString)
      return date.toLocaleString('zh-CN')
    }
  }
}
</script>

<style scoped>
.user-management {
  padding: 20px;
  background: #f8f9fa;
  min-height: 100vh;
}

.header-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.page-title {
  margin: 0;
  color: #333;
  font-size: 24px;
  font-weight: 600;
}

.action-buttons {
  display: flex;
  gap: 10px;
}

.filter-section {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.search-box {
  position: relative;
  flex: 1;
}

.search-input {
  width: 100%;
  padding: 10px 40px 10px 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 14px;
}

.search-box .icon-search {
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  color: #666;
}

.filter-controls {
  display: flex;
  gap: 10px;
}

.filter-select {
  padding: 10px 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 14px;
  min-width: 120px;
}

.batch-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 15px 20px;
  background: #e3f2fd;
  border-radius: 8px;
  border-left: 4px solid #2196f3;
}

.selected-info {
  font-weight: 500;
  color: #1976d2;
}

.batch-buttons {
  display: flex;
  gap: 10px;
}

.user-list {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
}

.loading-state, .empty-state {
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

.user-table {
  width: 100%;
}

.table-header {
  display: grid;
  grid-template-columns: 50px 200px 100px 80px 120px 120px 150px 200px;
  background: #f5f5f5;
  border-bottom: 1px solid #ddd;
  font-weight: 600;
  color: #333;
}

.table-row {
  display: grid;
  grid-template-columns: 50px 200px 100px 80px 120px 120px 150px 200px;
  border-bottom: 1px solid #eee;
  transition: background-color 0.2s;
}

.table-row:hover {
  background: #f9f9f9;
}

.table-row.selected {
  background: #e3f2fd;
}

.header-cell, .table-cell {
  padding: 12px 8px;
  display: flex;
  align-items: center;
  font-size: 14px;
}

.checkbox-cell {
  justify-content: center;
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
  overflow: hidden;
}

.avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.user-details {
  flex: 1;
}

.username {
  font-weight: 500;
  color: #333;
}

.email {
  font-size: 12px;
  color: #666;
  margin-top: 2px;
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

.date-text {
  font-size: 12px;
  color: #666;
}

.content-stats {
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
}

.stat-item {
  display: flex;
  gap: 4px;
  font-size: 12px;
}

.stat-label {
  color: #666;
}

.stat-value {
  font-weight: 500;
  color: #333;
}

.actions {
  gap: 5px;
  flex-wrap: wrap;
}

.pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 20px;
  margin-top: 20px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.page-info {
  font-size: 14px;
  color: #666;
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

.btn-info {
  background: #00bcd4;
  color: white;
}

.btn-info:hover:not(:disabled) {
  background: #0097a7;
}

/* 图标样式 */
.icon-refresh::before { content: '🔄'; }
.icon-download::before { content: '📥'; }
.icon-search::before { content: '🔍'; }
.icon-check::before { content: '✓'; }
.icon-x::before { content: '✕'; }
.icon-trash::before { content: '🗑️'; }
.icon-eye::before { content: '👁️'; }
.icon-edit::before { content: '✏️'; }
.icon-pause::before { content: '⏸️'; }
.icon-play::before { content: '▶️'; }

.checkbox {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

/* 响应式设计 */
@media (max-width: 1200px) {
  .table-header, .table-row {
    grid-template-columns: 50px 180px 80px 70px 100px 100px 120px 180px;
  }
}

@media (max-width: 768px) {
  .filter-section {
    flex-direction: column;
    gap: 10px;
  }
  
  .batch-actions {
    flex-direction: column;
    gap: 10px;
    align-items: stretch;
  }
  
  .table-header, .table-row {
    grid-template-columns: 1fr;
    grid-template-rows: repeat(8, auto);
  }
  
  .header-cell, .table-cell {
    border-bottom: 1px solid #eee;
    justify-content: space-between;
  }
  
  .header-cell::before, .table-cell::before {
    content: attr(data-label);
    font-weight: 600;
    color: #666;
  }
}
</style>