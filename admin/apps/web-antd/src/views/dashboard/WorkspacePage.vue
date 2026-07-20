<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { getStats, type Stats } from '#/api/admin/stats';

defineOptions({ name: 'WorkspacePage' });

const loading = ref(true);
const stats = ref<Stats>({
  today_new: 0,
  today_income_cents: 0,
  total_members: 0,
  online_members: 0,
  login_within_3_days: 0,
});

const statCards = [
  { key: 'today_new', label: '今日新增', format: (v: number) => String(v) },
  {
    key: 'today_income_cents',
    label: '今日入账',
    format: (v: number) => `¥${(v / 100).toFixed(2)}`,
  },
  { key: 'total_members', label: '总会员', format: (v: number) => String(v) },
  { key: 'online_members', label: '在线会员', format: (v: number) => String(v) },
  {
    key: 'login_within_3_days',
    label: '三天内登录',
    format: (v: number) => String(v),
  },
] as const;

async function loadStats() {
  loading.value = true;
  try {
    stats.value = await getStats();
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  loadStats();
});
</script>

<template>
  <div class="workspace-page">
    <el-card v-loading="loading">
      <template #header>
        <div class="card-header">
          <span>数据概览</span>
          <el-button link type="primary" @click="loadStats">刷新</el-button>
        </div>
      </template>
      <div class="stats-row">
        <div v-for="item in statCards" :key="item.key" class="stat-card">
          <div class="stat-label">{{ item.label }}</div>
          <div class="stat-value">{{ item.format(stats[item.key]) }}</div>
        </div>
      </div>
    </el-card>

    <el-card class="welcome-card">
      <template #header>
        <div class="card-header">
          <span>欢迎使用 9点9 VPN 管理后台</span>
        </div>
      </template>
      <div class="welcome-content">
        <h2>系统功能</h2>
        <el-row :gutter="20">
          <el-col :span="8">
            <el-card shadow="hover">
              <h3>用户管理</h3>
              <p>管理用户账号、设备、时长等</p>
              <el-button type="primary" @click="$router.push('/users/list')">进入</el-button>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <h3>套餐管理</h3>
              <p>管理套餐、订单等</p>
              <el-button type="primary" @click="$router.push('/plans/list')">进入</el-button>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <h3>内容管理</h3>
              <p>管理语录、支付配置等</p>
              <el-button type="primary" @click="$router.push('/content/quotes')">进入</el-button>
            </el-card>
          </el-col>
        </el-row>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.workspace-page {
  padding: 20px;
}

.welcome-card {
  margin-top: 20px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 18px;
  font-weight: bold;
}

.stats-row {
  display: flex;
  gap: 16px;
}

.stat-card {
  flex: 1;
  min-width: 0;
  padding: 20px 16px;
  text-align: center;
  background: linear-gradient(180deg, #f8fafc 0%, #ffffff 100%);
  border: 1px solid #ebeef5;
  border-radius: 8px;
}

.stat-label {
  margin-bottom: 12px;
  color: #909399;
  font-size: 14px;
}

.stat-value {
  color: #303133;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}

.welcome-content {
  padding: 20px 0;
}

.welcome-content h2 {
  margin-bottom: 20px;
  color: #333;
}

.welcome-content h3 {
  margin-bottom: 10px;
  color: #666;
}

.welcome-content p {
  margin-bottom: 15px;
  color: #999;
}
</style>
