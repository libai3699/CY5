import { NextResponse } from 'next/server';
import { encryptSiteConfig } from '@/lib/serverCrypto';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const apiBaseUrl = process.env.API_BASE_URL || 'http://127.0.0.1:8989';
    // 走 /api/public/config 公开接口
    const url = `${apiBaseUrl.replace(/\/$/, '')}/api/public/config`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);

    let response: Response;
    try {
      response = await fetch(url, { signal: controller.signal });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!response.ok) {
      console.error(`[site-config] backend status: ${response.status}`);
      return NextResponse.json({ error: '获取配置失败' }, { status: 500 });
    }

    // 公开接口返回明文 JSON，格式：{ code: 0, data: { key: value, ... } }
    const json = await response.json();
    const config: Record<string, string> = json?.data ?? json ?? {};

    const pick = (...keys: string[]) => keys.map((key) => config[key]).find(Boolean) ?? '';

    const plainConfig = {
      vpn_apk:          pick('vpn_apk', 'download_vpn_apk', 'download_vpn_url', 'vpn_download_url'),
      acc_apk:          pick('acc_apk', 'download_acc_apk', 'download_acc_url', 'acc_download_url'),
      vpn_version:      pick('vpn_version', 'app_vpn_version', 'download_vpn_version'),
      acc_version:      pick('acc_version', 'app_acc_version', 'download_acc_version'),
      contact_wechat:   config['contact_wechat']    ?? '',
      contact_telegram: config['contact_telegram']  ?? '',
      contact_qq:       config['contact_qq']        ?? '',
      contact_email:    config['contact_email']     ?? '',
    };

    // 加密后返回
    const encrypted = await encryptSiteConfig(plainConfig);
    return NextResponse.json({ encrypted });
  } catch (err) {
    console.error('[site-config] error:', err);
    return NextResponse.json({ error: '获取配置失败' }, { status: 500 });
  }
}
