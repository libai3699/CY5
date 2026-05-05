import { webcrypto } from 'node:crypto';
import type { DownloadConfig } from '@/types';

const crypto = webcrypto as unknown as Crypto;

function bytesToBase64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('base64');
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
    ['encrypt'],
  );
}

async function aesEncrypt(plaintext: string): Promise<string> {
  const secret = process.env.APP_SECRET || 'cy5vpn_app_secret_32bytes_2026xK9';
  if (!secret) {
    throw new Error('APP_SECRET 未设置');
  }

  const encoded = new TextEncoder().encode(plaintext);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveAESKey(secret);
  
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    encoded,
  );

  const result = new Uint8Array(iv.length + ciphertext.byteLength);
  result.set(iv, 0);
  result.set(new Uint8Array(ciphertext), iv.length);

  return bytesToBase64(result);
}

export async function encryptSiteConfig(config: DownloadConfig): Promise<string> {
  const plaintext = JSON.stringify(config);
  return aesEncrypt(plaintext);
}
