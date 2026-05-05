# 9.9 VPN 官网

「9.9 VPN」产品官网落地页，基于 Next.js 14 (App Router) + Tailwind CSS + TypeScript 构建。

## 功能特性

- 深色主题，深蓝/深紫渐变视觉风格
- 毛玻璃效果导航栏、特性卡片
- 双 APK 下载入口（9.9 VPN + 9.9 加速器）
- 联系方式展示（微信、Telegram、QQ、邮箱）
- 下载链接和联系方式从后台配置接口动态获取
- AES-256-GCM 加解密（服务端 Route Handler，密钥不暴露到客户端）
- 移动端优先响应式布局（320px ~ 1920px）
- CSS 入场动画，支持 `prefers-reduced-motion` 无障碍

## 环境变量配置

复制 `.env.example` 为 `.env.local`，填入实际值：

```bash
cp .env.example .env.local
```

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `APP_SECRET` | 与后端相同的密钥，用于 HKDF 派生 AES 密钥。**服务端专用，不带 `NEXT_PUBLIC_` 前缀** | `your_secret_here` |
| `API_BASE_URL` | 后端 API 基础 URL | `http://127.0.0.1:8989` |

> ⚠️ `.env.local` 已在 `.gitignore` 中忽略，不会提交到 git。

## 本地开发

```bash
# 安装依赖
npm install

# 启动开发服务器（默认 http://localhost:3000）
npm run dev
```

## 生产构建

```bash
# 构建生产版本
npm run build

# 启动生产服务器
npm start
```

## 运行测试

```bash
# 运行所有测试（属性测试 + 单元测试）
npm test

# 监听模式
npm test -- --watch
```

## 项目结构

```
guangwang/
├── app/
│   ├── layout.tsx              # 根布局（HTML head、全局样式）
│   ├── page.tsx                # 首页（组合所有 Section）
│   ├── globals.css             # 全局 CSS（Tailwind + 自定义变量 + 动画）
│   └── api/
│       └── site-config/
│           └── route.ts        # Route Handler：调用后端并解密，返回明文 JSON
├── components/
│   ├── Navbar.tsx              # 顶部导航栏（毛玻璃、sticky、移动端汉堡菜单）
│   ├── Hero.tsx                # Hero 区块（主标语、CTA 按钮、入场动画）
│   ├── Features.tsx            # 功能特性区块（4 个特性卡片）
│   ├── DownloadSection.tsx     # 下载区块（客户端 fetch，双卡片）
│   ├── DownloadCard.tsx        # 单个下载卡片组件
│   ├── ContactSection.tsx      # 联系方式区块（客户端 fetch，动态展示）
│   └── Footer.tsx              # 页脚（版权信息）
├── lib/
│   └── crypto.ts               # 服务端加解密工具（仅在 Route Handler 中使用）
├── types/
│   └── index.ts                # 共享 TypeScript 类型定义
├── __tests__/
│   ├── crypto.test.ts          # 加解密属性测试（属性 1、5、6）
│   ├── route.test.ts           # Route Handler 属性测试（属性 2）
│   ├── DownloadSection.test.tsx # DownloadSection 属性测试（属性 3）
│   └── DownloadCard.test.tsx   # DownloadCard 属性测试（属性 4）
├── .env.example                # 环境变量示例
├── next.config.ts              # Next.js 配置
├── tailwind.config.ts          # Tailwind 配置
├── jest.config.ts              # Jest 配置
└── tsconfig.json               # TypeScript 配置
```

## 加解密方案

与后端 Go `CryptoMiddleware` 完全对称：

- **密钥派生**：`HKDF(SHA-256, APP_SECRET, salt="cy5vpn-aes-key-v1", info="aes-256-gcm", length=32)`
- **加密格式**：`Base64StdEncoding(IV[12字节] || 密文[N字节] || GCM_Tag[16字节])`
- **解密位置**：Next.js Route Handler（服务端），`APP_SECRET` 不暴露到客户端 bundle

## 部署说明

### Vercel / Node.js 服务器

```bash
npm run build
npm start
```

### Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

构建时需要传入环境变量：

```bash
docker build \
  --build-arg APP_SECRET=your_secret \
  --build-arg API_BASE_URL=https://api.example.com \
  -t guangwang .
```
