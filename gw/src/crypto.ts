import type { DownloadConfig } from './types';

const APP_SECRET = 'TLROCWbiOQ7SGTyVarhqiS3Cfo5OqYVxpOsSTrbUXqWw62LI';

function base64ToBytes(value: string) {
  const binary = window.atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function deriveAESKey(secret: string) {
  const encoded = new TextEncoder();
  const inputKey = await crypto.subtle.importKey('raw', encoded.encode(secret), 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: encoded.encode('cy5vpn-aes-key-v1'),
      info: encoded.encode('aes-256-gcm'),
    },
    inputKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt'],
  );
}

async function aesDecrypt(encoded: string) {
  const data = base64ToBytes(encoded);
  const iv = data.slice(0, 12);
  const ciphertextWithTag = data.slice(12);
  const key = await deriveAESKey(APP_SECRET);
  const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ciphertextWithTag);
  return new TextDecoder().decode(decrypted);
}

export async function decryptSiteConfig(encrypted: string): Promise<DownloadConfig> {
  const payload = JSON.parse(await aesDecrypt(encrypted));
  return normalizeSiteConfig(payload);
}

export function normalizeSiteConfig(payload: any): DownloadConfig {
  const config = payload?.data ?? payload ?? {};

  const pick = (...keys: string[]) => {
    for (const key of keys) {
      const value = config[key];
      if (value !== undefined && value !== null && String(value).trim() !== '') {
        return String(value);
      }
    }
    return '';
  };

  return {
    vpn_apk: pick('vpn_apk', 'download_vpn_apk', 'download_vpn_url', 'vpn_download_url'),
    acc_apk: pick('acc_apk', 'download_acc_apk', 'download_acc_url', 'acc_download_url'),
    vpn_version: pick('vpn_version', 'app_vpn_version', 'download_vpn_version'),
    acc_version: pick('acc_version', 'app_acc_version', 'download_acc_version'),
    contact_wechat: pick('contact_wechat'),
    contact_telegram: pick('contact_telegram'),
    telegram_subscription_url: pick('telegram_subscription_url', 'subscription_url'),
    contact_qq: pick('contact_qq'),
    contact_email: pick('contact_email'),
  };
}
