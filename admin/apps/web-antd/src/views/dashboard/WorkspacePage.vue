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
  </div>
</template>

<style scoped>
.workspace-page {
  padding: 20px;
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
</style>
