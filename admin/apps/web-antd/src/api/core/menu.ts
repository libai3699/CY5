import type { RouteRecordStringComponent } from '@vben/types';

/**
 * 获取用户所有菜单 - 前端写死，不需要后端接口
 * component 路径需匹配 import.meta.glob('../views/**\/*.vue') 的 key 格式
 */
export async function getAllMenusApi(): Promise<RouteRecordStringComponent[]> {
  return Promise.resolve([
    {
      name: 'WorkspacePage',
      path: '/workspace',
      component: '../views/dashboard/WorkspacePage.vue',
      meta: {
        affixTab: true,
        icon: 'carbon:dashboard',
        order: -1,
        title: '仪表盘',
      },
    },
    {
      meta: { icon: 'carbon:user-multiple', order: 1, title: '用户管理' },
      name: 'UserMgmt',
      path: '/users',
      children: [
        {
          name: 'UserListPage',
          path: '/users/list',
          component: '../views/users/UserListPage.vue',
          meta: { icon: 'carbon:user', title: '用户列表' },
        },
        {
          name: 'UserDevicesPage',
          path: '/users/devices',
          component: '../views/users/UserDevicesPage.vue',
          meta: { icon: 'carbon:mobile', title: '设备管理' },
        },
        {
          name: 'DurationLogPage',
          path: '/users/duration-logs',
          component: '../views/users/DurationLogPage.vue',
          meta: { icon: 'carbon:time', title: '追加记录' },
        },
      ],
    },
    {
      meta: { icon: 'carbon:purchase', order: 2, title: '套餐管理' },
      name: 'PlanMgmt',
      path: '/plans',
      children: [
        {
          name: 'PlanListPage',
          path: '/plans/list',
          component: '../views/plans/PlanListPage.vue',
          meta: { icon: 'carbon:list', title: '套餐列表' },
        },
        {
          name: 'PlanOrdersPage',
          path: '/plans/orders',
          component: '../views/plans/PlanOrdersPage.vue',
          meta: { icon: 'carbon:document', title: '订单管理' },
        },
      ],
    },
    {
      meta: { icon: 'carbon:network-4', order: 3, title: '线路管理' },
      name: 'LineMgmt',
      path: '/lines',
      children: [
        {
          name: 'LineListPage',
          path: '/lines/list',
          component: '../views/lines/LineListPage.vue',
          meta: { icon: 'carbon:network-4', title: '线路列表' },
        },
      ],
    },
    {
      meta: { icon: 'carbon:settings', order: 4, title: '内容管理' },
      name: 'ContentMgmt',
      path: '/content',
      children: [
        {
          name: 'ContentNoticesPage',
          path: '/content/notices',
          component: '../views/content/ContentNoticesPage.vue',
          meta: { icon: 'carbon:notification', title: '公共通知' },
        },
        {
          name: 'ContentQuotesPage',
          path: '/content/quotes',
          component: '../views/content/ContentQuotesPage.vue',
          meta: { icon: 'carbon:quotes', title: '精选语录' },
        },
        {
          name: 'ContentDiscoveriesPage',
          path: '/content/discoveries',
          component: '../views/content/ContentDiscoveriesPage.vue',
          meta: { icon: 'carbon:compass', title: '发现宝藏' },
        },
        {
          name: 'ContentPaymentsPage',
          path: '/content/payments',
          component: '../views/content/ContentPaymentsPage.vue',
          meta: { icon: 'carbon:wallet', title: '支付配置' },
        },
        {
          name: 'ContentConfigsPage',
          path: '/content/configs',
          component: '../views/content/ContentConfigsPage.vue',
          meta: { icon: 'carbon:settings-adjust', title: '系统配置' },
        },
      ],
    },
    {
      meta: { icon: 'carbon:document', order: 5, title: '日志管理' },
      name: 'LogMgmt',
      path: '/logs',
      children: [
        {
          name: 'LogUserPage',
          path: '/logs/user',
          component: '../views/logs/LogUserPage.vue',
          meta: { icon: 'carbon:user-activity', title: '用户登录日志' },
        },
        {
          name: 'LogAdminPage',
          path: '/logs/admin',
          component: '../views/logs/LogAdminPage.vue',
          meta: { icon: 'carbon:security', title: '后台登录日志' },
        },
      ],
    },
  ]);
}
