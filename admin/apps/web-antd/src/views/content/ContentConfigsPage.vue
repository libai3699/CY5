<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { getConfigList, updateConfig, type AppConfig } from '#/api/admin/configs';

const loading = ref(false);
const list = ref<AppConfig[]>([]);
const editingKey = ref('');
const editingValue = ref('');

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

onMounted(load);
</script>

<template>
  <div class="p-4 space-y-4" v-loading="loading">
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
