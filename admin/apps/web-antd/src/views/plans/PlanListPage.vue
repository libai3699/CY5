<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getPlanList, createPlan, updatePlan, deletePlan, type Plan } from '#/api/admin/plans';

const loading = ref(false);
const list = ref<Plan[]>([]);
const dialogVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);
const form = reactive({ name: '', price: 0, traffic_gb: null as number | null, duration_days: 30, sort_order: 0, is_active: 1 });

async function load() {
  loading.value = true;
  try { list.value = await getPlanList() ?? []; } finally { loading.value = false; }
}

function openCreate() {
  isEdit.value = false;
  Object.assign(form, { name: '', price: 0, traffic_gb: null, duration_days: 30, sort_order: 0, is_active: 1 });
  dialogVisible.value = true;
}

function openEdit(row: Plan) {
  isEdit.value = true; editId.value = row.id;
  Object.assign(form, { ...row });
  dialogVisible.value = true;
}

async function handleSubmit() {
  if (!form.name || !form.price || !form.duration_days) { ElMessage.warning('请填写必填项'); return; }
  if (isEdit.value) { await updatePlan(editId.value, form); ElMessage.success('更新成功'); }
  else { await createPlan(form as any); ElMessage.success('创建成功'); }
  dialogVisible.value = false; load();
}

async function handleDelete(row: Plan) {
  await ElMessageBox.confirm(`确定删除套餐 ${row.name}？`, '提示', { type: 'warning' });
  await deletePlan(row.id); ElMessage.success('删除成功'); load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <el-card>
      <div class="mb-4 flex justify-end">
        <el-button type="primary" @click="openCreate">新增套餐</el-button>
      </div>
      <el-table :data="list" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="name" label="套餐名称" />
        <el-table-column prop="price" label="价格(元)" width="100" />
        <el-table-column label="流量" width="100">
          <template #default="{ row }">{{ row.traffic_gb ? `${row.traffic_gb} GB` : '无限' }}</template>
        </el-table-column>
        <el-table-column prop="duration_days" label="有效期(天)" width="110" />
        <el-table-column prop="sort_order" label="排序" width="80" />
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.is_active === 1 ? 'success' : 'info'">{{ row.is_active === 1 ? '上架' : '下架' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button size="small" @click="openEdit(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑套餐' : '新增套餐'" width="480px">
      <el-form :model="form" label-width="120px">
        <el-form-item label="套餐名称" required><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="价格(元)" required><el-input-number v-model="form.price" :min="0" :precision="2" style="width:100%" /></el-form-item>
        <el-form-item label="流量(GB)"><el-input-number v-model="form.traffic_gb" :min="1" style="width:100%" placeholder="留空=无限" /></el-form-item>
        <el-form-item label="有效期(天)" required><el-input-number v-model="form.duration_days" :min="1" style="width:100%" /></el-form-item>
        <el-form-item label="排序"><el-input-number v-model="form.sort_order" style="width:100%" /></el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.is_active">
            <el-radio :value="1">上架</el-radio><el-radio :value="0">下架</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>
