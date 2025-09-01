<template>
  <div 
    class="default-avatar"
    :class="sizeClass"
    :style="{ backgroundColor: avatarColor }"
  >
    {{ avatarLetter }}
  </div>
</template>

<script>
export default {
  name: 'DefaultAvatar',
  props: {
    username: {
      type: String,
      required: true
    },
    size: {
      type: String,
      default: 'medium',
      validator: value => ['small', 'medium', 'large'].includes(value)
    }
  },
  computed: {
    avatarLetter() {
      return this.username ? this.username.charAt(0).toUpperCase() : '?'
    },
    avatarColor() {
      // 根据用户名首字母生成固定颜色
      const colors = [
        '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
        '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
        '#F8C471', '#82E0AA', '#F1948A', '#85C1E9', '#D7BDE2'
      ]
      const charCode = this.avatarLetter.charCodeAt(0)
      return colors[charCode % colors.length]
    },
    sizeClass() {
      return `avatar-${this.size}`
    }
  }
}
</script>

<style scoped>
.default-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: white;
  font-weight: bold;
  text-align: center;
  user-select: none;
  flex-shrink: 0;
}

.avatar-small {
  width: 32px;
  height: 32px;
  font-size: 14px;
}

.avatar-medium {
  width: 48px;
  height: 48px;
  font-size: 18px;
}

.avatar-large {
  width: 64px;
  height: 64px;
  font-size: 24px;
}
</style>