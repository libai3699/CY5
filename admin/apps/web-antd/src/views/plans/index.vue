<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { getPlanList, createPlan, updatePlan, deletePlan, type Plan } from '#/api/admin/plans';

const loading = ref(false);
const list = ref<Plan[]>([]);
const modalVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);

const form = reactive({
  name: '',
  price: 0,
  traffic_gb: null as number | null,
  duration_days: 30,
  sort_order: 0,
  is_active: 1,
});

const columns = [
  { title: 'ID', dataIndex: 'id', width: 70 },
  { title: '套餐名称', dataIndex: 'name' },
  { title: '价格(元)', dataIndex: 'price', width: 100 },
  { title: '流量(GB)', key: 'traffic', width: 100 },
  { title: '有效期(天)', dataIndex: 'duration_days', width: 110 },
  { title: '排序', dataIndex: 'sort_order', width: 80 },
  { title: '状态', key: 'is_active', width: 80 },
  { title: '操作', key: 'action', width: 150 },
];

async function load() {
  loading.value = true;
  try {
    list.value = await getPlanList();
  } finally {
    loading.value = false;
  }
}

function openCreate() {
  isEdit.value = false;
  Object.assign(form, { name: '', price: 0, traffic_gb: null, duration_days: 30, sort_order: 0, is_active: 1 });
  modalVisible.value = true;
}

function openEdit(record: Plan) {
  isEdit.value = true;
  editId.value = record.id;
  Object.assign(form, { ...record });
  modalVisible.value = true;
}

async function handleOk() {
  if (!form.name || !form.price || !form.duration_days) {
    message.warning('请填写必填项');
    return;
  }
  if (isEdit.value) {
    await updatePlan(editId.value, form);
    message.success('更新成功');
  } else {
    await createPlan(form as any);
    message.success('创建成功');
  }
  modalVisible.value = false;
  load();
}

async function handleDelete(id: number) {
  await deletePlan(id);
  message.success('删除成功');
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <a-card :bordered="false">
      <template #extra>
        <a-button type="primary" @click="openCreate">新增套餐</a-button>
      </template>
      <a-table :columns="columns" :data-source="list" :loading="loading" row-key="id" :pagination="false">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'traffic'">
            {{ record.traffic_gb ? `${record.traffic_gb} GB` : '无限' }}
          </template>
          <template v-else-if="column.key === 'is_active'">
            <a-tag :color="record.is_active === 1 ? 'green' : 'default'">
              {{ record.is_active === 1 ? '上架' : '下架' }}
            </a-tag>
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

    <a-modal v-model:open="modalVisible" :title="isEdit ? '编辑套餐' : '新增套餐'" @ok="handleOk">
      <a-form layout="vertical">
        <a-form-item label="套餐名称" required>
          <a-input v-model:value="form.name" />
        </a-form-item>
        <a-form-item label="价格（元）" required>
          <a-input-number v-model:value="form.price" :min="0" :precision="2" style="width:100%" />
        </a-form-item>
        <a-form-item label="流量（GB，留空=无限）">
          <a-input-number v-model:value="form.traffic_gb" :min="1" style="width:100%" placeholder="留空表示无限流量" />
        </a-form-item>
        <a-form-item label="有效期（天）" required>
          <a-input-number v-model:value="form.duration_days" :min="1" style="width:100%" />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model:value="form.sort_order" style="width:100%" />
        </a-form-item>
        <a-form-item label="状态">
          <a-radio-group v-model:value="form.is_active">
            <a-radio :value="1">上架</a-radio>
            <a-radio :value="0">下架</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>
