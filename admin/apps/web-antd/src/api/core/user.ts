import { requestClient } from '#/api/request';

export interface UserInfo {
  id: number;
  username: string;
  realName: string;
  avatar?: string;
  roles: string[];
  homePath?: string;
}

/**
 * 获取用户信息 - 对接 Go 后端 /api/admin/user/info
 */
export async function getUserInfoApi(): Promise<UserInfo> {
  return requestClient.get<UserInfo>('/user/info');
}
