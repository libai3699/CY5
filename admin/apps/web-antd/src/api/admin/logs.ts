import { requestClient } from '#/api/request';

export interface UserLog {
  id: number;
  user_id: number;
  device_id: string;
  ip: string;
  app_version: string;
  status: number;
  fail_reason: string;
  created_at: string;
}

export interface AdminLog {
  id: number;
  username: string;
  ip: string;
  ip_detail?: {
    ip: string;
    is_private: boolean;
    location: string;
    type: string;
  };
  user_agent: string;
  status: number;
  created_at: string;
}

export interface LogListResult<T> {
  list: T[];
  total: number;
  page: number;
  size: number;
}

export const getUserLogs = (params: { page?: number; size?: number }) =>
  requestClient.get<LogListResult<UserLog>>('/logs/user', { params });

export const getAdminLogs = (params: { page?: number; size?: number }) =>
  requestClient.get<LogListResult<AdminLog>>('/logs/admin', { params });
