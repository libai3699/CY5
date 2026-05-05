// 此模块仅在服务端（Next.js Route Handler）中使用
// 不得在客户端组件中 import，否则会将 APP_SECRET 暴露到客户端 bundle

import { createDecipheriv, createCipheriv, hkdfSync, randomBytes } from 'crypto';

/**
 * 从 APP_SECRET 派生 32 字节 AES-256-GCM 密钥
 * 与后端 Go 实现完全对称：
 *   HKDF(SHA-256, APP_SECRET, salt="cy5vpn-aes-key-v1", info="aes-256-gcm", length=32)
 */
function deriveAESKey(): Buffer {
  const secret = process.env.APP_SECRET;
  if (!secret) {
    throw new Error('APP_SECRET 环境变量未设置');
  }

  const key = hkdfSync(
    'sha256',
    Buffer.from(secret, 'utf8'),
    Buffer.from('cy5vpn-aes-key-v1', 'utf8'),
    Buffer.from('aes-256-gcm', 'utf8'),
    32,
  );

  return Buffer.from(key);
}

/**
 * 解密后端 AES-256-GCM 加密的 Base64 字符串
 *
 * 输入格式：Base64StdEncoding( IV[12字节] || 密文[N字节] || GCM_Tag[16字节] )
 *
 * @param encoded - Base64 编码的加密数据
 * @returns 解密后的 UTF-8 明文字符串
 * @throws 若 Base64 格式非法、数据长度不足或 GCM Tag 校验失败，则抛出错误
 */
export function aesDecrypt(encoded: string): string {
  // 1. Base64 解码（非法字符会导致 Buffer.from 静默忽略，需要先验证）
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) {
    throw new Error('非法的 Base64 输入：包含非法字符');
  }

  const data = Buffer.from(encoded, 'base64');

  // 2. 验证最小长度：12字节IV + 至少0字节密文 + 16字节Tag = 28字节
  const IV_SIZE = 12;
  const TAG_SIZE = 16;
  if (data.length < IV_SIZE + TAG_SIZE) {
    throw new Error(`数据长度不足：需要至少 ${IV_SIZE + TAG_SIZE} 字节，实际 ${data.length} 字节`);
  }

  // 3. 拆分 IV、密文、GCM Tag
  const iv = data.subarray(0, IV_SIZE);
  const ciphertextWithTag = data.subarray(IV_SIZE);
  const tag = ciphertextWithTag.subarray(ciphertextWithTag.length - TAG_SIZE);
  const ciphertext = ciphertextWithTag.subarray(0, ciphertextWithTag.length - TAG_SIZE);

  // 4. 派生密钥
  const key = deriveAESKey();

  // 5. AES-256-GCM 解密（GCM Tag 校验失败时 Node.js 会抛出错误）
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);

  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

  return decrypted.toString('utf8');
}

/**
 * AES-256-GCM 加密（仅用于测试，与后端 AESEncrypt 对称）
 *
 * 输出格式：Base64StdEncoding( IV[12字节] || 密文[N字节] || GCM_Tag[16字节] )
 *
 * @param plaintext - 待加密的 UTF-8 明文字符串
 * @returns Base64 编码的加密数据
 */
export function aesEncrypt(plaintext: string): string {
  const key = deriveAESKey();
  const iv = randomBytes(12);

  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(Buffer.from(plaintext, 'utf8')), cipher.final()]);
  const tag = cipher.getAuthTag();

  // 拼接：IV || 密文 || Tag
  const combined = Buffer.concat([iv, encrypted, tag]);
  return combined.toString('base64');
}
