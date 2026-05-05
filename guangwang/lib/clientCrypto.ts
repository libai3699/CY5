import type { BackendConfig, DownloadConfig } from '@/types';

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
  const inputKey = await crypto.subtle.importKey(
    'raw',
    encoded.encode(secret),
    'HKDF',
    false,
    ['deriveKey'],
  );

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
  const secret = process.env.NEXT_PUBLIC_APP_SECRET || 'cy5vpn_app_secret_32bytes_2026xK9';
  if (!secret) {
    throw new Error('NEXT_PUBLIC_APP_SECRET 未设置');
  }

  const data = base64ToBytes(encoded);
  const iv = data.slice(0, 12);
  const ciphertextWithTag = data.slice(12);
  const key = await deriveAESKey(secret);
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    ciphertextWithTag,
  );

  return new TextDecoder().decode(decrypted);
}

export async function decryptSiteConfig(encrypted: string): Promise<DownloadConfig> {
  // 使用解密功能
  const plaintext = await aesDecrypt(encrypted);
  const payload = JSON.parse(plaintext);
  const config: BackendConfig = payload?.data ?? payload;

  return {
    vpn_apk: config.download_vpn_apk ?? '',
    acc_apk: config.download_acc_apk ?? '',
    vpn_version: config.app_vpn_version ?? '',
    acc_version: config.app_acc_version ?? '',
    contact_wechat: config.contact_wechat ?? '',
    contact_telegram: config.contact_telegram ?? '',
    contact_qq: config.contact_qq ?? '',
    contact_email: config.contact_email ?? '',
  };
}
