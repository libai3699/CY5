<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { getDeviceList, type Device } from '#/api/admin/devices';

const loading = ref(false);
const list = ref<Device[]>([]);
const total = ref(0);
const keyword = ref('');
const pagination = reactive({ current: 1, pageSize: 20 });

const columns = [
  { title: 'ID', dataIndex: 'id', width: 70 },
  { title: '设备ID', dataIndex: 'device_id', ellipsis: true },
  { title: '关联用户ID', dataIndex: 'user_id', width: 100 },
  { title: '品牌', dataIndex: 'brand', width: 100 },
  { title: '型号', dataIndex: 'model' },
  { title: 'Android版本', dataIndex: 'os_version', width: 110 },
  { title: 'App版本', dataIndex: 'app_version', width: 100 },
  { title: '最后IP', dataIndex: 'last_ip' },
  { title: '最后活跃', dataIndex: 'last_seen_at', width: 170 },
];

async function load() {
  loading.value = true;
  try {
    const res = await getDeviceList({ page: pagination.current, size: pagination.pageSize, keyword: keyword.value });
    list.value = res.list;
    total.value = res.total;
  } finally {
    loading.value = false;
  }
}

function handleTableChange(pag: any) {
  pagination.current = pag.current;
  pagination.pageSize = pag.pageSize;
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <a-card :bordered="false">
      <div class="mb-4 flex gap-2">
        <a-input-search
          v-model:value="keyword"
          placeholder="搜索设备ID / 品牌 / 型号"
          style="width: 300px"
          @search="load"
        />
      </div>
      <a-table
        :columns="columns"
        :data-source="list"
        :loading="loading"
        :pagination="{ current: pagination.current, pageSize: pagination.pageSize, total, showTotal: (t: number) => `共 ${t} 条` }"
        row-key="id"
        @change="handleTableChange"
      />
    </a-card>
  </div>
</template>
