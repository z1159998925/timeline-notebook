<template>
  <div class="permission-edit-modal" @click="closeModal">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>编辑用户权限</h3>
        <button @click="closeModal" class="close-btn">
          <i class="icon-x"></i>
        </button>
      </div>
      
      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>加载中...</p>
      </div>
      
      <div v-else class="modal-body">
        <div class="permission-info">
          <p class="info-text">
            <i class="icon-info"></i>
            为用户分配相应的权限，权限将决定用户可以执行的操作。
          </p>
        </div>
        
        <div class="permissions-container">
          <div v-if="groupedPermissions.length === 0" class="empty-state">
            <p>暂无可用权限</p>
          </div>
          
          <div v-else>
            <div 
              v-for="group in groupedPermissions" 
              :key="group.category"
              class="permission-group"
            >
              <div class="group-header">
                <h4 class="group-title">{{ getCategoryName(group.category) }}</h4>
                <div class="group-actions">
                  <button 
                    @click="toggleGroupSelection(group.category)"
                    class="btn btn-sm btn-outline"
                  >
                    {{ isGroupSelected(group.category) ? '取消全选' : '全选' }}
                  </button>
                </div>
              </div>
              
              <div class="permissions-grid">
                <div 
                  v-for="permission in group.permissions" 
                  :key="permission.id"
                  class="permission-item"
                  :class="{ selected: isPermissionSelected(permission.id) }"
                  @click="togglePermission(permission.id)"
                >
                  <div class="permission-checkbox">
                    <input 
                      type="checkbox"
                      :checked="isPermissionSelected(permission.id)"
                      @change="togglePermission(permission.id)"
                      @click.stop
                    >
                  </div>
                  <div class="permission-info">
                    <div class="permission-name">{{ permission.name }}</div>
                    <div class="permission-desc">{{ permission.description }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button @click="closeModal" class="btn btn-secondary">
          取消
        </button>
        <button @click="savePermissions" class="btn btn-primary" :disabled="saving">
          <i v-if="saving" class="icon-loading"></i>
          <i v-else class="icon-save"></i>
          {{ saving ? '保存中...' : '保存权限' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'PermissionEdit',
  props: {
    userId: {
      type: Number,
      required: true
    },
    currentPermissions: {
      type: Array,
      default: () => []
    }
  },
  data() {
    return {
      loading: false,
      saving: false,
      allPermissions: [],
      selectedPermissions: new Set()
    }
  },
  computed: {
    groupedPermissions() {
      const groups = {}
      
      this.allPermissions.forEach(permission => {
        const category = permission.category || 'other'
        if (!groups[category]) {
          groups[category] = {
            category,
            permissions: []
          }
        }
        groups[category].permissions.push(permission)
      })
      
      return Object.values(groups).sort((a, b) => {
        const order = ['user', 'content', 'admin', 'system', 'other']
        return order.indexOf(a.category) - order.indexOf(b.category)
      })
    }
  },
  mounted() {
    this.initializePermissions()
    this.loadAllPermissions()
  },
  methods: {
    initializePermissions() {
      // 初始化已选择的权限
      this.currentPermissions.forEach(permission => {
        this.selectedPermissions.add(permission.id)
      })
    },
    
    async loadAllPermissions() {
      this.loading = true
      try {
        const response = await fetch('/api/admin/permissions', {
          credentials: 'include'
        })
        
        if (response.ok) {
          this.allPermissions = await response.json()
        } else {
          console.error('加载权限列表失败')
          alert('加载权限列表失败')
        }
      } catch (error) {
        console.error('加载权限列表时发生错误:', error)
        alert('加载权限列表失败')
      } finally {
        this.loading = false
      }
    },
    
    isPermissionSelected(permissionId) {
      return this.selectedPermissions.has(permissionId)
    },
    
    togglePermission(permissionId) {
      if (this.selectedPermissions.has(permissionId)) {
        this.selectedPermissions.delete(permissionId)
      } else {
        this.selectedPermissions.add(permissionId)
      }
    },
    
    isGroupSelected(category) {
      const group = this.groupedPermissions.find(g => g.category === category)
      if (!group) return false
      
      return group.permissions.every(permission => 
        this.selectedPermissions.has(permission.id)
      )
    },
    
    toggleGroupSelection(category) {
      const group = this.groupedPermissions.find(g => g.category === category)
      if (!group) return
      
      const isSelected = this.isGroupSelected(category)
      
      group.permissions.forEach(permission => {
        if (isSelected) {
          this.selectedPermissions.delete(permission.id)
        } else {
          this.selectedPermissions.add(permission.id)
        }
      })
    },
    
    getCategoryName(category) {
      const categoryNames = {
        'user': '用户管理',
        'content': '内容管理',
        'admin': '系统管理',
        'system': '系统设置',
        'other': '其他权限'
      }
      return categoryNames[category] || category
    },
    
    async savePermissions() {
      this.saving = true
      try {
        const permissionIds = Array.from(this.selectedPermissions)
        
        const response = await fetch(`/api/admin/users/${this.userId}/permissions`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json'
          },
          credentials: 'include',
          body: JSON.stringify({
            permission_ids: permissionIds
          })
        })
        
        if (response.ok) {
          const data = await response.json()
          alert(data.message || '权限更新成功')
          this.$emit('refresh')
          this.closeModal()
        } else {
          const error = await response.json()
          alert(error.message || '权限更新失败')
        }
      } catch (error) {
        console.error('保存权限时发生错误:', error)
        alert('保存权限失败')
      } finally {
        this.saving = false
      }
    },
    
    closeModal() {
      this.$emit('close')
    }
  }
}
</script>

