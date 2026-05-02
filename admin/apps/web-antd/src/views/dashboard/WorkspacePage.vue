<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { getStats, type Stats } from '#/api/admin/stats';

const stats = ref<Stats>({ total_users: 0, total_devices: 0, active_orders: 0, today_new: 0 });

onMounted(async () => {
  try { stats.value = await getStats(); } catch {}
});
</script>

<template>
  <div class="p-5">
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="text-gray-500 text-sm">用户总数</div>
          <div class="text-3xl font-bold mt-2">{{ stats.total_users }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="text-gray-500 text-sm">设备总数</div>
          <div class="text-3xl font-bold mt-2">{{ stats.total_devices }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="text-gray-500 text-sm">活跃套餐</div>
          <div class="text-3xl font-bold mt-2">{{ stats.active_orders }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="text-gray-500 text-sm">今日新增</div>
          <div class="text-3xl font-bold mt-2">{{ stats.today_new }}</div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
