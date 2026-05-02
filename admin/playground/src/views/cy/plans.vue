<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Form, Input, InputNumber, Modal, Space, Switch, Table, message } from 'ant-design-vue';

import { createPlan, deletePlan, getPlans, updatePlan, type PlanItem } from '#/api';

const loading = ref(false);
const rows = ref<PlanItem[]>([]);
const open = ref(false);
const editing = ref<PlanItem | null>(null);
const form = reactive<any>({ duration_days: 30, is_active: 1, name: '', price: 0, sort_order: 0, traffic_gb: null });
const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'name', title: '套餐名称' },
  { dataIndex: 'price', title: '价格' },
  { dataIndex: 'traffic_gb', title: '流量GB' },
  { dataIndex: 'duration_days', title: '有效天数' },
  { dataIndex: 'sort_order', title: '排序' },
  { dataIndex: 'is_active', title: '上架', width: 90 },
  { dataIndex: 'action', title: '操作', width: 180 },
];

async function load() {
  loading.value = true;
  try {
    rows.value = await getPlans();
  } finally {
    loading.value = false;
  }
}

function create() {
  editing.value = null;
  Object.assign(form, { duration_days: 30, is_active: 1, name: '', price: 0, sort_order: 0, traffic_gb: null });
  open.value = true;
}

function edit(row: PlanItem) {
  editing.value = row;
  Object.assign(form, row);
  open.value = true;
}

async function save() {
  const data = { ...form, traffic_gb: form.traffic_gb === undefined ? null : form.traffic_gb };
  if (editing.value) await updatePlan(editing.value.id, data);
  else await createPlan(data);
  message.success('已保存');
  open.value = false;
  await load();
}

async function remove(row: PlanItem) {
  await deletePlan(row.id);
  message.success('已删除');
  await load();
}

onMounted(load);
</script>

<template>
  <Page title="套餐管理">
    <Button class="mb-4" type="primary" @click="create">新增套餐</Button>
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="false" row-key="id">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'traffic_gb'">{{ record.traffic_gb ?? '无限' }}</template>
        <template v-if="column.dataIndex === 'is_active'">
          <Switch :checked="record.is_active === 1" @change="(v)=>updatePlan(record.id,{...record,is_active:v?1:0}).then(load)" />
        </template>
        <template v-if="column.dataIndex === 'action'">
          <Space>
            <Button size="small" @click="edit(record)">编辑</Button>
            <Button danger size="small" @click="remove(record)">删除</Button>
          </Space>
        </template>
      </template>
    </Table>
    <Modal v-model:open="open" title="套餐" @ok="save">
      <Form layout="vertical">
        <Form.Item label="套餐名称" required><Input v-model:value="form.name" /></Form.Item>
        <Form.Item label="价格" required><InputNumber v-model:value="form.price" class="w-full" :min="0" /></Form.Item>
        <Form.Item label="流量GB"><InputNumber v-model:value="form.traffic_gb" class="w-full" :min="0" placeholder="留空为无限" /></Form.Item>
        <Form.Item label="有效天数" required><InputNumber v-model:value="form.duration_days" class="w-full" :min="1" /></Form.Item>
        <Form.Item label="排序"><InputNumber v-model:value="form.sort_order" class="w-full" /></Form.Item>
        <Form.Item label="上架"><Switch v-model:checked="form.is_active" :checked-value="1" :un-checked-value="0" /></Form.Item>
      </Form>
    </Modal>
  </Page>
</template>
