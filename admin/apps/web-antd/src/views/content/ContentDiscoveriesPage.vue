<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { Delete, Plus } from '@element-plus/icons-vue';

import {
  createDiscovery,
  deleteDiscovery,
  getDiscoveryList,
  updateDiscovery,
  type DiscoveryItem,
  type DiscoveryItemPayload,
} from '#/api/admin/discoveries';
import { uploadDiscoveryImage } from '#/api/admin/files';

const loading = ref(false);
const saving = ref(false);
const uploading = ref(false);
const iconInputMode = ref<'upload' | 'url'>('upload');
const list = ref<DiscoveryItem[]>([]);
const dialogVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);
const form = reactive<DiscoveryItemPayload>({
  name: '',
  icon_url: '',
  h5_url: '',
  is_active: 1,
  sort_order: 0,
});

async function load() {
  loading.value = true;
  try {
    list.value = (await getDiscoveryList()) ?? [];
  } finally {
    loading.value = false;
  }
}

function resetForm() {
  Object.assign(form, {
    name: '',
    icon_url: '',
    h5_url: '',
    is_active: 1,
    sort_order: 0,
  });
}

function openCreate() {
  isEdit.value = false;
  editId.value = 0;
  resetForm();
  iconInputMode.value = 'upload';
  dialogVisible.value = true;
}

function openEdit(row: DiscoveryItem) {
  isEdit.value = true;
  editId.value = row.id;
  iconInputMode.value = 'upload';
  Object.assign(form, {
    name: row.name,
    icon_url: row.icon_url,
    h5_url: row.h5_url,
    is_active: row.is_active,
    sort_order: row.sort_order,
  });
  dialogVisible.value = true;
}

async function handleIconUpload(file: File) {
  if (!file.type.startsWith('image/')) {
    ElMessage.error('只能上传图片文件');
    return;
  }
  if (file.size > 5 * 1024 * 1024) {
    ElMessage.error('图片大小不能超过 5MB');
    return;
  }

  uploading.value = true;
  try {
    const data = new FormData();
    data.append('file', file);
    const result = await uploadDiscoveryImage(data);
    form.icon_url = result.url;
    ElMessage.success('图标上传成功');
  } finally {
    uploading.value = false;
  }
}

async function handleSubmit() {
  if (!form.name.trim()) {
    ElMessage.warning('请输入名称');
    return;
  }
  if (!form.icon_url.trim()) {
    ElMessage.warning('请输入图标地址');
    return;
  }
  if (!form.h5_url.trim()) {
    ElMessage.warning('请输入 H5 链接');
    return;
  }

  saving.value = true;
  try {
    const payload = { ...form };
    if (isEdit.value) {
      await updateDiscovery(editId.value, payload);
      ElMessage.success('更新成功');
    } else {
      await createDiscovery(payload);
      ElMessage.success('创建成功');
    }
    dialogVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

async function handleDelete(row: DiscoveryItem) {
  await ElMessageBox.confirm(`确定删除“${row.name}”？`, '提示', {
    type: 'warning',
  });
  await deleteDiscovery(row.id);
  ElMessage.success('删除成功');
  await load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <el-card>
      <div class="mb-4 flex justify-end">
        <el-button type="primary" @click="openCreate">新增</el-button>
      </div>

      <el-table
        v-loading="loading"
        :data="list"
        border
        stripe
        empty-text="暂无发现宝藏内容"
      >
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="图标" width="90" align="center">
          <template #default="{ row }">
            <el-image
              :src="row.icon_url"
              :preview-src-list="[row.icon_url]"
              preview-teleported
              fit="cover"
              class="h-11 w-11 rounded-lg"
            />
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" min-width="140" />
        <el-table-column label="H5 链接" min-width="300" show-overflow-tooltip>
          <template #default="{ row }">
            <el-link :href="row.h5_url" target="_blank" type="primary">
              {{ row.h5_url }}
            </el-link>
          </template>
        </el-table-column>
        <el-table-column prop="sort_order" label="排序" width="80" align="center" />
        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.is_active === 1 ? 'success' : 'info'">
              {{ row.is_active === 1 ? '启用' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="180" />
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="openEdit(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(row)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? '编辑发现宝藏' : '新增发现宝藏'"
      width="560px"
      destroy-on-close
    >
      <el-form :model="form" label-width="90px">
        <el-form-item label="名称" required>
          <el-input v-model="form.name" maxlength="80" placeholder="请输入名称" />
        </el-form-item>
        <el-form-item label="图标" required>
          <div class="w-full">
            <el-radio-group v-model="iconInputMode" class="mb-3">
              <el-radio-button value="upload">上传图片</el-radio-button>
              <el-radio-button value="url">图片地址</el-radio-button>
            </el-radio-group>

            <div v-if="form.icon_url" class="mb-3 flex items-center gap-3">
              <el-image
                :src="form.icon_url"
                :preview-src-list="[form.icon_url]"
                preview-teleported
                fit="cover"
                class="h-16 w-16 rounded-lg"
              />
              <el-button :icon="Delete" @click="form.icon_url = ''">移除</el-button>
            </div>

            <el-upload
              v-if="iconInputMode === 'upload'"
              :show-file-list="false"
              :before-upload="(file) => { handleIconUpload(file); return false; }"
              accept="image/*"
              :disabled="uploading"
            >
              <el-button :icon="Plus" :loading="uploading">
                {{ form.icon_url ? '更换图片' : '选择图片' }}
              </el-button>
            </el-upload>

            <el-input
              v-else
              v-model="form.icon_url"
              placeholder="https://example.com/icon.png"
            />
            <div class="mt-2 text-xs text-gray-500">
              上传图片或填写图片地址，任选一种即可
            </div>
          </div>
        </el-form-item>
        <el-form-item label="H5 链接" required>
          <el-input v-model="form.h5_url" placeholder="https://example.com/app" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :min="0" style="width: 100%" />
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.is_active">
            <el-radio :value="1">启用</el-radio>
            <el-radio :value="0">禁用</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" :disabled="uploading" @click="handleSubmit">
          确定
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>
