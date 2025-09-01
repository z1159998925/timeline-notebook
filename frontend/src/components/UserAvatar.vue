<template>
  <div class="user-avatar" :class="sizeClass">
    <img 
      v-if="hasValidAvatar"
      :src="avatarUrl" 
      :alt="username"
      class="avatar-image"
      @error="handleImageError"
    >
    <DefaultAvatar 
      v-else
      :username="username"
      :size="size"
    />
  </div>
</template>

<script>
import DefaultAvatar from './DefaultAvatar.vue'

export default {
  name: 'UserAvatar',
  components: {
    DefaultAvatar
  },
  props: {
    username: {
      type: String,
      required: true
    },
    avatarUrl: {
      type: String,
      default: null
    },
    size: {
      type: String,
      default: 'medium',
      validator: value => ['small', 'medium', 'large'].includes(value)
    }
  },
  data() {
    return {
      imageError: false
    }
  },
  computed: {
    hasValidAvatar() {
      return this.avatarUrl && 
             !this.imageError && 
             !this.avatarUrl.includes('/api/avatar/default/') &&
             this.avatarUrl !== '/default-avatar.png'
    },
    sizeClass() {
      return `avatar-${this.size}`
    }
  },
  watch: {
    avatarUrl() {
      // 当头像URL变化时，重置错误状态
      this.imageError = false
    }
  },
  methods: {
    handleImageError() {
      this.imageError = true
    }
  }
}
</script>

<style scoped>
.user-avatar {
  display: inline-block;
  position: relative;
}

.avatar-image {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
}

.avatar-small {
  width: 32px;
  height: 32px;
}

.avatar-medium {
  width: 48px;
  height: 48px;
}

.avatar-large {
  width: 64px;
  height: 64px;
}
</style>