/** @type {import('next').NextConfig} */
const nextConfig = {
  // APP_SECRET 不带 NEXT_PUBLIC_ 前缀，Next.js 默认不暴露到客户端 bundle
  // API_BASE_URL 仅由服务端 Route Handler 读取
  
  // 禁用静态文件缓存，强制每次加载最新文件
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0',
          },
        ],
      },
    ];
  },
  
  // 生成唯一的构建 ID，确保每次构建文件名都不同
  generateBuildId: async () => {
    return `build-${Date.now()}`;
  },
};

export default nextConfig;
