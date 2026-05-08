import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { webcrypto } from 'node:crypto';

const crypto = webcrypto;

function readAppSecret() {
  if (process.env.APP_SECRET) return process.env.APP_SECRET;
  const root = process.cwd();
  const envPath = join(root, '.env');
  const serverEnvPath = join(root, '..', 'server', '.env');
  for (const path of [envPath, serverEnvPath]) {
    if (!existsSync(path)) continue;
    const text = readFileSync(path, 'utf8');
    for (const line of text.split(/\r?\n/)) {
      const match = /^APP_SECRET=(.*)$/.exec(line.trim());
      if (match?.[1]) return match[1];
    }
  }
  return '';
}

async function deriveAESKey(secret: string, usage: KeyUsage) {
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
    [usage],
  );
}

async function decryptSiteConfig(encrypted: string) {
  const secret = readAppSecret();
  if (!secret) throw new Error('APP_SECRET is required');
  const data = Buffer.from(encrypted, 'base64');
  const iv = data.subarray(0, 12);
  const ciphertextWithTag = data.subarray(12);
  const key = await deriveAESKey(secret, 'decrypt');
  const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ciphertextWithTag);
  return JSON.parse(new TextDecoder().decode(decrypted));
}

function pick(config: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = config[key];
    if (value !== undefined && value !== null && String(value).trim() !== '') return String(value);
  }
  return '';
}

function normalizeConfig(config: Record<string, unknown>) {
  return {
    vpn_apk: pick(config, ['vpn_apk', 'download_vpn_apk', 'download_vpn_url', 'vpn_download_url']),
    acc_apk: pick(config, ['acc_apk', 'download_acc_apk', 'download_acc_url', 'acc_download_url']),
    vpn_version: pick(config, ['vpn_version', 'app_vpn_version', 'download_vpn_version']),
    acc_version: pick(config, ['acc_version', 'app_acc_version', 'download_acc_version']),
    contact_wechat: pick(config, ['contact_wechat']),
    contact_telegram: pick(config, ['contact_telegram']),
    telegram_subscription_url: pick(config, ['telegram_subscription_url', 'subscription_url']),
    contact_qq: pick(config, ['contact_qq']),
    contact_email: pick(config, ['contact_email']),
  };
}

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'site-config-dev',
      configureServer(server) {
        server.middlewares.use('/api/site-config', async (_req, res) => {
          try {
            const response = await fetch('https://vpnapi.wangwei.tech/api/public/config');
            if (!response.ok) throw new Error(`backend ${response.status}`);
            const json = await response.json();
            const encrypted = json?.encrypted ?? json?.data?.encrypted;
            let rawConfig = json?.data ?? json ?? {};
            if (encrypted) {
              try {
                rawConfig = await decryptSiteConfig(encrypted);
              } catch (error) {
                console.error('[site-config-dev decrypt]', error);
                throw error;
              }
            }
            const config = normalizeConfig(rawConfig?.data ?? rawConfig ?? {});
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            res.setHeader('Cache-Control', 'no-store');
            res.end(JSON.stringify(config));
          } catch (error) {
            console.error('[site-config-dev]', error);
            res.statusCode = 500;
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            res.end(JSON.stringify({ error: error instanceof Error ? error.message : '获取配置失败' }));
          }
        });
      },
    },
  ],
});
