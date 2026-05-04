<script lang="ts" setup>
import { ConfigProvider, App } from 'ant-design-vue';
import { antdLocale } from '#/locales';

defineOptions({ name: 'App' });
</script>

<template>
  <ConfigProvider :locale="antdLocale">
    <App>
      <RouterView />
    </App>
  </ConfigProvider>
</template>
