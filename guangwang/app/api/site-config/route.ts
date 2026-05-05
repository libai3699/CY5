import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const apiBaseUrl = process.env.API_BASE_URL || 'http://127.0.0.1:8989';
    const url = `${apiBaseUrl.replace(/\/$/, '')}/api/app/config`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);

    let response: Response;
    try {
      response = await fetch(url, {
        signal: controller.signal,
        headers: {
          Accept: 'text/plain',
        },
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!response.ok) {
      console.error(`[site-config] backend status: ${response.status}`);
      return NextResponse.json({ error: '获取配置失败' }, { status: 500 });
    }

    const encrypted = await response.text();
    return NextResponse.json({ encrypted: encrypted.trim() });
  } catch (err) {
    console.error('[site-config] error:', err);
    return NextResponse.json({ error: '获取配置失败' }, { status: 500 });
  }
}
