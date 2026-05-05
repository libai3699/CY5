/**
 * Route Handler 属性测试
 * Feature: official-website
 *
 * 测试 /api/site-config Route Handler 的字段提取完整性和错误处理
 */

import * as fc from 'fast-check';
import { aesEncrypt } from '../lib/crypto';

// 设置测试环境变量
beforeAll(() => {
  process.env.APP_SECRET = 'test-secret-for-unit-tests-only-32chars!!';
  process.env.API_BASE_URL = 'http://localhost:8989';
});

afterAll(() => {
  delete process.env.APP_SECRET;
  delete process.env.API_BASE_URL;
});

// ── 辅助函数：调用 Route Handler ─────────────────────────────────────────────

/**
 * 模拟调用 Route Handler，mock fetch 返回加密的后端响应
 */
async function callRouteHandler(encryptedResponse: string, fetchStatus = 200) {
  // 动态 mock fetch
  global.fetch = jest.fn().mockResolvedValueOnce({
    ok: fetchStatus >= 200 && fetchStatus < 300,
    status: fetchStatus,
    text: async () => encryptedResponse,
  } as Response);

  // 动态 import Route Handler（避免模块缓存问题）
  jest.resetModules();
  const { GET } = await import('../app/api/site-config/route');
  const response = await GET();
  return response.json();
}

// ── 属性 2：下载配置字段提取完整性 ───────────────────────────────────────────

describe('属性 2：下载配置字段提取完整性', () => {
  /**
   * Validates: Requirements 1.3
   *
   * Feature: official-website, Property 2: 下载配置字段提取完整性
   * 对于任意包含所需字段的后端配置 JSON，经加密后由 Route Handler 解密并提取，
   * 返回的配置对象中各字段值必须与原始 JSON 中对应字段值完全一致。
   */
  it('字段提取应与原始配置完全一致', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          download_vpn_apk: fc.string(),
          download_acc_apk: fc.string(),
          app_vpn_version: fc.string(),
          app_acc_version: fc.string(),
          contact_wechat: fc.string(),
          contact_telegram: fc.string(),
          contact_qq: fc.string(),
          contact_email: fc.string(),
        }),
        async (backendConfig) => {
          const encrypted = aesEncrypt(JSON.stringify(backendConfig));
          const result = await callRouteHandler(encrypted);

          return (
            result.vpn_apk === backendConfig.download_vpn_apk &&
            result.acc_apk === backendConfig.download_acc_apk &&
            result.vpn_version === backendConfig.app_vpn_version &&
            result.acc_version === backendConfig.app_acc_version &&
            result.contact_wechat === backendConfig.contact_wechat &&
            result.contact_telegram === backendConfig.contact_telegram &&
            result.contact_qq === backendConfig.contact_qq &&
            result.contact_email === backendConfig.contact_email
          );
        },
      ),
      { numRuns: 100 },
    );
  });
});

// ── 错误场景单元测试 ──────────────────────────────────────────────────────────

describe('Route Handler 错误处理', () => {
  it('fetch 失败时应返回 500', async () => {
    global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'));

    jest.resetModules();
    const { GET } = await import('../app/api/site-config/route');
    const response = await GET();
    const data = await response.json();

    expect(response.status).toBe(500);
    expect(data.error).toBeDefined();
  });

  it('后端返回非 200 状态码时应返回 500', async () => {
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: false,
      status: 503,
      text: async () => '',
    } as Response);

    jest.resetModules();
    const { GET } = await import('../app/api/site-config/route');
    const response = await GET();
    const data = await response.json();

    expect(response.status).toBe(500);
    expect(data.error).toBeDefined();
  });

  it('后端返回非法 Base64 时应返回 500', async () => {
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () => 'invalid!base64!!',
    } as Response);

    jest.resetModules();
    const { GET } = await import('../app/api/site-config/route');
    const response = await GET();
    const data = await response.json();

    expect(response.status).toBe(500);
    expect(data.error).toBeDefined();
  });

  it('缺失字段时应默认为空字符串', async () => {
    // 只包含部分字段的配置
    const partialConfig = {
      download_vpn_apk: 'https://example.com/vpn.apk',
      // 其他字段缺失
    };
    const encrypted = aesEncrypt(JSON.stringify(partialConfig));
    const result = await callRouteHandler(encrypted);

    expect(result.vpn_apk).toBe('https://example.com/vpn.apk');
    expect(result.acc_apk).toBe('');
    expect(result.vpn_version).toBe('');
    expect(result.acc_version).toBe('');
  });
});
