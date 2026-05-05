'use client';

import { useEffect, useState, type ReactNode } from 'react';
import type { DownloadConfig } from '@/types';
import { copy, type Lang } from '@/lib/i18n';
import { decryptSiteConfig } from '@/lib/clientCrypto';

interface ContactItem {
  key: keyof Pick<DownloadConfig, 'contact_wechat' | 'contact_telegram' | 'contact_qq' | 'contact_email'>;
  labelKey: 'wechat' | 'telegram' | 'qq' | 'email';
  icon: ReactNode;
  href: (value: string) => string;
}

const contactItems: ContactItem[] = [
  {
    key: 'contact_wechat',
    labelKey: 'wechat',
    icon: <span className="text-sm font-bold">WX</span>,
    href: () => '#',
  },
  {
    key: 'contact_telegram',
    labelKey: 'telegram',
    icon: <span className="text-sm font-bold">TG</span>,
    href: (v) => (v.startsWith('http') ? v : `https://t.me/${v.replace('@', '')}`),
  },
  {
    key: 'contact_qq',
    labelKey: 'qq',
    icon: <span className="text-sm font-bold">QQ</span>,
    href: (v) => `tencent://message/?uin=${v}`,
  },
  {
    key: 'contact_email',
    labelKey: 'email',
    icon: <span className="text-sm font-bold">@</span>,
    href: (v) => `mailto:${v}`,
  },
];

export default function ContactSection({ lang }: { lang: Lang }) {
  const [config, setConfig] = useState<DownloadConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [copiedKey, setCopiedKey] = useState<string>('');
  const t = copy[lang].contact;

  useEffect(() => {
    let cancelled = false;

    async function fetchConfig() {
      try {
        const res = await fetch('/api/site-config');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.error) throw new Error(data.error);
        const decrypted = await decryptSiteConfig(data.encrypted);
        if (!cancelled) setConfig(decrypted);
      } catch {
        // 联系方式失败时不显示该区块。
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetchConfig();
    return () => {
      cancelled = true;
    };
  }, []);

  const visibleItems = contactItems.filter((item) => config && config[item.key]?.trim() !== '');

  async function copyValue(key: string, value: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedKey(key);
      window.setTimeout(() => setCopiedKey(''), 1200);
    } catch {
      setCopiedKey('');
    }
  }

  if (loading || visibleItems.length === 0) return null;

  return (
    <section id="contact" className="relative overflow-hidden py-20 sm:py-28">
      <div
        className="pointer-events-none absolute inset-0"
        style={{ background: 'radial-gradient(ellipse 60% 40% at 50% 50%, rgba(37,99,235,0.06) 0%, transparent 70%)' }}
        aria-hidden="true"
      />

      <div className="relative z-10 mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="animate-fade-in-up mb-12 text-center">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-blue-500/30 bg-blue-500/10 px-4 py-2 text-sm font-medium text-blue-300">
            {t.badge}
          </div>
          <h2 className="mb-4 text-3xl font-extrabold text-white sm:text-4xl">
            {t.titleA}
            <span className="text-gradient"> {t.titleB}</span>
          </h2>
          <p className="mx-auto max-w-xl text-lg text-slate-400">{t.subtitle}</p>
        </div>

        <div
          className={`animate-fade-in-up-delay-1 grid gap-4 ${
            visibleItems.length === 1
              ? 'mx-auto max-w-xs grid-cols-1'
              : visibleItems.length === 2
                ? 'mx-auto max-w-lg grid-cols-1 sm:grid-cols-2'
                : visibleItems.length === 3
                  ? 'grid-cols-1 sm:grid-cols-3'
                  : 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-4'
          }`}
        >
          {visibleItems.map((item) => {
            const value = config![item.key];
            const href = item.href(value);
            const isClickable = href !== '#';
            const label = t[item.labelKey];

            return (
              <div key={item.key} className="glass-card p-6 text-center transition-all duration-300 hover:-translate-y-1 hover:border-blue-500/30">
                <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl border border-white/10 bg-gradient-to-br from-blue-500/20 to-purple-500/20 text-blue-300">
                  {item.icon}
                </div>
                <div className="mb-2 text-xs font-medium uppercase tracking-wider text-slate-400">{label}</div>
                <div className="flex items-center justify-center gap-2">
                  {isClickable ? (
                    <a
                      href={href}
                      target={href.startsWith('http') ? '_blank' : undefined}
                      rel={href.startsWith('http') ? 'noopener noreferrer' : undefined}
                      className="min-w-0 break-all text-sm font-semibold text-white transition-colors hover:text-purple-300"
                    >
                      {value}
                    </a>
                  ) : (
                    <span className="min-w-0 break-all text-sm font-semibold text-white">{value}</span>
                  )}
                  <button
                    type="button"
                    onClick={() => copyValue(item.key, value)}
                    className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-md border border-white/10 text-slate-400 transition hover:border-blue-400/50 hover:text-blue-300"
                    aria-label={`${copiedKey === item.key ? '已复制' : '复制'} ${label}`}
                    title={copiedKey === item.key ? '已复制' : '复制'}
                  >
                    {copiedKey === item.key ? (
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                        <path d="M20 6L9 17l-5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    ) : (
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                        <rect x="9" y="9" width="11" height="11" rx="2" stroke="currentColor" strokeWidth="2" />
                        <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                      </svg>
                    )}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
