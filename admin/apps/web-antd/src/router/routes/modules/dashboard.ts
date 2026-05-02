import type { RouteRecordRaw } from 'vue-router';

import { $t } from '#/locales';

const routes: RouteRecordRaw[] = [
  {
    name: 'Workspace',
    path: '/workspace',
    component: () => import('#/views/dashboard/workspace/index.vue'),
    meta: {
      affixTab: true,
      icon: 'carbon:workspace',
      order: -1,
      title: $t('page.dashboard.workspace'),
    },
  },
];

export default routes;
