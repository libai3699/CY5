import { requestClient } from '#/api/request';

export interface Stats {
  total_users: number;
  total_devices: number;
  active_orders: number;
  today_new: number;
}

export const getStats = () =>
  requestClient.get<Stats>('/stats');
