import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createReadStream, existsSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import { webcrypto } from 'node:crypto';

const crypto = webcrypto;
const root = process.cwd();
const distDir = join(root, 'dist');
const port = Number(process.env.PORT || 3000);

function bytesToBase64(bytes) {
  return Buffer.from(bytes).toString('base64');
}

async function deriveAESKey(secret, usage) {
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

async function encryptSiteConfig(config) {
  const secret = process.env.APP_SECRET || 'cy5vpn_app_secret_32bytes_2026xK9';
  const encoded = new TextEncoder().encode(JSON.stringify(config));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveAESKey(secret, 'encrypt');
  const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, encoded);
  const result = new Uint8Array(iv.length + ciphertext.byteLength);
  result.set(iv, 0);
  result.set(new Uint8Array(ciphertext), iv.length);
  return bytesToBase64(result);
}

function pick(config, keys) {
  for (const key of keys) {
    if (config[key]) return config[key];
  }
  return '';
}

async function handleSiteConfig(res) {
  const url = 'https://vpnapi.wangwei.tech/api/public/config';
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);

  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) throw new Error(`backend ${response.status}`);
    const json = await response.json();
    const config = json?.data ?? json ?? {};
    const plainConfig = {
      vpn_apk: pick(config, ['vpn_apk', 'download_vpn_apk', 'download_vpn_url', 'vpn_download_url']),
      acc_apk: pick(config, ['acc_apk', 'download_acc_apk', 'download_acc_url', 'acc_download_url']),
      vpn_version: pick(config, ['vpn_version', 'app_vpn_version', 'download_vpn_version']),
      acc_version: pick(config, ['acc_version', 'app_acc_version', 'download_acc_version']),
      contact_wechat: config.contact_wechat ?? '',
      contact_telegram: config.contact_telegram ?? '',
      contact_qq: config.contact_qq ?? '',
      contact_email: config.contact_email ?? '',
    };
    const encrypted = await encryptSiteConfig(plainConfig);
    sendJson(res, 200, { encrypted });
  } catch (error) {
    console.error('[site-config]', error);
    sendJson(res, 500, { error: '获取配置失败' });
  } finally {
    clearTimeout(timeout);
  }
}

function sendJson(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

async function serveStatic(req, res) {
  const url = new URL(req.url || '/', `http://${req.headers.host}`);
  const pathname = decodeURIComponent(url.pathname);
  const safePath = normalize(pathname).replace(/^(\.\.[/\\])+/, '');
  let filePath = join(distDir, safePath === '/' ? 'index.html' : safePath);

  if (!filePath.startsWith(distDir) || !existsSync(filePath)) {
    filePath = join(distDir, 'index.html');
  }

  const types = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.ico': 'image/x-icon',
  };

  try {
    await readFile(filePath);
    res.writeHead(200, {
      'Content-Type': types[extname(filePath)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    createReadStream(filePath).pipe(res);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
}

createServer((req, res) => {
  if (req.url?.startsWith('/api/site-config')) {
    void handleSiteConfig(res);
    return;
  }
  void serveStatic(req, res);
}).listen(port, () => {
  console.log(`9.9 VPN site listening on ${port}`);
});
