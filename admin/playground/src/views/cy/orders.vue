<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Form, Input, InputNumber, Modal, Select, Space, Table, message } from 'ant-design-vue';

import { createOrder, getOrders, getPlans, type OrderItem, type PlanItem } from '#/api';

const loading = ref(false);
const rows = ref<OrderItem[]>([]);
const plans = ref<PlanItem[]>([]);
const pagination = reactive({ current: 1, pageSize: 20, total: 0 });
const open = ref(false);
const form = reactive<any>({ plan_id: undefined, remark: '', user_id: undefined });
const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'user_id', title: '用户ID' },
  { dataIndex: 'plan_name', title: '套餐' },
  { dataIndex: 'plan_price', title: '价格' },
  { dataIndex: 'traffic_gb', title: '流量GB' },
  { dataIndex: 'started_at', title: '开始时间' },
  { dataIndex: 'expired_at', title: '到期时间' },
  { dataIndex: 'remark', title: '备注' },
];

async function load() {
  loading.value = true;
  try {
    const res = await getOrders({ page: pagination.current, size: pagination.pageSize });
    rows.value = res.list;
    pagination.total = res.total;
  } finally {
    loading.value = false;
  }
}

async function save() {
  await createOrder(form);
  message.success('已开通');
  open.value = false;
  await load();
}

onMounted(async () => {
  plans.value = await getPlans();
  await load();
});
</script>

<template>
  <Page title="订单管理">
    <Button class="mb-4" type="primary" @click="open = true">手动开通套餐</Button>
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="pagination" row-key="id" @change="(p)=>{pagination.current=p.current;pagination.pageSize=p.pageSize;load()}">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'traffic_gb'">{{ record.traffic_gb ?? '无限' }}</template>
      </template>
    </Table>
    <Modal v-model:open="open" title="手动开通套餐" @ok="save">
      <Form layout="vertical">
        <Form.Item label="用户ID" required><InputNumber v-model:value="form.user_id" class="w-full" :min="1" /></Form.Item>
        <Form.Item label="套餐" required>
          <Select v-model:value="form.plan_id" :options="plans.map((p) => ({ label: `${p.name} - ${p.price}`, value: p.id }))" />
        </Form.Item>
        <Form.Item label="备注"><Input v-model:value="form.remark" /></Form.Item>
      </Form>
    </Modal>
  </Page>
</template>
