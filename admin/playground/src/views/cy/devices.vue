<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Input, Space, Table } from 'ant-design-vue';

import { getDevices, type DeviceItem } from '#/api';

const loading = ref(false);
const rows = ref<DeviceItem[]>([]);
const keyword = ref('');
const pagination = reactive({ current: 1, pageSize: 20, total: 0 });
const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'device_id', title: '设备ID', ellipsis: true },
  { dataIndex: 'user_id', title: '用户ID', width: 100 },
  { dataIndex: 'brand', title: '品牌' },
  { dataIndex: 'model', title: '型号' },
  { dataIndex: 'os_version', title: '系统' },
  { dataIndex: 'app_version', title: 'App版本' },
  { dataIndex: 'last_ip', title: '最后IP' },
  { dataIndex: 'last_seen_at', title: '最后活跃' },
];

async function load() {
  loading.value = true;
  try {
    const res = await getDevices({ keyword: keyword.value, page: pagination.current, size: pagination.pageSize });
    rows.value = res.list;
    pagination.total = res.total;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <Page title="设备管理">
    <Space class="mb-4">
      <Input v-model:value="keyword" allow-clear placeholder="设备ID/品牌/型号" @press-enter="load" />
      <Button @click="load">搜索</Button>
    </Space>
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="pagination" row-key="id" @change="(p)=>{pagination.current=p.current;pagination.pageSize=p.pageSize;load()}" />
  </Page>
</template>
