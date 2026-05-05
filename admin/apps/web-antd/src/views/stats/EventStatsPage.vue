<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { requestClient } from '#/api/request';

const loading = ref(false);
const listLoading = ref(false);

// 汇总统计
const eventCounts = ref<{ page: string; event: string; count: number }[]>([]);
const stayStats = ref<{ page: string; avg_ms: number; max_ms: number; total: number }[]>([]);

// 事件列表
const list = ref<any[]>([]);
const total = ref(0);
const page = reactive({ current: 1, size: 20 });
const filterPage = ref('');
const filterEvent = ref('');

const pageOptions = [
  { label: '全部', value: '' },
  { label: '购买页', value: 'purchase' },
  { label: '支付页', value: 'payment' },
];
const eventOptions = [
  { label: '全部', value: '' },
  { label: '进入', value: 'enter' },
  { label: '离开', value: 'leave' },
  { label: '点击购买', value: 'click_buy' },
];

async function loadStats() {
  loading.value = true;
  try {
    const res = await requestClient.get<any>('/events/stats');
    eventCounts.value = res?.event_counts ?? [];
    stayStats.value = res?.stay_stats ?? [];
  } finally {
    loading.value = false;
  }
}

async function loadList() {
  listLoading.value = true;
  try {
    const res = await requestClient.get<any>('/events', {
      params: { page: page.current, size: page.size, page_name: filterPage.value, event: filterEvent.value },
    });
    list.value = res?.list ?? [];
    total.value = res?.total ?? 0;
  } finally {
    listLoading.value = false;
  }
}

function handleSearch() { page.current = 1; loadList(); }

function fmtMs(ms: number) {
  if (!ms || ms <= 0) return '-';
  if (ms < 1000) return `${ms}ms`;
  const s = ms / 1000;
  if (s < 60) return `${s.toFixed(1)}秒`;
  return `${Math.floor(s / 60)}分${Math.round(s % 60)}秒`;
}

function fmtTime(t: string) {
  if (!t) return '';
  const d = new Date(t);
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

function eventLabel(e: string) {
  const map: Record<string, string> = { enter: '进入', leave: '离开', click_buy: '点击购买' };
  return map[e] ?? e;
}

function pageLabel(p: string) {
  const map: Record<string, string> = { purchase: '购买页', payment: '支付页' };
  return map[p] ?? p;
}

onMounted(() => { loadStats(); loadList(); });
</script>

<template>
  <div class="p-4 space-y-4">
    <!-- 汇总卡片 -->
    <el-row :gutter="16" v-loading="loading">
      <el-col :span="12">
        <el-card header="事件统计">
          <el-table :data="eventCounts" border size="small">
            <el-table-column label="页面" width="100">
              <template #default="{ row }">{{ pageLabel(row.page) }}</template>
            </el-table-column>
            <el-table-column label="事件" width="100">
              <template #default="{ row }">{{ eventLabel(row.event) }}</template>
            </el-table-column>
            <el-table-column prop="count" label="次数" width="80" />
          </el-table>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card header="停留时长统计">
          <el-table :data="stayStats" border size="small">
            <el-table-column label="页面" width="100">
              <template #default="{ row }">{{ pageLabel(row.page) }}</template>
            </el-table-column>
            <el-table-column label="平均停留" width="100">
              <template #default="{ row }">{{ fmtMs(row.avg_ms) }}</template>
            </el-table-column>
            <el-table-column label="最长停留" width="100">
              <template #default="{ row }">{{ fmtMs(row.max_ms) }}</template>
            </el-table-column>
            <el-table-column prop="total" label="样本数" width="80" />
          </el-table>
        </el-card>
      </el-col>
    </el-row>

    <!-- 明细列表 -->
    <el-card>
      <div class="mb-4 flex items-center gap-3">
        <el-select v-model="filterPage" placeholder="页面" style="width:120px" clearable @change="handleSearch">
          <el-option v-for="o in pageOptions" :key="o.value" :label="o.label" :value="o.value" />
        </el-select>
        <el-select v-model="filterEvent" placeholder="事件" style="width:120px" clearable @change="handleSearch">
          <el-option v-for="o in eventOptions" :key="o.value" :label="o.label" :value="o.value" />
        </el-select>
        <el-button @click="handleSearch">查询</el-button>
      </div>

      <el-table :data="list" v-loading="listLoading" border stripe size="small">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="页面" width="90">
          <template #default="{ row }">{{ pageLabel(row.page) }}</template>
        </el-table-column>
        <el-table-column label="事件" width="90">
          <template #default="{ row }">
            <el-tag :type="row.event === 'click_buy' ? 'danger' : row.event === 'enter' ? 'success' : 'info'" size="small">
              {{ eventLabel(row.event) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="username" label="用户名" width="110">
          <template #default="{ row }">{{ row.username || '-' }}</template>
        </el-table-column>
        <el-table-column prop="display_id" label="展示ID" width="90">
          <template #default="{ row }">{{ row.display_id || '-' }}</template>
        </el-table-column>
        <el-table-column prop="plan_name" label="套餐" width="120">
          <template #default="{ row }">{{ row.plan_name || '-' }}</template>
        </el-table-column>
        <el-table-column label="价格" width="80">
          <template #default="{ row }">{{ row.plan_price > 0 ? `¥${row.plan_price}` : '-' }}</template>
        </el-table-column>
        <el-table-column prop="cycle" label="周期" width="80">
          <template #default="{ row }">{{ row.cycle || '-' }}</template>
        </el-table-column>
        <el-table-column label="停留时长" width="100">
          <template #default="{ row }">{{ fmtMs(row.stay_ms) }}</template>
        </el-table-column>
        <el-table-column prop="ip" label="IP" width="130" />
        <el-table-column label="时间" width="155">
          <template #default="{ row }">{{ fmtTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="page.current"
          v-model:page-size="page.size"
          :total="total"
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next"
          @change="loadList"
        />
      </div>
    </el-card>
  </div>
</template>
