<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { getConfigList, updateConfig, type AppConfig } from '#/api/admin/configs';

const loading = ref(false);
const list = ref<AppConfig[]>([]);
const editingKey = ref('');
const editingValue = ref('');

async function load() {
  loading.value = true;
  try { list.value = await getConfigList(); } finally { loading.value = false; }
}

function startEdit(record: AppConfig) {
  editingKey.value = record.key_name;
  editingValue.value = record.value;
}

async function saveEdit(record: AppConfig) {
  await updateConfig(record.key_name, editingValue.value);
  message.success('保存成功');
  editingKey.value = '';
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <a-card title="系统配置" :bordered="false" :loading="loading">
      <a-list :data-source="list" item-layout="horizontal">
        <template #renderItem="{ item }">
          <a-list-item>
            <a-list-item-meta :title="item.label" :description="item.key_name" />
            <template #actions>
              <template v-if="editingKey === item.key_name">
                <a-input v-model:value="editingValue" style="width:300px" />
                <a-button type="link" @click="saveEdit(item)">保存</a-button>
                <a-button type="link" @click="editingKey = ''">取消</a-button>
              </template>
              <template v-else>
                <span class="mr-4 text-gray-500">{{ item.value || '（未设置）' }}</span>
                <a-button type="link" @click="startEdit(item)">编辑</a-button>
              </template>
            </template>
          </a-list-item>
        </template>
      </a-list>
    </a-card>
  </div>
</template>
