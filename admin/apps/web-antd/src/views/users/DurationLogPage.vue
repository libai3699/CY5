<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { requestClient } from '#/api/request';

const loading = ref(false);
const list = ref<any[]>([]);
const total = ref(0);
const page = ref(1);
const size = ref(20);

const fmtTime = (t: string) => {
  if (!t) return '-';
  const d = new Date(t);
  if (Number.isNaN(d.getTime())) return t;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
};

const fmtSeconds = (s: number) => {
  if (!s) return '-';
  if (s < 60) return `${s}秒`;
  if (s < 3600) return `${Math.floor(s/60)}分钟`;
  if (s < 86400) return `${Math.floor(s/3600)}小时`;
  if (s < 86400*30) return `${Math.floor(s/86400)}天`;
  if (s < 86400*365) return `${Math.floor(s/86400/30)}个月`;
  return `${(s/86400/365).toFixed(1)}年`;
};

const fmtBytes = (b: number) => {
  if (!b) return '-';
  if (b < 1024*1024*1024) return `${(b/1024/1024).toFixed(1)} MB`;
  return `${(b/1024/1024/1024).toFixed(2)} GB`;
};

async function load() {
  loading.value = true;
  try {
    const res = await requestClient.get<any>('/duration-logs', { params: { page: page.value, size: size.value } });
    list.value = res?.list ?? [];
    total.value = res?.total ?? 0;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <el-card>
      <template #header>
        <span style="font-weight:700">追加记录</span>
      </template>

      <el-table :data="list" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="username" label="用户名" width="130" />
        <el-table-column label="追加时长" width="120">
          <template #default="{ row }">{{ fmtSeconds(row.seconds) }}</template>
        </el-table-column>
        <el-table-column label="追加流量" width="120">
          <template #default="{ row }">{{ fmtBytes(row.traffic_bytes) }}</template>
        </el-table-column>
        <el-table-column prop="operator_name" label="操作人" width="100" />
        <el-table-column prop="remark" label="备注" show-overflow-tooltip />
        <el-table-column label="时间" width="160">
          <template #default="{ row }">{{ fmtTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="size"
          :total="total"
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next"
          @change="load"
        />
      </div>
    </el-card>
  </div>
</template>
