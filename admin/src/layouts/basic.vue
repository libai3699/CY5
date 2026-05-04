<script lang="ts" setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useUserStore } from '../vben-shims/stores';

const router = useRouter();
const userStore = useUserStore();

const username = computed(() => 'Admin');

async function handleLogout() {
  userStore.clearToken();
  router.push('/login');
}
</script>

<template>
  <div class="layout-container">
    <div class="layout-header">
      <div class="header-left">
        <h2>9点9 Admin</h2>
      </div>
      <div class="header-right">
        <span class="username">{{ username }}</span>
        <button @click="handleLogout" class="logout-btn">退出登录</button>
      </div>
    </div>
    <div class="layout-content">
      <router-view />
    </div>
  </div>
</template>

<style scoped>
.layout-container {
  min-height: 100vh;
  background: #f0f2f5;
}

.layout-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 24px;
  height: 64px;
  background: #fff;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

.header-left h2 {
  margin: 0;
  color: #1890ff;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.username {
  color: #666;
}

.logout-btn {
  padding: 6px 16px;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  transition: all 0.3s;
}

.logout-btn:hover {
  color: #1890ff;
  border-color: #1890ff;
}

.layout-content {
  padding: 24px;
  min-height: calc(100vh - 64px);
}
</style>
