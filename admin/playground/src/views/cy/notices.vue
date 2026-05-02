<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Form, Input, InputNumber, Modal, Select, Space, Switch, Table, message } from 'ant-design-vue';

import { createNotice, deleteNotice, getNotices, updateNotice, type NoticeItem } from '#/api';

const loading = ref(false);
const rows = ref<NoticeItem[]>([]);
const open = ref(false);
const editing = ref<NoticeItem | null>(null);
const form = reactive<any>({ content: '', is_active: 1, sort_order: 0, type: 1 });
const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'content', title: '内容' },
  { dataIndex: 'type', title: '类型', width: 100 },
  { dataIndex: 'is_active', title: '显示', width: 90 },
  { dataIndex: 'sort_order', title: '排序', width: 90 },
  { dataIndex: 'action', title: '操作', width: 180 },
];

async function load() {
  loading.value = true;
  try {
    rows.value = await getNotices();
  } finally {
    loading.value = false;
  }
}

function create() {
  editing.value = null;
  Object.assign(form, { content: '', is_active: 1, sort_order: 0, type: 1 });
  open.value = true;
}

function edit(row: NoticeItem) {
  editing.value = row;
  Object.assign(form, row);
  open.value = true;
}

async function save() {
  if (editing.value) await updateNotice(editing.value.id, form);
  else await createNotice(form);
  message.success('已保存');
  open.value = false;
  await load();
}

async function remove(row: NoticeItem) {
  await deleteNotice(row.id);
  message.success('已删除');
  await load();
}

onMounted(load);
</script>

<template>
  <Page title="公共通知">
    <Button class="mb-4" type="primary" @click="create">新增通知</Button>
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="false" row-key="id">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'type'">{{ record.type === 2 ? '重要' : '普通' }}</template>
        <template v-if="column.dataIndex === 'is_active'">
          <Switch :checked="record.is_active === 1" @change="(v)=>updateNotice(record.id,{...record,is_active:v?1:0}).then(load)" />
        </template>
        <template v-if="column.dataIndex === 'action'">
          <Space>
            <Button size="small" @click="edit(record)">编辑</Button>
            <Button danger size="small" @click="remove(record)">删除</Button>
          </Space>
        </template>
      </template>
    </Table>
    <Modal v-model:open="open" title="通知" @ok="save">
      <Form layout="vertical">
        <Form.Item label="内容" required><Input.TextArea v-model:value="form.content" :rows="4" /></Form.Item>
        <Form.Item label="类型"><Select v-model:value="form.type" :options="[{label:'普通',value:1},{label:'重要',value:2}]" /></Form.Item>
        <Form.Item label="排序"><InputNumber v-model:value="form.sort_order" class="w-full" /></Form.Item>
        <Form.Item label="显示"><Switch v-model:checked="form.is_active" :checked-value="1" :un-checked-value="0" /></Form.Item>
      </Form>
    </Modal>
  </Page>
</template>
