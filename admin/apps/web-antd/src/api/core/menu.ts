import type { RouteRecordStringComponent } from '@vben/types';

import { requestClient } from '#/api/request';

/**
 * 获取用户所有菜单 - 对接 Go 后端
 */
export async function getAllMenusApi(): Promise<RouteRecordStringComponent[]> {
  // 根据 PROJECT_PLAN.md，后端没有菜单接口
  // 后台菜单直接在前端写死
  return Promise.resolve([
    {
      name: 'Workspace',
      path: '/workspace',
      component: '/dashboard/workspace/index',
      meta: {
        affixTab: true,
        icon: 'carbon:workspace',
        order: -1,
        title: '工作台',
      },
    },
    {
      meta: {
        icon: 'carbon:settings',
        order: 1,
        title: '系统管理',
      },
      name: 'System',
      path: '/system',
      children: [
        {
          name: 'UserManagement',
          path: '/system/user',
          component: '/system/user/index',
          meta: {
            icon: 'carbon:user-multiple',
            title: '用户管理',
          },
        },
      ],
    },
  ]);
}
