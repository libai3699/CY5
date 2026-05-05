/** @type {import('next').NextConfig} */
const nextConfig = {
  // APP_SECRET 不带 NEXT_PUBLIC_ 前缀，Next.js 默认不暴露到客户端 bundle
  // API_BASE_URL 仅由服务端 Route Handler 读取
};

export default nextConfig;
