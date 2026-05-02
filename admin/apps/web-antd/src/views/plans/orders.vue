<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { getOrderList, createOrder, type Order } from '#/api/admin/orders';
import { getPlanList, type Plan } from '#/api/admin/plans';

const loading = ref(false);
const list = ref<Order[]>([]);
const total = ref(0);
const pagination = reactive({ current: 1, pageSize: 20 });
const modalVisible = ref(false);
const plans = ref<Plan[]>([]);
const form = reactive({ user_id: undefined as number | undefined, plan_id: undefined as number | undefined, remark: '' });

const columns = [
  { title: 'ID', dataIndex: 'id', width: 70 },
  { title: '用户ID', dataIndex: 'user_id', width: 90 },
  { title: '套餐', dataIndex: 'plan_name' },
  { title: '价格', dataIndex: 'plan_price', width: 90 },
  { title: '流量', key: 'traffic', width: 90 },
  { title: '有效期(天)', dataIndex: 'duration_days', width: 100 },
  { title: '生效时间', dataIndex: 'started_at', width: 170 },
  { title: '到期时间', dataIndex: 'expired_at', width: 170 },
  { title: '方式', dataIndex: 'pay_method', width: 80 },
  { title: '备注', dataIndex: 'remark' },
];

async function load() {
  loading.value = true;
  try {
    const res = await getOrderList({ page: pagination.current, size: pagination.pageSize });
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

async function openCreate() {
  plans.value = await getPlanList();
  Object.assign(form, { user_id: undefined, plan_id: undefined, remark: '' });
  modalVisible.value = true;
}

async function handleOk() {
  if (!form.user_id || !form.plan_id) {
    message.warning('请填写用户ID和套餐');
    return;
  }
  await createOrder({ user_id: form.user_id, plan_id: form.plan_id, remark: form.remark });
  message.success('开通成功');
  modalVisible.value = false;
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <a-card :bordered="false">
      <template #extra>
        <a-button type="primary" @click="openCreate">手动开通</a-button>
      </template>
      <a-table
        :columns="columns"
        :data-source="list"
        :loading="loading"
        :pagination="{ current: pagination.current, pageSize: pagination.pageSize, total, showTotal: (t: number) => `共 ${t} 条` }"
        row-key="id"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'traffic'">
            {{ record.traffic_gb ? `${record.traffic_gb} GB` : '无限' }}
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal v-model:open="modalVisible" title="手动开通套餐" @ok="handleOk">
      <a-form layout="vertical">
        <a-form-item label="用户ID" required>
          <a-input-number v-model:value="form.user_id" :min="1" style="width:100%" placeholder="输入用户ID" />
        </a-form-item>
        <a-form-item label="套餐" required>
          <a-select v-model:value="form.plan_id" style="width:100%" placeholder="选择套餐">
            <a-select-option v-for="p in plans" :key="p.id" :value="p.id">
              {{ p.name }} - ¥{{ p.price }} / {{ p.duration_days }}天
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="备注">
          <a-input v-model:value="form.remark" placeholder="可选备注" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>
