<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Card, Col, Row, Statistic } from 'ant-design-vue';

import { getStats, type AdminStats } from '#/api';

const stats = ref<AdminStats>({
  active_orders: 0,
  today_new: 0,
  total_devices: 0,
  total_users: 0,
});

onMounted(async () => {
  stats.value = await getStats();
});
</script>

<template>
  <Page title="仪表盘">
    <Row :gutter="[16, 16]">
      <Col :lg="6" :sm="12" :xs="24">
        <Card><Statistic title="用户数" :value="stats.total_users" /></Card>
      </Col>
      <Col :lg="6" :sm="12" :xs="24">
        <Card><Statistic title="设备数" :value="stats.total_devices" /></Card>
      </Col>
      <Col :lg="6" :sm="12" :xs="24">
        <Card><Statistic title="活跃套餐" :value="stats.active_orders" /></Card>
      </Col>
      <Col :lg="6" :sm="12" :xs="24">
        <Card><Statistic title="今日新增" :value="stats.today_new" /></Card>
      </Col>
    </Row>
  </Page>
</template>
