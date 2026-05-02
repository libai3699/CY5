import type { Recordable } from '@vben/types';

import { requestClient } from '#/api/request';

export interface PageResult<T> {
  list: T[];
  page: number;
  size: number;
  total: number;
}

export interface AdminStats {
  active_orders: number;
  today_new: number;
  total_devices: number;
  total_users: number;
}

export interface UserItem {
  created_at?: string;
  current_plan_id?: number;
  device_id?: string;
  free_limit_seconds: number;
  free_used_seconds: number;
  id: number;
  last_login_at?: string;
  phone?: string;
  plan_expired_at?: string;
  status: 0 | 1;
  username: string;
}

export interface DeviceItem {
  app_version?: string;
  brand?: string;
  created_at?: string;
  device_id: string;
  id: number;
  last_ip?: string;
  last_seen_at?: string;
  model?: string;
  os_version?: string;
  user_id?: number;
}

export interface PlanItem {
  duration_days: number;
  id: number;
  is_active: 0 | 1;
  name: string;
  price: number;
  sort_order: number;
  traffic_gb?: number | null;
}

export interface OrderItem {
  created_at?: string;
  duration_days: number;
  expired_at: string;
  id: number;
  plan_id: number;
  plan_name: string;
  plan_price: number;
  remark?: string;
  started_at: string;
  traffic_gb?: number | null;
  user_id: number;
}

export interface ConfigItem {
  id: number;
  key_name: string;
  label: string;
  sort_order: number;
  updated_at?: string;
  value: string;
}

export interface NoticeItem {
  content: string;
  created_at?: string;
  id: number;
  is_active: 0 | 1;
  sort_order: number;
  type: 1 | 2;
}

export interface LoginLogItem {
  app_version?: string;
  created_at?: string;
  device_id?: string;
  fail_reason?: string;
  id: number;
  ip?: string;
  status: 0 | 1;
  user_agent?: string;
  user_id?: number;
  username?: string;
}

export function getStats() {
  return requestClient.get<AdminStats>('/admin/stats');
}

export function getUsers(params: Recordable<any>) {
  return requestClient.get<PageResult<UserItem>>('/admin/users', { params });
}

export function createUser(data: Recordable<any>) {
  return requestClient.post('/admin/users', data);
}

export function updateUser(id: number, data: Recordable<any>) {
  return requestClient.put(`/admin/users/${id}`, data);
}

export function deleteUser(id: number) {
  return requestClient.delete(`/admin/users/${id}`);
}

export function getDevices(params: Recordable<any>) {
  return requestClient.get<PageResult<DeviceItem>>('/admin/devices', { params });
}

export function getPlans() {
  return requestClient.get<PlanItem[]>('/admin/plans');
}

export function createPlan(data: Recordable<any>) {
  return requestClient.post('/admin/plans', data);
}

export function updatePlan(id: number, data: Recordable<any>) {
  return requestClient.put(`/admin/plans/${id}`, data);
}

export function deletePlan(id: number) {
  return requestClient.delete(`/admin/plans/${id}`);
}

export function getOrders(params: Recordable<any>) {
  return requestClient.get<PageResult<OrderItem>>('/admin/orders', { params });
}

export function createOrder(data: Recordable<any>) {
  return requestClient.post('/admin/orders', data);
}

export function getConfigs() {
  return requestClient.get<ConfigItem[]>('/admin/configs');
}

export function updateConfig(key: string, value: string) {
  return requestClient.put(`/admin/configs/${key}`, { value });
}

export function getNotices() {
  return requestClient.get<NoticeItem[]>('/admin/notices');
}

export function createNotice(data: Recordable<any>) {
  return requestClient.post('/admin/notices', data);
}

export function updateNotice(id: number, data: Recordable<any>) {
  return requestClient.put(`/admin/notices/${id}`, data);
}

export function deleteNotice(id: number) {
  return requestClient.delete(`/admin/notices/${id}`);
}

export function getFiles() {
  return requestClient.get<Record<string, string>>('/admin/files');
}

export function uploadFile(data: FormData) {
  return requestClient.post<{ key: string; url: string }>(
    '/admin/files/upload',
    data,
    {
      headers: { 'Content-Type': 'multipart/form-data' },
    },
  );
}

export function deleteFile(key: string) {
  return requestClient.delete(`/admin/files/${key}`);
}

export function getUserLogs(params: Recordable<any>) {
  return requestClient.get<PageResult<LoginLogItem>>('/admin/logs/user', {
    params,
  });
}

export function getAdminLogs(params: Recordable<any>) {
  return requestClient.get<PageResult<LoginLogItem>>('/admin/logs/admin', {
    params,
  });
}
