'use client';

import { useEffect, useState } from 'react';
import { copy, type Lang } from '@/lib/i18n';

export default function BackToTop({ lang }: { lang: Lang }) {
  const [visible, setVisible] = useState(false);
  const t = copy[lang].nav;

  useEffect(() => {
    const handleScroll = () => setVisible(window.scrollY > 360);
    handleScroll();
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  if (!visible) return null;

  return (
    <button
      type="button"
      aria-label={t.backToTop}
      title={t.backToTop}
      onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
      className="fixed bottom-6 right-6 z-50 flex h-12 w-12 items-center justify-center rounded-full border border-white/15 bg-black/45 text-white shadow-lg shadow-black/30 backdrop-blur-md transition hover:border-purple-400/50 hover:bg-purple-500/25"
    >
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path
          d="M12 19V5M5 12l7-7 7 7"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </button>
  );
}
