<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Form, Input, InputNumber, Modal, Space, Switch, Table, message } from 'ant-design-vue';

import { createUser, deleteUser, getUsers, updateUser, type UserItem } from '#/api';

const loading = ref(false);
const rows = ref<UserItem[]>([]);
const keyword = ref('');
const pagination = reactive({ current: 1, pageSize: 20, total: 0 });
const open = ref(false);
const editing = ref<UserItem | null>(null);
const form = reactive<any>({ username: '', password: '', phone: '', free_limit_seconds: 2700, status: 1 });

const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'username', title: '用户名' },
  { dataIndex: 'phone', title: '手机号' },
  { dataIndex: 'device_id', title: '设备ID', ellipsis: true },
  { dataIndex: 'free_used_seconds', title: '已用免费秒数' },
  { dataIndex: 'free_limit_seconds', title: '免费上限秒数' },
  { dataIndex: 'plan_expired_at', title: '套餐到期' },
  { dataIndex: 'status', title: '状态', width: 90 },
  { dataIndex: 'action', title: '操作', width: 180 },
];

async function load() {
  loading.value = true;
  try {
    const res = await getUsers({ keyword: keyword.value, page: pagination.current, size: pagination.pageSize });
    rows.value = res.list;
    pagination.total = res.total;
  } finally {
    loading.value = false;
  }
}

function create() {
  editing.value = null;
  Object.assign(form, { username: '', password: '', phone: '', free_limit_seconds: 2700, free_used_seconds: 0, status: 1 });
  open.value = true;
}

function edit(row: UserItem) {
  editing.value = row;
  Object.assign(form, { password: '', phone: row.phone || '', status: row.status, free_used_seconds: row.free_used_seconds, free_limit_seconds: row.free_limit_seconds });
  open.value = true;
}

async function save() {
  if (editing.value) {
    const data = { ...form };
    if (!data.password) delete data.password;
    await updateUser(editing.value.id, data);
  } else {
    await createUser(form);
  }
  message.success('已保存');
  open.value = false;
  await load();
}

async function remove(row: UserItem) {
  await deleteUser(row.id);
  message.success('已删除');
  await load();
}

onMounted(load);
</script>

<template>
  <Page title="用户管理">
    <Space class="mb-4">
      <Input v-model:value="keyword" allow-clear placeholder="用户名/手机号/设备ID" @press-enter="load" />
      <Button @click="load">搜索</Button>
      <Button type="primary" @click="create">新增用户</Button>
    </Space>
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="pagination" row-key="id" @change="(p)=>{pagination.current=p.current;pagination.pageSize=p.pageSize;load()}">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'status'">
          <Switch :checked="record.status === 1" @change="(v)=>updateUser(record.id,{status:v?1:0}).then(load)" />
        </template>
        <template v-if="column.dataIndex === 'action'">
          <Space>
            <Button size="small" @click="edit(record)">编辑</Button>
            <Button danger size="small" @click="remove(record)">删除</Button>
          </Space>
        </template>
      </template>
    </Table>
    <Modal v-model:open="open" title="用户" @ok="save">
      <Form layout="vertical">
        <Form.Item v-if="!editing" label="用户名" required><Input v-model:value="form.username" /></Form.Item>
        <Form.Item :label="editing ? '新密码' : '密码'" :required="!editing"><Input.Password v-model:value="form.password" /></Form.Item>
        <Form.Item label="手机号"><Input v-model:value="form.phone" /></Form.Item>
        <Form.Item v-if="editing" label="已用免费秒数"><InputNumber v-model:value="form.free_used_seconds" class="w-full" :min="0" /></Form.Item>
        <Form.Item label="免费上限秒数"><InputNumber v-model:value="form.free_limit_seconds" class="w-full" :min="0" /></Form.Item>
        <Form.Item v-if="editing" label="启用"><Switch v-model:checked="form.status" :checked-value="1" :un-checked-value="0" /></Form.Item>
      </Form>
    </Modal>
  </Page>
</template>
