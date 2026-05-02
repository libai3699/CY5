import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    meta: {
      icon: 'lucide:shield',
      order: -10,
      title: 'CY VPN',
    },
    name: 'CyVpn',
    path: '/cy',
    children: [
      {
        component: () => import('#/views/cy/dashboard.vue'),
        meta: { affixTab: true, icon: 'lucide:gauge', title: '仪表盘' },
        name: 'CyDashboard',
        path: '/cy/dashboard',
      },
      {
        component: () => import('#/views/cy/users.vue'),
        meta: { icon: 'lucide:users', title: '用户管理' },
        name: 'CyUsers',
        path: '/cy/users',
      },
      {
        component: () => import('#/views/cy/devices.vue'),
        meta: { icon: 'lucide:smartphone', title: '设备管理' },
        name: 'CyDevices',
        path: '/cy/devices',
      },
      {
        component: () => import('#/views/cy/plans.vue'),
        meta: { icon: 'lucide:package', title: '套餐管理' },
        name: 'CyPlans',
        path: '/cy/plans',
      },
      {
        component: () => import('#/views/cy/orders.vue'),
        meta: { icon: 'lucide:receipt', title: '订单管理' },
        name: 'CyOrders',
        path: '/cy/orders',
      },
      {
        meta: { icon: 'lucide:file-text', title: '内容管理' },
        name: 'CyContent',
        path: '/cy/content',
        children: [
          {
            component: () => import('#/views/cy/notices.vue'),
            meta: { icon: 'lucide:bell', title: '公共通知' },
            name: 'CyNotices',
            path: '/cy/content/notices',
          },
          {
            component: () => import('#/views/cy/configs.vue'),
            meta: { icon: 'lucide:settings', title: '系统配置' },
            name: 'CyConfigs',
            path: '/cy/content/configs',
          },
          {
            component: () => import('#/views/cy/files.vue'),
            meta: { icon: 'lucide:download', title: '安装包管理' },
            name: 'CyFiles',
            path: '/cy/content/files',
          },
        ],
      },
      {
        meta: { icon: 'lucide:logs', title: '日志管理' },
        name: 'CyLogs',
        path: '/cy/logs',
        children: [
          {
            component: () => import('#/views/cy/user-logs.vue'),
            meta: { icon: 'lucide:log-in', title: '前台登录日志' },
            name: 'CyUserLogs',
            path: '/cy/logs/user',
          },
          {
            component: () => import('#/views/cy/admin-logs.vue'),
            meta: { icon: 'lucide:shield-check', title: '后台登录日志' },
            name: 'CyAdminLogs',
            path: '/cy/logs/admin',
          },
        ],
      },
    ],
  },
];

export default routes;
