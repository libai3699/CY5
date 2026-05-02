<script lang="ts" setup>
import { useUserStore } from '@vben/stores';
import { preferences } from '@vben/preferences';

const userStore = useUserStore();
</script>

<template>
  <div class="p-5">
    <div class="mb-5 rounded-lg bg-white p-6 shadow">
      <div class="flex items-center">
        <img
          :src="userStore.userInfo?.avatar || preferences.app.defaultAvatar"
          class="h-16 w-16 rounded-full"
          alt="avatar"
        />
        <div class="ml-4">
          <h2 class="text-2xl font-bold">
            早安, {{ userStore.userInfo?.realName || '管理员' }}
          </h2>
          <p class="text-gray-500">开始您一天的工作吧！</p>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
      <div class="rounded-lg bg-white p-6 shadow">
        <div class="text-gray-500">用户总数</div>
        <div class="mt-2 text-3xl font-bold">0</div>
      </div>
      <div class="rounded-lg bg-white p-6 shadow">
        <div class="text-gray-500">设备总数</div>
        <div class="mt-2 text-3xl font-bold">0</div>
      </div>
      <div class="rounded-lg bg-white p-6 shadow">
        <div class="text-gray-500">活跃套餐</div>
        <div class="mt-2 text-3xl font-bold">0</div>
      </div>
      <div class="rounded-lg bg-white p-6 shadow">
        <div class="text-gray-500">今日新增</div>
        <div class="mt-2 text-3xl font-bold">0</div>
      </div>
    </div>

    <div class="mt-5 rounded-lg bg-white p-6 shadow">
      <h3 class="mb-4 text-xl font-bold">欢迎使用 CY VPN 管理后台</h3>
      <p class="text-gray-600">
        这是一个基于 Vue 3 + Vite + TypeScript + Ant Design Vue 的企业级中后台管理系统。
      </p>
      <div class="mt-4">
        <p class="text-gray-600">当前登录账号：{{ userStore.userInfo?.username }}</p>
        <p class="text-gray-600">登录时间：{{ new Date().toLocaleString() }}</p>
      </div>
    </div>
  </div>
</template>
