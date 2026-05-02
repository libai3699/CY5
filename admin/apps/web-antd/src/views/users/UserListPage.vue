<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getUserList, createUser, updateUser, deleteUser, type User } from '#/api/admin/users';

const loading = ref(false);
const list = ref<User[]>([]);
const total = ref(0);
const keyword = ref('');
const page = reactive({ current: 1, size: 20 });

const dialogVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);
const form = reactive({ username: '', password: '', phone: '', status: 1, free_used_seconds: 0, free_limit_seconds: 2700 });

async function load() {
  loading.value = true;
  try {
    const res = await getUserList({ page: page.current, size: page.size, keyword: keyword.value });
    list.value = res?.list ?? [];
    total.value = res?.total ?? 0;
  } finally { loading.value = false; }
}

function handleSearch() { page.current = 1; load(); }

function openCreate() {
  isEdit.value = false;
  Object.assign(form, { username: '', password: '', phone: '', status: 1, free_used_seconds: 0, free_limit_seconds: 2700 });
  dialogVisible.value = true;
}

function openEdit(row: User) {
  isEdit.value = true;
  editId.value = row.id;
  Object.assign(form, { username: row.username, password: '', phone: row.phone || '', status: row.status, free_used_seconds: row.free_used_seconds, free_limit_seconds: row.free_limit_seconds });
  dialogVisible.value = true;
}

async function handleSubmit() {
  if (!isEdit.value) {
    if (!form.username || !form.password) { ElMessage.warning('用户名和密码必填'); return; }
    await createUser({ username: form.username, password: form.password, phone: form.phone, free_limit_seconds: form.free_limit_seconds });
    ElMessage.success('创建成功');
  } else {
    const data: any = { status: form.status, phone: form.phone, free_used_seconds: form.free_used_seconds, free_limit_seconds: form.free_limit_seconds };
    if (form.password) data.password = form.password;
    await updateUser(editId.value, data);
    ElMessage.success('更新成功');
  }
  dialogVisible.value = false;
  load();
}

async function handleToggle(row: User) {
  await updateUser(row.id, { status: row.status === 1 ? 0 : 1 });
  ElMessage.success(row.status === 1 ? '已禁用' : '已启用');
  load();
}

async function handleDelete(row: User) {
  await ElMessageBox.confirm(`确定删除用户 ${row.username}？`, '提示', { type: 'warning' });
  await deleteUser(row.id);
  ElMessage.success('删除成功');
  load();
}

const fmtSec = (s: number) => `${Math.floor(s / 60)} 分钟`;

onMounted(load);
</script>

<template>
  <div class="p-4">
    <el-card>
      <div class="mb-4 flex items-center justify-between">
        <el-input v-model="keyword" placeholder="搜索用户名/手机号/设备ID" style="width:280px" clearable @keyup.enter="handleSearch">
          <template #append><el-button @click="handleSearch">搜索</el-button></template>
        </el-input>
        <el-button type="primary" @click="openCreate">新增用户</el-button>
      </div>

      <el-table :data="list" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="username" label="用户名" width="120" />
        <el-table-column prop="phone" label="手机号" width="130" />
        <el-table-column prop="device_id" label="设备ID" show-overflow-tooltip />
        <el-table-column label="免费时长" width="150">
          <template #default="{ row }">{{ fmtSec(row.free_used_seconds) }} / {{ fmtSec(row.free_limit_seconds) }}</template>
        </el-table-column>
        <el-table-column label="线路ID" width="90">
          <template #default="{ row }">{{ row.current_line_id ?? '未分配' }}</template>
        </el-table-column>
        <el-table-column label="套餐到期" width="170">
          <template #default="{ row }">{{ row.plan_expired_at || '未开通' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'">{{ row.status === 1 ? '正常' : '禁用' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="注册时间" width="170" />
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="openEdit(row)">编辑</el-button>
            <el-button size="small" :type="row.status === 1 ? 'warning' : 'success'" @click="handleToggle(row)">
              {{ row.status === 1 ? '禁用' : '启用' }}
            </el-button>
            <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="page.current"
          v-model:page-size="page.size"
          :total="total"
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next"
          @change="load"
        />
      </div>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑用户' : '新增用户'" width="480px">
      <el-form :model="form" label-width="140px">
        <el-form-item label="用户名" required>
          <el-input v-model="form.username" :disabled="isEdit" />
        </el-form-item>
        <el-form-item :label="isEdit ? '新密码（留空不改）' : '密码'" :required="!isEdit">
          <el-input v-model="form.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item v-if="isEdit" label="状态">
          <el-radio-group v-model="form.status">
            <el-radio :value="1">正常</el-radio>
            <el-radio :value="0">禁用</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="isEdit" label="已用免费时长(秒)">
          <el-input-number v-model="form.free_used_seconds" :min="0" style="width:100%" />
        </el-form-item>
        <el-form-item label="免费时长上限(秒)">
          <el-input-number v-model="form.free_limit_seconds" :min="0" style="width:100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>
