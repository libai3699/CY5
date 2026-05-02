<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { getNoticeList, createNotice, updateNotice, deleteNotice, type Notice } from '#/api/admin/notices';

const loading = ref(false);
const list = ref<Notice[]>([]);
const modalVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);
const form = reactive({ content: '', type: 1, is_active: 1 as number, sort_order: 0 });

const columns = [
  { title: 'ID', dataIndex: 'id', width: 70 },
  { title: '内容', dataIndex: 'content', ellipsis: true },
  { title: '类型', key: 'type', width: 90 },
  { title: '状态', key: 'is_active', width: 80 },
  { title: '排序', dataIndex: 'sort_order', width: 80 },
  { title: '创建时间', dataIndex: 'created_at', width: 170 },
  { title: '操作', key: 'action', width: 150 },
];

async function load() {
  loading.value = true;
  try { list.value = await getNoticeList(); } finally { loading.value = false; }
}

function openCreate() {
  isEdit.value = false;
  Object.assign(form, { content: '', type: 1, is_active: 1, sort_order: 0 });
  modalVisible.value = true;
}

function openEdit(record: Notice) {
  isEdit.value = true;
  editId.value = record.id;
  Object.assign(form, { content: record.content, type: record.type, is_active: record.is_active, sort_order: record.sort_order });
  modalVisible.value = true;
}

async function handleOk() {
  if (!form.content) { message.warning('请输入通知内容'); return; }
  if (isEdit.value) {
    await updateNotice(editId.value, form);
    message.success('更新成功');
  } else {
    await createNotice(form);
    message.success('创建成功');
  }
  modalVisible.value = false;
  load();
}

async function handleDelete(id: number) {
  await deleteNotice(id);
  message.success('删除成功');
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <a-card :bordered="false">
      <template #extra>
        <a-button type="primary" @click="openCreate">新增通知</a-button>
      </template>
      <a-table :columns="columns" :data-source="list" :loading="loading" row-key="id" :pagination="false">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'type'">
            <a-tag :color="record.type === 2 ? 'red' : 'blue'">{{ record.type === 2 ? '重要' : '普通' }}</a-tag>
          </template>
          <template v-else-if="column.key === 'is_active'">
            <a-tag :color="record.is_active === 1 ? 'green' : 'default'">{{ record.is_active === 1 ? '显示' : '隐藏' }}</a-tag>
          </template>
          <template v-else-if="column.key === 'action'">
            <a-space>
              <a-button size="small" type="link" @click="openEdit(record)">编辑</a-button>
              <a-popconfirm title="确定删除？" @confirm="handleDelete(record.id)">
                <a-button size="small" type="link" danger>删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal v-model:open="modalVisible" :title="isEdit ? '编辑通知' : '新增通知'" @ok="handleOk">
      <a-form layout="vertical">
        <a-form-item label="内容" required>
          <a-textarea v-model:value="form.content" :rows="4" />
        </a-form-item>
        <a-form-item label="类型">
          <a-radio-group v-model:value="form.type">
            <a-radio :value="1">普通</a-radio>
            <a-radio :value="2">重要</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="状态">
          <a-radio-group v-model:value="form.is_active">
            <a-radio :value="1">显示</a-radio>
            <a-radio :value="0">隐藏</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model:value="form.sort_order" style="width:100%" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>
