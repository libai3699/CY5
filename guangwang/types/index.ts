/** Route Handler 返回给客户端的下载配置 */
export interface DownloadConfig {
  vpn_apk: string;
  acc_apk: string;
  vpn_version: string;
  acc_version: string;
  contact_wechat: string;
  contact_telegram: string;
  contact_qq: string;
  contact_email: string;
}

/** Route Handler 错误响应 */
export interface DownloadConfigError {
  error: string;
}

/** 后端 /api/app/config 解密后的完整配置（键值对） */
export type BackendConfig = Record<string, string>;
