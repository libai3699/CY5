import type { Lang } from './types';

export const copy = {
  zh: {
    nav: { features: '核心优势', download: '立即下载', contact: '联系方式', lang: 'EN' },
    hero: {
      badge: '安全高速',
      titleA: '9.9 VPN',
      titleB: '极速稳定，畅游全球',
      subtitle: '专为移动网络场景优化，低延迟连接、稳定下载、隐私加密，让每一次访问都更顺畅。',
      primary: '立即下载',
      secondary: '查看联系',
      statA: '高速节点',
      statB: '隐私加密',
      statC: '稳定连接',
    },
    features: {
      badge: '为什么选择我们',
      titleA: '更快、更稳、',
      titleB: '更省心',
      items: [
        ['极速连接', '智能线路调度，减少等待时间，打开应用即刻连接。'],
        ['稳定体验', '弱网环境下持续优化，降低掉线和卡顿概率。'],
        ['安全加密', '下载配置加密传输，敏感信息不直接暴露在页面源码。'],
        ['轻量易用', '界面简洁，安装包清晰，适合 Android 用户快速上手。'],
      ],
    },
    download: {
      badge: '官方下载',
      titleA: '下载',
      titleB: '最新版',
      subtitle: '自动读取后台发布的最新版本和下载地址。',
      vpnName: '9.9 VPN',
      accName: '9.9 加速器',
      downloadNow: '立即下载',
      unavailable: '暂未开放',
      note: '下载链接由后台实时返回，请以页面显示版本为准。',
      error: '下载配置加载失败',
    },
    contact: {
      badge: '联系我们',
      titleA: '需要帮助？',
      titleB: '联系支持',
      subtitle: '后台配置的联系方式会自动展示。',
      wechat: '微信',
      telegram: 'Telegram',
      qq: 'QQ',
      email: '邮箱',
      copied: '已复制',
      copy: '复制',
    },
    footer: '© 2026 9.9 VPN. All rights reserved.',
  },
  en: {
    nav: { features: 'Features', download: 'Download', contact: 'Contact', lang: '中文' },
    hero: {
      badge: 'Secure · Fast · Android Ready',
      titleA: '9.9 VPN',
      titleB: 'Fast, stable global access',
      subtitle: 'Optimized for mobile networks with low latency, stable downloads, and encrypted configuration delivery.',
      primary: 'Download',
      secondary: 'Contact',
      statA: 'Fast Nodes',
      statB: 'Encrypted',
      statC: 'Stable',
    },
    features: {
      badge: 'Why choose us',
      titleA: 'Fast, stable,',
      titleB: 'easy to trust',
      items: [
        ['Fast connection', 'Smart routing reduces waiting and connects quickly.'],
        ['Stable experience', 'Optimized for weak networks to reduce drops and stalls.'],
        ['Encrypted config', 'Download configuration is encrypted before reaching the page.'],
        ['Easy install', 'Clear APK cards make Android downloads simple.'],
      ],
    },
    download: {
      badge: 'Official download',
      titleA: 'Get the',
      titleB: 'latest build',
      subtitle: 'Version and download URLs are read from the backend in real time.',
      vpnName: '9.9 VPN',
      accName: '9.9 Accelerator',
      downloadNow: 'Download now',
      unavailable: 'Unavailable',
      note: 'Download links are controlled by the backend configuration.',
      error: 'Failed to load download config',
    },
    contact: {
      badge: 'Contact us',
      titleA: 'Need help?',
      titleB: 'Reach support',
      subtitle: 'Configured contact channels are displayed automatically.',
      wechat: 'WeChat',
      telegram: 'Telegram',
      qq: 'QQ',
      email: 'Email',
      copied: 'Copied',
      copy: 'Copy',
    },
    footer: '© 2026 9.9 VPN. All rights reserved.',
  },
} as const;

export function detectBrowserLang(): Lang {
  if (typeof navigator === 'undefined') return 'zh';
  return navigator.language.toLowerCase().startsWith('zh') ? 'zh' : 'en';
}
