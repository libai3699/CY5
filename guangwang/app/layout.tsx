import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: '9.9 VPN - 极速稳定，畅游全球',
  description: '9.9 VPN 官网，提供高速稳定的 VPN 服务，支持 Android 设备，保护您的网络隐私。',
  keywords: ['VPN', '9.9 VPN', '加速器', '网络加速'],
  icons: {
    icon: '/favicon.ico',
    apple: '/logo.png',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body suppressHydrationWarning>
        <main className="min-h-screen overflow-x-hidden">
          {children}
        </main>
      </body>
    </html>
  );
}
