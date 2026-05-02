<template>
  <div class="p-4">
    <a-card title="用户管理" :bordered="false">
      <a-table
        :columns="columns"
        :data-source="dataSource"
        :loading="loading"
        :pagination="pagination"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" size="small" @click="handleEdit(record)">
                编辑
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 编辑弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="modalTitle"
      @ok="handleSubmit"
      @cancel="handleCancel"
    >
      <a-form
        ref="formRef"
        :model="formData"
        :rules="rules"
        layout="vertical"
      >
        <a-form-item label="状态" name="status">
          <a-radio-group v-model:value="formData.status">
            <a-radio :value="1">正常</a-radio>
            <a-radio :value="0">禁用</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="已用免费时长（秒）" name="free_used_seconds">
          <a-input-number
            v-model:value="formData.free_used_seconds"
            :min="0"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="免费时长上限（秒）" name="free_limit_seconds">
          <a-input-number
            v-model:value="formData.free_limit_seconds"
            :min="0"
            style="width: 100%"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { message } from 'ant-design-vue';
import { ref, reactive, onMounted } from 'vue';
import {
  getUsersListApi,
  updateUserApi,
  type UsersApi,
} from '#/api/core/users';

const columns = [
  {
    title: 'ID',
    dataIndex: 'id',
    key: 'id',
    width: 80,
  },
  {
    title: '用户名',
    dataIndex: 'username',
    key: 'username',
  },
  {
    title: '手机号',
    dataIndex: 'phone',
    key: 'phone',
  },
  {
    title: '设备ID',
    dataIndex: 'device_id',
    key: 'device_id',
    width: 150,
  },
  {
    title: '免费时长',
    key: 'free_time',
    customRender: ({ record }: any) => {
      const used = Math.floor(record.free_used_seconds / 60);
      const limit = Math.floor(record.free_limit_seconds / 60);
      return `${used}/${limit} 分钟`;
    },
  },
  {
    title: '状态',
    dataIndex: 'status',
    key: 'status',
    customRender: ({ record }: any) => {
      return record.status === 1 ? '正常' : '禁用';
    },
  },
  {
    title: '注册时间',
    dataIndex: 'created_at',
    key: 'created_at',
    width: 180,
  },
  {
    title: '操作',
    key: 'action',
    width: 200,
  },
];

const dataSource = ref<UsersApi.User[]>([]);
const loading = ref(false);
const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
});

const modalVisible = ref(false);
const modalTitle = ref('编辑用户');
const formRef = ref();
const formData = reactive<Partial<UsersApi.User>>({
  status: 1,
  free_used_seconds: 0,
  free_limit_seconds: 2700,
});
const editingId = ref<number | null>(null);

const rules = {
  status: [{ required: true, message: '请选择状态' }],
};

// 加载用户列表
async function loadUserList() {
  loading.value = true;
  try {
    const res = await getUsersListApi({
      page: pagination.current,
      pageSize: pagination.pageSize,
    });
    dataSource.value = res.items;
    pagination.total = res.total;
  } catch (error) {
    message.error('加载用户列表失败');
  } finally {
    loading.value = false;
  }
}

// 表格分页变化
function handleTableChange(pag: any) {
  pagination.current = pag.current;
  pagination.pageSize = pag.pageSize;
  loadUserList();
}

// 编辑用户
function handleEdit(record: UsersApi.User) {
  modalTitle.value = '编辑用户';
  editingId.value = record.id;
  Object.assign(formData, {
    status: record.status,
    free_used_seconds: record.free_used_seconds,
    free_limit_seconds: record.free_limit_seconds,
  });
  modalVisible.value = true;
}

// 提交表单
async function handleSubmit() {
  try {
    await formRef.value.validate();
    if (editingId.value !== null) {
      await updateUserApi(editingId.value, formData);
      message.success('更新成功');
    }
    modalVisible.value = false;
    loadUserList();
  } catch (error) {
    console.error('表单验证失败', error);
  }
}

// 取消
function handleCancel() {
  modalVisible.value = false;
  formRef.value?.resetFields();
}

onMounted(() => {
  loadUserList();
});
</script>
