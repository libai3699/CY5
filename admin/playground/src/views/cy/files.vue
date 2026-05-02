<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { Page } from '@vben/common-ui';

import { Button, Input, Table, Upload, message } from 'ant-design-vue';

import { deleteFile, getFiles, updateConfig, uploadFile } from '#/api';

const labels: Record<string, string> = {
  download_acc_apk: '9点9 加速器 APK',
  download_acc_exe: '9点9 加速器 EXE',
  download_vpn_apk: '9点9 VPN APK',
  download_vpn_exe: '9点9 VPN EXE',
};
const uploadKeys: Record<string, string> = {
  download_acc_apk: 'acc_apk',
  download_acc_exe: 'acc_exe',
  download_vpn_apk: 'vpn_apk',
  download_vpn_exe: 'vpn_exe',
};
const loading = ref(false);
const rows = ref<{ key: string; label: string; url: string }[]>([]);
const columns = [
  { dataIndex: 'label', title: '文件' },
  { dataIndex: 'url', title: '下载链接' },
  { dataIndex: 'action', title: '操作', width: 160 },
];

async function load() {
  loading.value = true;
  try {
    const data = await getFiles();
    rows.value = Object.keys(labels).map((key) => ({ key, label: labels[key]!, url: data[key] || '' }));
  } finally {
    loading.value = false;
  }
}

async function save(row: { key: string; url: string }) {
  await updateConfig(row.key, row.url);
  message.success('已保存链接');
  await load();
}

async function clear(row: { key: string }) {
  await deleteFile(row.key);
  message.success('已清空');
  await load();
}

async function upload(row: { key: string }, options: any) {
  const data = new FormData();
  data.append('file_key', uploadKeys[row.key] || row.key);
  data.append('file', options.file);
  try {
    await uploadFile(data);
    message.success('已上传');
    options.onSuccess?.({});
    await load();
  } catch (error) {
    options.onError?.(error);
  }
}

onMounted(load);
</script>

<template>
  <Page title="安装包管理">
    <Table :columns="columns" :data-source="rows" :loading="loading" :pagination="false" row-key="key">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'url'">
          <Input v-model:value="record.url" placeholder="云存储公开下载 URL" />
        </template>
        <template v-if="column.dataIndex === 'action'">
          <Upload :custom-request="(options)=>upload(record, options)" :max-count="1" :show-upload-list="false">
            <Button size="small">上传</Button>
          </Upload>
          <Button class="ml-2" size="small" type="primary" @click="save(record)">保存</Button>
          <Button class="ml-2" danger size="small" @click="clear(record)">清空</Button>
        </template>
      </template>
    </Table>
  </Page>
</template>