<style scoped>
.permission-edit-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1100;
}

.modal-content {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 700px;
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
  font-size: 18px;
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

.permission-info {
  margin-bottom: 20px;
  padding: 15px;
  background: #e3f2fd;
  border-radius: 6px;
  border-left: 4px solid #2196f3;
}

.info-text {
  margin: 0;
  color: #1565c0;
  display: flex;
  align-items: center;
  gap: 8px;
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: #666;
  font-style: italic;
}

.permission-group {
  margin-bottom: 25px;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  overflow: hidden;
}

.group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px 20px;
  background: #f8f9fa;
  border-bottom: 1px solid #e0e0e0;
}

.group-title {
  margin: 0;
  color: #333;
  font-size: 16px;
  font-weight: 600;
}

.group-actions {
  display: flex;
  gap: 10px;
}

.permissions-grid {
  padding: 15px;
  display: grid;
  gap: 10px;
}

.permission-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px;
  border: 1px solid #e0e0e0;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
  background: white;
}

.permission-item:hover {
  border-color: #2196f3;
  background: #f8f9ff;
}

.permission-item.selected {
  border-color: #2196f3;
  background: #e3f2fd;
}

.permission-checkbox {
  margin-top: 2px;
}

.permission-checkbox input[type="checkbox"] {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.permission-info {
  flex: 1;
}

.permission-name {
  font-weight: 500;
  color: #333;
  margin-bottom: 4px;
}

.permission-desc {
  font-size: 14px;
  color: #666;
  line-height: 1.4;
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

.btn-outline {
  background: transparent;
  color: #2196f3;
  border: 1px solid #2196f3;
}

.btn-outline:hover {
  background: #2196f3;
  color: white;
}

/* 图标样式 */
.icon-x::before { content: '✕'; }
.icon-info::before { content: 'ℹ️'; }
.icon-save::before { content: '💾'; }
.icon-loading::before { 
  content: '⟳'; 
  animation: spin 1s linear infinite;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .modal-content {
    width: 95%;
    max-height: 95vh;
  }
  
  .group-header {
    flex-direction: column;
    gap: 10px;
    align-items: flex-start;
  }
  
  .group-actions {
    width: 100%;
    justify-content: flex-end;
  }
  
  .permission-item {
    flex-direction: column;
    gap: 8px;
  }
  
  .permission-checkbox {
    align-self: flex-start;
  }
  
  .modal-footer {
    flex-direction: column;
    gap: 10px;
  }
  
  .btn {
    width: 100%;
    justify-content: center;
  }
}
</style>