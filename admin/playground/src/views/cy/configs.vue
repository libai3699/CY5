<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Input, Space, Table, message } from 'ant-design-vue';

import { getConfigs, updateConfig, type ConfigItem } from '#/api';

const loading = ref(false);
const rows = ref<ConfigItem[]>([]);
const values = ref<Record<string, string>>({});
const columns = [
  { dataIndex: 'label', title: '名称', width: 220 },
  { dataIndex: 'key_name', title: '配置键', width: 220 },
  { dataIndex: 'value', title: '配置值' },
  { dataIndex: 'action', title: '操作', width: 100 },
];

async function load() {
  loading.value = true;
  try {
    rows.value = await getConfigs();
    values.value = Object.fromEntries(rows.value.map((item) => [item.key_name, item.value]));
  } finally {
    loading.value = false;
  }
}

async function save(row: ConfigItem) {
  await updateConfig(row.key_name, values.value[row.key_name] || '');
  message.success('已保存');
  await load();
}

onMounted(load);
</script>

<template>
  <Page title="系统配置">
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="false" row-key="key_name">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'value'">
          <Input v-model:value="values[record.key_name]" />
        </template>
        <template v-if="column.dataIndex === 'action'">
          <Button size="small" type="primary" @click="save(record)">保存</Button>
        </template>
      </template>
    </Table>
  </Page>
</template>
