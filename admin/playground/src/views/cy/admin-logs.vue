<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Table } from 'ant-design-vue';

import { getAdminLogs, type LoginLogItem } from '#/api';

const loading = ref(false);
const rows = ref<LoginLogItem[]>([]);
const pagination = reactive({ current: 1, pageSize: 20, total: 0 });
const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'username', title: '管理员' },
  { dataIndex: 'ip', title: 'IP' },
  { dataIndex: 'user_agent', title: 'User-Agent', ellipsis: true },
  { dataIndex: 'status', title: '状态' },
  { dataIndex: 'created_at', title: '时间' },
];

async function load() {
  loading.value = true;
  try {
    const res = await getAdminLogs({ page: pagination.current, size: pagination.pageSize });
    rows.value = res.list;
    pagination.total = res.total;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <Page title="后台登录日志">
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="pagination" row-key="id" @change="(p)=>{pagination.current=p.current;pagination.pageSize=p.pageSize;load()}">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'status'">{{ record.status === 1 ? '成功' : '失败' }}</template>
      </template>
    </Table>
  </Page>
</template>
