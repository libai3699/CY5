<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ElMessage } from 'element-plus';
import { getConfigList, updateConfig, type AppConfig } from '#/api/admin/configs';

const loading = ref(false);
const list = ref<AppConfig[]>([]);
const editingKey = ref('');
const editingValue = ref('');

async function load() {
  loading.value = true;
  try { list.value = await getConfigList() ?? []; } finally { loading.value = false; }
}

function startEdit(row: AppConfig) {
  editingKey.value = row.key_name;
  editingValue.value = row.value;
}

async function saveEdit(row: AppConfig) {
  await updateConfig(row.key_name, editingValue.value);
  ElMessage.success('保存成功');
  editingKey.value = '';
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <el-card title="系统配置" v-loading="loading">
      <el-table :data="list" border stripe>
        <el-table-column prop="label" label="配置名称" width="200" />
        <el-table-column prop="key_name" label="配置键" width="200" />
        <el-table-column label="配置值">
          <template #default="{ row }">
            <template v-if="editingKey === row.key_name">
              <el-input v-model="editingValue" style="width:100%" />
            </template>
            <template v-else>
              <span class="text-gray-600">{{ row.value || '（未设置）' }}</span>
            </template>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
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
    </el-card>
  </div>
</template>
