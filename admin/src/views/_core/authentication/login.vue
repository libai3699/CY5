<script lang="ts" setup>
import { reactive, ref } from 'vue';

import {
  ElButton,
  ElCard,
  ElForm,
  ElFormItem,
  ElInput,
  ElMessage,
} from 'element-plus';
import 'element-plus/dist/index.css';

import { useAuthStore } from '#/store';

defineOptions({ name: 'Login' });

const authStore = useAuthStore();

const form = reactive({
  password: 'admin123456',
  username: 'admin',
});

// 默认账号密码已填入，直接点登录即可

const loading = ref(false);

async function onSubmit() {
  loading.value = true;
  try {
    await authStore.authLogin({
      password: form.password,
      username: form.username,
    });
  } catch {
    ElMessage.error('登录失败');
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <main class="cy-login-page">
    <section class="cy-login-visual">
      <div>
        <h1>CY VPN Admin</h1>
        <p>VPN service management</p>
      </div>
    </section>

    <section class="cy-login-panel">
      <ElCard class="cy-login-card" shadow="never">
        <div class="cy-login-title">
          <h2>后台登录</h2>
          <p>账号：admin，密码：admin123456</p>
        </div>

        <ElForm :model="form" label-position="top" @submit.prevent>
          <ElFormItem label="用户名">
            <ElInput v-model="form.username" size="large" />
          </ElFormItem>
          <ElFormItem label="密码">
            <ElInput
              v-model="form.password"
              show-password
              size="large"
              type="password"
            />
          </ElFormItem>
          <ElButton
            class="cy-login-button"
            :loading="loading || authStore.loginLoading"
            native-type="button"
            size="large"
            type="primary"
            @click="onSubmit"
          >
            登录后台
          </ElButton>
        </ElForm>
      </ElCard>
    </section>
  </main>
</template>

<style scoped>
.cy-login-page {
  display: grid;
  width: 100vw;
  min-width: 100vw;
  height: 100vh;
  min-height: 100vh;
  grid-template-columns: minmax(0, 1fr) 460px;
  overflow: hidden;
  background: #0f172a;
}

.cy-login-visual {
  display: flex;
  align-items: center;
  padding: 64px;
  color: #f8fafc;
  background:
    linear-gradient(135deg, rgb(15 23 42 / 92%), rgb(30 64 175 / 72%)),
    url('/logo.png') center / cover no-repeat;
}

.cy-login-visual h1 {
  margin: 0;
  font-size: 44px;
  font-weight: 700;
  line-height: 1.1;
}

.cy-login-visual p {
  margin: 16px 0 0;
  color: #cbd5e1;
  font-size: 18px;
}

.cy-login-panel {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100vh;
  padding: 32px;
  background: #f8fafc;
}

.cy-login-card {
  width: 100%;
  max-width: 360px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}

.cy-login-title {
  margin-bottom: 24px;
}

.cy-login-title h2 {
  margin: 0;
  color: #0f172a;
  font-size: 24px;
  font-weight: 700;
}

.cy-login-title p {
  margin: 8px 0 0;
  color: #64748b;
  font-size: 14px;
}

.cy-login-button {
  width: 100%;
  margin-top: 8px;
}

@media (width <= 768px) {
  .cy-login-page {
    grid-template-columns: 1fr;
  }

  .cy-login-visual {
    display: none;
  }

  .cy-login-panel {
    padding: 24px;
  }
}
</style>
