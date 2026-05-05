'use client';

import { useEffect, useState } from 'react';
import DownloadCard from './DownloadCard';
import type { DownloadConfig } from '@/types';
import { copy, type Lang } from '@/lib/i18n';
import { decryptSiteConfig } from '@/lib/clientCrypto';

function SkeletonCard() {
  return (
    <div className="glass-card flex flex-col items-center p-8">
      <div className="skeleton mb-5 h-20 w-20 rounded-3xl" />
      <div className="skeleton mb-2 h-6 w-32 rounded" />
      <div className="skeleton mb-6 h-5 w-20 rounded-full" />
      <div className="skeleton mb-6 h-5 w-24 rounded-full" />
      <div className="skeleton h-12 w-full rounded-full" />
    </div>
  );
}

export default function DownloadSection({ lang }: { lang: Lang }) {
  const [config, setConfig] = useState<DownloadConfig | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const t = copy[lang].download;

  useEffect(() => {
    let cancelled = false;

    async function fetchConfig() {
      try {
        const res = await fetch('/api/site-config');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.error) throw new Error(data.error);
        // 使用解密
        const decrypted = await decryptSiteConfig(data.encrypted);
        if (!cancelled) setConfig(decrypted);
      } catch (err) {
        if (!cancelled) {
          console.error('[DownloadSection] 获取配置失败:', err);
          setError(t.error);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetchConfig();
    return () => {
      cancelled = true;
    };
  }, [t.error]);

  return (
    <section id="download" className="relative overflow-hidden py-20 sm:py-28">
      <div
        className="pointer-events-none absolute inset-0"
        style={{ background: 'radial-gradient(ellipse 80% 50% at 50% 50%, rgba(124,58,237,0.08) 0%, transparent 70%)' }}
        aria-hidden="true"
      />

      <div className="relative z-10 mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
        <div className="animate-fade-in-up mb-12 text-center">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-purple-500/30 bg-purple-500/10 px-4 py-2 text-sm font-medium text-purple-300">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 16l-6-6h4V4h4v6h4l-6 6z" />
              <path d="M20 18H4v2h16v-2z" />
            </svg>
            {t.badge}
          </div>
          <h2 className="mb-4 text-3xl font-extrabold text-white sm:text-4xl md:text-5xl">
            {t.titleA}
            <span className="text-gradient"> {t.titleB}</span>
          </h2>
          <p className="mx-auto max-w-2xl text-lg text-slate-400">{t.subtitle}</p>
        </div>

        {error && !loading && (
          <div className="glass-card mb-8 border-red-500/20 p-6 text-center">
            <div className="flex items-center justify-center gap-3 text-red-400">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" />
                <path d="M12 8v4M12 16h.01" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
              <span className="font-medium">{error}</span>
            </div>
          </div>
        )}

        <div className="animate-fade-in-up-delay-1 grid grid-cols-1 gap-6 md:grid-cols-2">
          {loading ? (
            <>
              <SkeletonCard />
              <SkeletonCard />
            </>
          ) : (
            <>
              <DownloadCard
                appName={t.vpnName}
                version={config?.vpn_version ?? ''}
                downloadUrl={config?.vpn_apk ?? ''}
                disabled={!config?.vpn_apk || !!error}
                testId="vpn-download-btn"
                unavailableText={t.unavailable}
                downloadText={t.downloadNow}
                unavailableLabel={t.unavailableLabel}
                downloadLabel={t.downloadLabel}
              />
              <DownloadCard
                appName={t.accName}
                version={config?.acc_version ?? ''}
                downloadUrl={config?.acc_apk ?? ''}
                disabled={!config?.acc_apk || !!error}
                testId="acc-download-btn"
                unavailableText={t.unavailable}
                downloadText={t.downloadNow}
                unavailableLabel={t.unavailableLabel}
                downloadLabel={t.downloadLabel}
              />
            </>
          )}
        </div>

        {!loading && (
          <div className="animate-fade-in-up-delay-2 mt-8">
            <div className="glass-card p-5 text-center">
              <div className="flex items-start justify-center gap-3 text-sm text-slate-400 sm:items-center">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" className="mt-0.5 flex-shrink-0 text-purple-400 sm:mt-0" aria-hidden="true">
                  <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" />
                  <path d="M12 16v-4M12 8h.01" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                </svg>
                <span>{t.note}</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
