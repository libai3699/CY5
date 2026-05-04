import { requestClient } from '#/api/request';

export namespace AuthApi {
  export interface LoginParams {
    password?: string;
    username?: string;
  }

  export interface LoginResult {
    accessToken: string;
  }

  export interface RefreshTokenResult {
    data: string;
    status: number;
  }
}

/**
 * 登录
 */
export async function loginApi(data: AuthApi.LoginParams) {
  return requestClient.post<AuthApi.LoginResult>('/auth/login', data);
}

/**
 * 刷新 token - 后端暂无此接口，直接返回当前 token
 */
export async function refreshTokenApi() {
  const token = localStorage.getItem('accessToken') || '';
  return Promise.resolve({ data: token, status: 0 });
}

/**
 * 退出登录 - 前端清除即可
 */
export async function logoutApi() {
  localStorage.removeItem('accessToken');
  return Promise.resolve({ code: 0 });
}

/**
 * 获取权限码 - 管理员拥有所有权限
 */
export async function getAccessCodesApi() {
  return Promise.resolve(['AC_100100', 'AC_100110', 'AC_100120', 'AC_100010']);
}
