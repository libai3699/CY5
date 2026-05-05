<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';

import { ElMessage } from 'element-plus';

import {
  createConfig,
  getConfigList,
  updateConfig,
  type AppConfig,
} from '#/api/admin/configs';

const loading = ref(false);
const list = ref<AppConfig[]>([]);
const editingKey = ref('');
const editingValue = ref('');
const createOpen = ref(false);
const createForm = reactive({
  key_name: '',
  label: '',
  sort_order: 0,
  value: '',
});

const websiteConfigs = computed(() =>
  list.value.filter(
    (c) =>
      c.key_name.startsWith('download_') ||
      c.key_name.startsWith('app_') ||
      c.key_name.startsWith('site_'),
  ),
);
const contactConfigs = computed(() => list.value.filter((c) => c.key_name.startsWith('contact_')));

async function load() {
  loading.value = true;
  try {
    list.value = (await getConfigList()) ?? [];
  } finally {
    loading.value = false;
  }
}

function startEdit(row: AppConfig) {
  editingKey.value = row.key_name;
  editingValue.value = row.value;
}

async function saveEdit(row: AppConfig) {
  await updateConfig(row.key_name, editingValue.value);
  ElMessage.success('保存成功');
  editingKey.value = '';
  await load();
}

function openCreate(prefix = '') {
  Object.assign(createForm, { key_name: prefix, label: '', sort_order: 10, value: '' });
  createOpen.value = true;
}

async function saveCreate() {
  await createConfig(createForm);
  ElMessage.success('新增成功');
  createOpen.value = false;
  await load();
}

onMounted(load);
</script>

<template>
  <div class="space-y-4 p-4">
    <el-card v-loading="loading">
      <template #header>
        <div class="flex items-center justify-between">
          <span class="text-base font-semibold">官网配置</span>
          <el-button type="primary" @click="openCreate('download_')">新增官网配置</el-button>
        </div>
      </template>

      <el-table :data="websiteConfigs" border stripe>
        <el-table-column prop="label" label="名称" width="160" />
        <el-table-column prop="key_name" label="配置键" width="220" />
        <el-table-column label="值">
          <template #default="{ row }">
            <el-input
              v-if="editingKey === row.key_name"
              v-model="editingValue"
              type="textarea"
              :autosize="{ minRows: 1, maxRows: 4 }"
              placeholder="请输入配置值"
            />
            <span v-else :class="row.value ? 'text-gray-800' : 'text-gray-400'">
              {{ row.value || '（未设置）' }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <template v-if="editingKey === row.key_name">
              <el-button size="small" type="primary" @click="saveEdit(row)">保存</el-button>
              <el-button size="small" @click="editingKey = ''">取消</el-button>
            </template>
            <template v-else>
              <el-button size="small" @click="startEdit(row)">编辑</el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>

      <el-empty v-if="!loading && websiteConfigs.length === 0" description="暂无官网配置" />
    </el-card>

    <el-card v-loading="loading">
      <template #header>
        <div class="flex items-center justify-between">
          <span class="text-base font-semibold">联系方式</span>
          <el-button type="primary" @click="openCreate('contact_')">新增联系方式</el-button>
        </div>
      </template>

      <el-table :data="contactConfigs" border stripe>
        <el-table-column prop="label" label="名称" width="160" />
        <el-table-column prop="key_name" label="配置键" width="220" />
        <el-table-column label="值">
          <template #default="{ row }">
            <el-input
              v-if="editingKey === row.key_name"
              v-model="editingValue"
              type="textarea"
              :autosize="{ minRows: 1, maxRows: 4 }"
              placeholder="请输入联系方式内容"
            />
            <span v-else :class="row.value ? 'text-gray-800' : 'text-gray-400'">
              {{ row.value || '（未设置）' }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <template v-if="editingKey === row.key_name">
              <el-button size="small" type="primary" @click="saveEdit(row)">保存</el-button>
              <el-button size="small" @click="editingKey = ''">取消</el-button>
            </template>
            <template v-else>
              <el-button size="small" @click="startEdit(row)">编辑</el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>

      <el-empty v-if="!loading && contactConfigs.length === 0" description="暂无联系方式配置" />
    </el-card>

    <el-dialog v-model="createOpen" title="新增配置" width="480px">
      <el-form label-position="top">
        <el-form-item label="配置键">
          <el-input v-model="createForm.key_name" placeholder="例如 download_vpn_apk" />
        </el-form-item>
        <el-form-item label="显示名称">
          <el-input v-model="createForm.label" placeholder="例如 VPN 下载地址" />
        </el-form-item>
        <el-form-item label="配置值">
          <el-input v-model="createForm.value" type="textarea" :rows="2" placeholder="请输入链接、版本号或联系方式" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="createForm.sort_order" :min="0" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createOpen = false">取消</el-button>
        <el-button type="primary" @click="saveCreate">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
