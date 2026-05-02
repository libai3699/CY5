import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    meta: { icon: 'carbon:user-multiple', order: 1, title: '用户管理' },
    name: 'UserMgmt',
    path: '/users',
    children: [
      {
        name: 'UserList',
        path: '/users/list',
        component: () => import('#/views/users/index.vue'),
        meta: { icon: 'carbon:user', title: '用户列表' },
      },
      {
        name: 'DeviceList',
        path: '/users/devices',
        component: () => import('#/views/users/devices.vue'),
        meta: { icon: 'carbon:mobile', title: '设备管理' },
      },
    ],
  },
  {
    meta: { icon: 'carbon:purchase', order: 2, title: '套餐管理' },
    name: 'PlanMgmt',
    path: '/plans',
    children: [
      {
        name: 'PlanList',
        path: '/plans/list',
        component: () => import('#/views/plans/index.vue'),
        meta: { icon: 'carbon:list', title: '套餐列表' },
      },
      {
        name: 'OrderList',
        path: '/plans/orders',
        component: () => import('#/views/plans/orders.vue'),
        meta: { icon: 'carbon:document', title: '订单管理' },
      },
    ],
  },
  {
    meta: { icon: 'carbon:settings', order: 3, title: '内容管理' },
    name: 'ContentMgmt',
    path: '/content',
    children: [
      {
        name: 'NoticeList',
        path: '/content/notices',
        component: () => import('#/views/content/notices.vue'),
        meta: { icon: 'carbon:notification', title: '公共通知' },
      },
      {
        name: 'ConfigList',
        path: '/content/configs',
        component: () => import('#/views/content/configs.vue'),
        meta: { icon: 'carbon:settings-adjust', title: '系统配置' },
      },
    ],
  },
  {
    meta: { icon: 'carbon:document', order: 4, title: '日志管理' },
    name: 'LogMgmt',
    path: '/logs',
    children: [
      {
        name: 'UserLogs',
        path: '/logs/user',
        component: () => import('#/views/logs/user.vue'),
        meta: { icon: 'carbon:user-activity', title: '用户登录日志' },
      },
      {
        name: 'AdminLogs',
        path: '/logs/admin',
        component: () => import('#/views/logs/admin.vue'),
        meta: { icon: 'carbon:security', title: '后台登录日志' },
      },
    ],
  },
];

export default routes;
