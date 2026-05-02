<script lang="ts" setup>
import { ref, onMounted } from 'vue';
import { getStats, type Stats } from '#/api/admin/stats';

const stats = ref<Stats>({ total_users: 0, total_devices: 0, active_orders: 0, today_new: 0 });

onMounted(async () => {
  try {
    stats.value = await getStats();
  } catch {}
});
</script>

<template>
  <div class="p-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
      <a-card>
        <a-statistic title="用户总数" :value="stats.total_users" prefix-icon="carbon:user-multiple" />
      </a-card>
      <a-card>
        <a-statistic title="设备总数" :value="stats.total_devices" />
      </a-card>
      <a-card>
        <a-statistic title="活跃套餐" :value="stats.active_orders" />
      </a-card>
      <a-card>
        <a-statistic title="今日新增" :value="stats.today_new" />
      </a-card>
    </div>
  </div>
</template>
