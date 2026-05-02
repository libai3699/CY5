<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { getUserList, createUser, updateUser, deleteUser, type User } from '#/api/admin/users';

const loading = ref(false);
const list = ref<User[]>([]);
const total = ref(0);
const keyword = ref('');
const pagination = reactive({ current: 1, pageSize: 20 });

// 弹窗
const modalVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);
const form = reactive({
  username: '',
  password: '',
  phone: '',
  status: 1,
  free_used_seconds: 0,
  free_limit_seconds: 2700,
});

const columns = [
  { title: 'ID', dataIndex: 'id', width: 70 },
  { title: '用户名', dataIndex: 'username', width: 120 },
  { title: '手机号', dataIndex: 'phone', width: 130 },
  { title: '设备ID', dataIndex: 'device_id', ellipsis: true },
  { title: '免费时长', key: 'free_time', width: 140 },
  { title: '套餐到期', dataIndex: 'plan_expired_at', width: 170 },
  { title: '状态', key: 'status', width: 80 },
  { title: '注册时间', dataIndex: 'created_at', width: 170 },
  { title: '操作', key: 'action', width: 180, fixed: 'right' },
];

async function load() {
  loading.value = true;
  try {
    const res = await getUserList({ page: pagination.current, size: pagination.pageSize, keyword: keyword.value });
    list.value = res.list ?? [];
    total.value = res.total ?? 0;
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  pagination.current = 1;
  load();
}

function handleTableChange(pag: any) {
  pagination.current = pag.current;
  pagination.pageSize = pag.pageSize;
  load();
}

function openCreate() {
  isEdit.value = false;
  Object.assign(form, { username: '', password: '', phone: '', status: 1, free_used_seconds: 0, free_limit_seconds: 2700 });
  modalVisible.value = true;
}

function openEdit(record: User) {
  isEdit.value = true;
  editId.value = record.id;
  Object.assign(form, {
    username: record.username,
    password: '',
    phone: record.phone || '',
    status: record.status,
    free_used_seconds: record.free_used_seconds,
    free_limit_seconds: record.free_limit_seconds,
  });
  modalVisible.value = true;
}

async function handleOk() {
  if (!isEdit.value) {
    if (!form.username || !form.password) {
      message.warning('用户名和密码必填');
      return;
    }
    await createUser({ username: form.username, password: form.password, phone: form.phone, free_limit_seconds: form.free_limit_seconds });
    message.success('创建成功');
  } else {
    const data: any = { status: form.status, phone: form.phone, free_used_seconds: form.free_used_seconds, free_limit_seconds: form.free_limit_seconds };
    if (form.password) data.password = form.password;
    await updateUser(editId.value, data);
    message.success('更新成功');
  }
  modalVisible.value = false;
  load();
}

async function handleToggleStatus(record: User) {
  await updateUser(record.id, { status: record.status === 1 ? 0 : 1 });
  message.success(record.status === 1 ? '已禁用' : '已启用');
  load();
}

async function handleDelete(id: number) {
  await deleteUser(id);
  message.success('删除成功');
  load();
}

function fmtSeconds(s: number) {
  return `${Math.floor(s / 60)} 分钟`;
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <a-card :bordered="false">
      <template #extra>
        <a-button type="primary" @click="openCreate">新增用户</a-button>
      </template>
      <div class="mb-4">
        <a-input-search
          v-model:value="keyword"
          placeholder="搜索用户名 / 手机号 / 设备ID"
          style="width: 300px"
          @search="handleSearch"
        />
      </div>

      <a-table
        :columns="columns"
        :data-source="list"
        :loading="loading"
        :pagination="{ current: pagination.current, pageSize: pagination.pageSize, total, showTotal: (t: number) => `共 ${t} 条` }"
        row-key="id"
        :scroll="{ x: 1200 }"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="record.status === 1 ? 'green' : 'red'">
              {{ record.status === 1 ? '正常' : '禁用' }}
            </a-tag>
          </template>
          <template v-else-if="column.key === 'free_time'">
            {{ fmtSeconds(record.free_used_seconds) }} / {{ fmtSeconds(record.free_limit_seconds) }}
          </template>
          <template v-else-if="column.key === 'action'">
            <a-space>
              <a-button size="small" type="link" @click="openEdit(record)">编辑</a-button>
              <a-popconfirm
                :title="record.status === 1 ? '确定禁用该用户？' : '确定启用该用户？'"
                @confirm="handleToggleStatus(record)"
              >
                <a-button size="small" type="link" :danger="record.status === 1">
                  {{ record.status === 1 ? '禁用' : '启用' }}
                </a-button>
              </a-popconfirm>
              <a-popconfirm title="确定删除该用户？删除后不可恢复" @confirm="handleDelete(record.id)">
                <a-button size="small" type="link" danger>删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal
      v-model:open="modalVisible"
      :title="isEdit ? '编辑用户' : '新增用户'"
      @ok="handleOk"
    >
      <a-form layout="vertical">
        <a-form-item label="用户名" :required="!isEdit">
          <a-input v-model:value="form.username" :disabled="isEdit" placeholder="登录用户名" />
        </a-form-item>
        <a-form-item :label="isEdit ? '新密码（留空不修改）' : '密码'" :required="!isEdit">
          <a-input-password v-model:value="form.password" placeholder="输入密码" />
        </a-form-item>
        <a-form-item label="手机号">
          <a-input v-model:value="form.phone" placeholder="可选" />
        </a-form-item>
        <template v-if="isEdit">
          <a-form-item label="状态">
            <a-radio-group v-model:value="form.status">
              <a-radio :value="1">正常</a-radio>
              <a-radio :value="0">禁用</a-radio>
            </a-radio-group>
          </a-form-item>
          <a-form-item label="已用免费时长（秒）">
            <a-input-number v-model:value="form.free_used_seconds" :min="0" style="width:100%" />
          </a-form-item>
        </template>
        <a-form-item label="免费时长上限（秒，默认2700=45分钟）">
          <a-input-number v-model:value="form.free_limit_seconds" :min="0" style="width:100%" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>
