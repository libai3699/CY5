<script lang="ts" setup>
import { onMounted, reactive, ref } from 'vue';

import { captchaApi } from '#/api';
import { useAuthStore } from '#/store';

defineOptions({ name: 'Login' });

const authStore = useAuthStore();
const form = reactive({
  captcha: '',
  password: '',
  username: '',
});
const totpSecret = ref('');
const totpUri = ref('');

async function loadCaptchaSetup() {
  const data = await captchaApi();
  totpSecret.value = data.secret;
  totpUri.value = data.otpauth;
}

async function submit() {
  await authStore.authLogin({ ...form });
}

onMounted(loadCaptchaSetup);
</script>

<template>
  <main class="cy-login-page">
    <section class="cy-login-card">
      <h1>后台登录</h1>
      <p>请输入账号、密码和 Google Authenticator 动态验证码</p>

      <label>
        <span>用户名</span>
        <input v-model="form.username" />
      </label>
      <label>
        <span>密码</span>
        <input v-model="form.password" type="password" />
      </label>
      <label>
        <span>Google 验证码</span>
        <input v-model="form.captcha" maxlength="6" />
      </label>

      <div class="cy-totp-box">
        <div>首次绑定密钥</div>
        <strong>{{ totpSecret }}</strong>
        <small>{{ totpUri }}</small>
      </div>

      <button class="cy-login-button" type="button" :disabled="authStore.loginLoading" @click="submit">
        {{ authStore.loginLoading ? '登录中...' : '登录后台' }}
      </button>
    </section>
  </main>
</template>

<style scoped>
.cy-login-page {
  display: flex;
  min-height: 100vh;
  align-items: center;
  justify-content: center;
  background: #f8fafc;
  padding: 24px;
}

.cy-login-card {
  width: 360px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #fff;
  padding: 28px;
}

.cy-login-card h1 {
  margin: 0;
  color: #0f172a;
  font-size: 24px;
}

.cy-login-card p {
  margin: 8px 0 24px;
  color: #64748b;
  font-size: 14px;
}

.cy-login-card label {
  display: block;
  margin-bottom: 16px;
}

.cy-login-card span {
  display: block;
  margin-bottom: 8px;
  color: #334155;
  font-size: 14px;
}

.cy-login-card input {
  width: 100%;
  height: 40px;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  padding: 0 12px;
  outline: none;
}

.cy-totp-box {
  margin-bottom: 16px;
  border: 1px dashed #cbd5e1;
  border-radius: 8px;
  padding: 12px;
  color: #475569;
  font-size: 12px;
}

.cy-totp-box strong {
  display: block;
  margin: 6px 0;
  color: #0f172a;
  font-size: 14px;
  letter-spacing: 1px;
}

.cy-totp-box small {
  display: block;
  overflow-wrap: anywhere;
}

.cy-login-button {
  width: 100%;
  height: 42px;
  border: 0;
  border-radius: 6px;
  background: #2563eb;
  color: white;
  cursor: pointer;
  font-weight: 600;
}
</style>
