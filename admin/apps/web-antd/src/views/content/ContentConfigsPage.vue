<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { getConfigList, updateConfig, type AppConfig } from '#/api/admin/configs';

const loading = ref(false);
const list = ref<AppConfig[]>([]);
const editingKey = ref('');
const editingValue = ref('');
const bulkVersion = ref('');
const bulkSaving = ref(false);

const versionConfigKeys = [
  'download_vpn_apk',
  'download_acc_apk',
  'download_vpn_exe',
  'download_acc_exe',
  'app_vpn_version',
  'app_acc_version',
];

// 配置分组定义
const groups = [
  { label: '📥 下载链接', prefix: 'download_' },
  { label: '📱 应用版本', prefix: 'app_' },
  { label: '📞 联系方式', prefix: 'contact_' },
  { label: '🔗 其他配置', prefix: '' },
];

function getGroup(keyName: string) {
  for (const g of groups.slice(0, -1)) {
    if (keyName.startsWith(g.prefix)) return g.label;
  }
  return groups[groups.length - 1]!.label;
}

function groupedList() {
  const map: Record<string, AppConfig[]> = {};
  for (const g of groups) map[g.label] = [];
  for (const item of list.value) {
    const label = getGroup(item.key_name);
    map[label]!.push(item);
  }
  return groups.map((g) => ({ label: g.label, items: map[g.label]! })).filter((g) => g.items.length > 0);
}

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

function replaceVersionValue(row: AppConfig, version: string) {
  if (row.key_name.startsWith('app_')) return version;
  const next = row.value.replace(/_\d+\.\d+\.\d+(?=\.(apk|exe)(\?|$))/i, `_${version}`);
  if (next !== row.value) return next;
  return row.value.replace(/\d+\.\d+\.\d+/, version);
}

async function applyBulkVersion() {
  const version = bulkVersion.value.trim();
  if (!/^\d+\.\d+\.\d+$/.test(version)) {
    ElMessage.warning('请输入正确版本号，例如 0.0.9');
    return;
  }

  const rows = list.value.filter((item) => versionConfigKeys.includes(item.key_name));
  if (rows.length === 0) {
    ElMessage.warning('没有找到需要更新的版本配置');
    return;
  }

  bulkSaving.value = true;
  try {
    await Promise.all(rows.map((row) => updateConfig(row.key_name, replaceVersionValue(row, version))));
    ElMessage.success(`已统一更新为 ${version}`);
    await load();
  } finally {
    bulkSaving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="p-4 space-y-4" v-loading="loading">
    <el-card>
      <div class="flex flex-wrap items-center gap-3">
        <span class="text-base font-semibold">统一版本号</span>
        <el-input v-model="bulkVersion" placeholder="例如 0.0.9" style="width:180px" clearable @keyup.enter="applyBulkVersion" />
        <el-button type="primary" :loading="bulkSaving" @click="applyBulkVersion">批量更新下载链接和版本</el-button>
        <span class="text-sm text-gray-500">会更新 4 个下载链接和 2 个应用版本，单项编辑功能保留。</span>
      </div>
    </el-card>

    <template v-for="group in groupedList()" :key="group.label">
      <el-card>
        <template #header>
          <span class="text-base font-semibold">{{ group.label }}</span>
        </template>
        <el-table :data="group.items" border stripe>
          <el-table-column prop="label" label="名称" width="180" />
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
      </el-card>
    </template>
    <el-empty v-if="!loading && list.length === 0" description="暂无配置" />
  </div>
</template>
