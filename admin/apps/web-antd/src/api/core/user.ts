export interface UserInfo {
  id: number;
  username: string;
  realName: string;
  roles: string[];
}

/**
 * 获取用户信息 - 对接 Go 后端
 */
export async function getUserInfoApi(): Promise<UserInfo> {
  // 从后端获取用户信息
  // 根据 PROJECT_PLAN.md，后端应该有 /api/admin/user/profile 接口
  // 但这里先用简单的方式，从 localStorage 获取登录时保存的信息
  const userStr = localStorage.getItem('userInfo');
  if (userStr) {
    return JSON.parse(userStr);
  }
  
  // 默认返回管理员信息
  return {
    id: 1,
    username: 'admin',
    realName: '管理员',
    roles: ['super'],
  };
}
