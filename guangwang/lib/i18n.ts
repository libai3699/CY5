export type Lang = 'zh-CN' | 'zh-TW' | 'en';

export function detectBrowserLang(): Lang {
  const languages = navigator.languages?.length ? navigator.languages : [navigator.language];
  const firstChinese = languages.find((lang) => lang.toLowerCase().startsWith('zh'));
  if (!firstChinese) return 'en';

  const lang = firstChinese.toLowerCase();
  if (lang.includes('tw') || lang.includes('hk') || lang.includes('mo') || lang.includes('hant')) {
    return 'zh-TW';
  }
  return 'zh-CN';
}

export function nextLang(lang: Lang): Lang {
  if (lang === 'zh-CN') return 'zh-TW';
  if (lang === 'zh-TW') return 'en';
  return 'zh-CN';
}

export const copy = {
  'zh-CN': {
    nav: {
      features: '功能特性',
      download: '立即下载',
      contact: '联系我们',
      freeDownload: '免费下载',
      openMenu: '打开菜单',
      closeMenu: '关闭菜单',
      language: '繁體',
      backToTop: '返回顶部',
    },
    hero: {
      badge: '稳定运行中 · 全球节点覆盖',
      titleA: '极速稳定，',
      titleB: '畅游全球',
      descA: '9.9 VPN 为您提供高速、安全、稳定的网络加速服务。',
      descB: '一键连接，畅享全球互联网，保护您的网络隐私。',
      primary: '立即免费下载',
      secondary: '了解更多',
      stats: [
        { value: '99.9%', label: '在线率' },
        { value: '50+', label: '全球节点' },
        { value: '10万+', label: '用户信赖' },
      ],
    },
    features: {
      badge: '核心优势',
      titleA: '为什么选择',
      subtitle: '专为国内用户设计，提供稳定、安全的网络加速体验',
      items: [
        ['高速稳定', '全球 50+ 高速节点，智能路由优化，峰值带宽无限制，视频流媒体、游戏加速更顺畅。'],
        ['隐私保护', 'AES-256 加密，隐藏 IP 地址，保护您的上网记录和网络隐私。'],
        ['简单易用', '一键连接，无需复杂配置。简洁直观的界面，新手也能快速上手。'],
        ['多设备支持', '支持 Android 手机和平板，一个账号可在多设备上使用。'],
      ],
    },
    download: {
      badge: '立即下载',
      titleA: '选择适合您的',
      titleB: '版本',
      subtitle: '支持 Android 设备，一键安装，立即体验极速网络',
      error: '暂时无法获取下载链接，请稍后重试',
      vpnName: '9.9 VPN',
      accName: '9.9 加速器',
      note: '两款应用功能一致，您可自主选择其中一个下载安装',
      unavailable: '暂未开放',
      downloadNow: '立即下载',
      unavailableLabel: '暂未开放下载',
      downloadLabel: '下载',
    },
    contact: {
      badge: '联系我们',
      titleA: '有问题？',
      titleB: '随时联系',
      subtitle: '我们的客服团队随时为您提供帮助和支持',
      wechat: '微信',
      telegram: 'Telegram',
      qq: 'QQ',
      email: '邮箱',
    },
    footer: {
      rights: 'All rights reserved.',
    },
  },
  'zh-TW': {
    nav: {
      features: '功能特色',
      download: '立即下載',
      contact: '聯絡我們',
      freeDownload: '免費下載',
      openMenu: '開啟選單',
      closeMenu: '關閉選單',
      language: 'EN',
      backToTop: '返回頂部',
    },
    hero: {
      badge: '穩定運行中 · 全球節點覆蓋',
      titleA: '極速穩定，',
      titleB: '暢遊全球',
      descA: '9.9 VPN 為您提供高速、安全、穩定的網路加速服務。',
      descB: '一鍵連線，暢享全球網際網路，保護您的網路隱私。',
      primary: '立即免費下載',
      secondary: '了解更多',
      stats: [
        { value: '99.9%', label: '在線率' },
        { value: '50+', label: '全球節點' },
        { value: '10萬+', label: '用戶信賴' },
      ],
    },
    features: {
      badge: '核心優勢',
      titleA: '為什麼選擇',
      subtitle: '專為中文用戶設計，提供穩定、安全的網路加速體驗',
      items: [
        ['高速穩定', '全球 50+ 高速節點，智慧路由最佳化，峰值頻寬無限制，影音串流、遊戲加速更順暢。'],
        ['隱私保護', 'AES-256 加密，隱藏 IP 位址，保護您的上網記錄和網路隱私。'],
        ['簡單易用', '一鍵連線，無需複雜設定。簡潔直覺的介面，新手也能快速上手。'],
        ['多裝置支援', '支援 Android 手機和平板，一個帳號可在多裝置上使用。'],
      ],
    },
    download: {
      badge: '立即下載',
      titleA: '選擇適合您的',
      titleB: '版本',
      subtitle: '支援 Android 裝置，一鍵安裝，立即體驗極速網路',
      error: '暫時無法取得下載連結，請稍後再試',
      vpnName: '9.9 VPN',
      accName: '9.9 加速器',
      note: '兩款應用功能一致，您可自行選擇其中一個下載安裝',
      unavailable: '暫未開放',
      downloadNow: '立即下載',
      unavailableLabel: '暫未開放下載',
      downloadLabel: '下載',
    },
    contact: {
      badge: '聯絡我們',
      titleA: '有問題？',
      titleB: '隨時聯絡',
      subtitle: '我們的客服團隊隨時為您提供協助與支援',
      wechat: '微信',
      telegram: 'Telegram',
      qq: 'QQ',
      email: '信箱',
    },
    footer: {
      rights: 'All rights reserved.',
    },
  },
  en: {
    nav: {
      features: 'Features',
      download: 'Download',
      contact: 'Contact',
      freeDownload: 'Free Download',
      openMenu: 'Open menu',
      closeMenu: 'Close menu',
      language: '简体',
      backToTop: 'Back to top',
    },
    hero: {
      badge: 'Stable service · Global node coverage',
      titleA: 'Fast and stable,',
      titleB: 'connect globally',
      descA: '9.9 VPN provides fast, secure, and stable network acceleration.',
      descB: 'Connect with one tap, access the global internet, and protect your privacy.',
      primary: 'Download for Free',
      secondary: 'Learn More',
      stats: [
        { value: '99.9%', label: 'Uptime' },
        { value: '50+', label: 'Global nodes' },
        { value: '100K+', label: 'Trusted users' },
      ],
    },
    features: {
      badge: 'Core Advantages',
      titleA: 'Why choose',
      subtitle: 'Designed for reliable, secure, and simple network acceleration.',
      items: [
        ['Fast and stable', '50+ high-speed global nodes, smart routing, and unlimited peak bandwidth for streaming and games.'],
        ['Privacy protection', 'AES-256 encryption, hidden IP address, and privacy protection for your browsing activity.'],
        ['Easy to use', 'Connect with one tap and no complex setup. The interface is simple enough for first-time users.'],
        ['Multi-device support', 'Supports Android phones and tablets, with access across multiple devices.'],
      ],
    },
    download: {
      badge: 'Download',
      titleA: 'Choose the right',
      titleB: 'version',
      subtitle: 'Android APK downloads with quick installation and fast access.',
      error: 'Download links are temporarily unavailable. Please try again later.',
      vpnName: '9.9 VPN',
      accName: '9.9 Accelerator',
      note: 'Both apps provide the same features. Choose either one to download and install.',
      unavailable: 'Unavailable',
      downloadNow: 'Download Now',
      unavailableLabel: 'Download unavailable',
      downloadLabel: 'Download',
    },
    contact: {
      badge: 'Contact Us',
      titleA: 'Need help?',
      titleB: 'Contact us anytime',
      subtitle: 'Our support team is ready to help.',
      wechat: 'WeChat',
      telegram: 'Telegram',
      qq: 'QQ',
      email: 'Email',
    },
    footer: {
      rights: 'All rights reserved.',
    },
  },
} as const;
