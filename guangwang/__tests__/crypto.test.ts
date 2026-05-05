/**
 * 加解密模块属性测试
 * Feature: official-website
 *
 * 使用 fast-check 进行属性测试，验证 aesDecrypt 的正确性
 */

import * as fc from 'fast-check';
import { aesDecrypt, aesEncrypt } from '../lib/crypto';

// 设置测试用的 APP_SECRET
beforeAll(() => {
  process.env.APP_SECRET = 'test-secret-for-unit-tests-only-32chars!!';
});

afterAll(() => {
  delete process.env.APP_SECRET;
});

// ── 辅助函数 ──────────────────────────────────────────────────────────────────

/**
 * 篡改 Base64 编码数据中 IV 之后的某个字节
 * IV 为前 12 字节，Base64 编码后每 3 字节对应 4 个 Base64 字符
 */
function tamperByteAfterIV(encoded: string, offsetFromIV: number): string {
  const data = Buffer.from(encoded, 'base64');
  const IV_SIZE = 12;

  if (data.length <= IV_SIZE) {
    // 数据太短，直接篡改最后一个字节
    const tampered = Buffer.from(data);
    tampered[tampered.length - 1] ^= 0xff;
    return tampered.toString('base64');
  }

  // 在 IV 之后的位置篡改
  const tamperIndex = IV_SIZE + (offsetFromIV % (data.length - IV_SIZE));
  const tampered = Buffer.from(data);
  tampered[tamperIndex] ^= 0x01; // 翻转最低位
  return tampered.toString('base64');
}

// ── 属性 1：解密往返一致性 ────────────────────────────────────────────────────

describe('属性 1：解密往返一致性', () => {
  /**
   * Validates: Requirements 1.2, 6.2, 6.3
   *
   * Feature: official-website, Property 1: 解密往返一致性
   * 对于任意明文字符串，使用 aesEncrypt 加密后再用 aesDecrypt 解密，
   * 所得明文必须与原始明文完全相同。
   */
  it('任意明文加密后解密应还原为原始明文', () => {
    fc.assert(
      fc.property(
        fc.string(), // 任意明文（含空字符串、Unicode、超长）
        (plaintext) => {
          const encrypted = aesEncrypt(plaintext);
          const decrypted = aesDecrypt(encrypted);
          return decrypted === plaintext;
        },
      ),
      { numRuns: 100 },
    );
  });

  it('空字符串往返一致', () => {
    const encrypted = aesEncrypt('');
    const decrypted = aesDecrypt(encrypted);
    expect(decrypted).toBe('');
  });

  it('Unicode 字符串往返一致', () => {
    const plaintext = '你好世界 🌍 Hello World';
    const encrypted = aesEncrypt(plaintext);
    const decrypted = aesDecrypt(encrypted);
    expect(decrypted).toBe(plaintext);
  });

  it('JSON 字符串往返一致', () => {
    const json = JSON.stringify({
      download_vpn_apk: 'https://example.com/vpn.apk',
      download_acc_apk: 'https://example.com/acc.apk',
      app_vpn_version: '1.2.3',
      app_acc_version: '1.2.3',
    });
    const encrypted = aesEncrypt(json);
    const decrypted = aesDecrypt(encrypted);
    expect(decrypted).toBe(json);
  });
});

// ── 属性 5：非法 Base64 输入必须抛出错误 ─────────────────────────────────────

describe('属性 5：非法 Base64 输入必须抛出错误', () => {
  /**
   * Validates: Requirements 6.4
   *
   * Feature: official-website, Property 5: 非法 Base64 输入必须抛出错误
   * 对于任意包含非 Base64 合法字符的字符串，调用 aesDecrypt 必须抛出可捕获的错误。
   */
  it('含非法字符的字符串应抛出错误', () => {
    fc.assert(
      fc.property(
        // 生成包含非 Base64 字符（如 !、@、中文等）的字符串
        fc.string().filter((s) => /[^A-Za-z0-9+/=]/.test(s)),
        (invalidInput) => {
          expect(() => aesDecrypt(invalidInput)).toThrow();
          return true;
        },
      ),
      { numRuns: 100 },
    );
  });

  it('包含感叹号的字符串应抛出错误', () => {
    expect(() => aesDecrypt('invalid!base64')).toThrow();
  });

  it('包含中文字符的字符串应抛出错误', () => {
    expect(() => aesDecrypt('非法输入')).toThrow();
  });

  it('包含 @ 符号的字符串应抛出错误', () => {
    expect(() => aesDecrypt('abc@def')).toThrow();
  });
});

// ── 属性 6：GCM Tag 校验失败必须抛出错误 ─────────────────────────────────────

describe('属性 6：GCM Tag 校验失败必须抛出错误', () => {
  /**
   * Validates: Requirements 6.5
   *
   * Feature: official-website, Property 6: GCM Tag 校验失败必须抛出错误
   * 对于任意明文字符串，将其加密后随机篡改密文部分的任意一个字节，
   * 调用 aesDecrypt 必须抛出可捕获的错误。
   */
  it('篡改密文字节后解密应抛出错误', () => {
    fc.assert(
      fc.property(
        fc.string({ minLength: 1 }),
        fc.integer({ min: 0, max: 99 }),
        (plaintext, offset) => {
          const encrypted = aesEncrypt(plaintext);
          const tampered = tamperByteAfterIV(encrypted, offset);
          expect(() => aesDecrypt(tampered)).toThrow();
          return true;
        },
      ),
      { numRuns: 100 },
    );
  });

  it('篡改 Tag 字节后解密应抛出错误', () => {
    const plaintext = 'hello world';
    const encrypted = aesEncrypt(plaintext);
    const data = Buffer.from(encrypted, 'base64');

    // 篡改最后一个字节（Tag 的最后一字节）
    data[data.length - 1] ^= 0xff;
    const tampered = data.toString('base64');

    expect(() => aesDecrypt(tampered)).toThrow();
  });

  it('数据长度不足时应抛出错误', () => {
    // 少于 28 字节（12 IV + 16 Tag）的有效 Base64
    const shortData = Buffer.alloc(10).toString('base64');
    expect(() => aesDecrypt(shortData)).toThrow();
  });
});
