'use client';

import Image from 'next/image';
import { copy, type Lang } from '@/lib/i18n';

export default function Footer({ lang }: { lang: Lang }) {
  const currentYear = new Date().getFullYear();
  const t = copy[lang];

  return (
    <footer className="relative border-t border-white/5 py-10">
      <div
        className="pointer-events-none absolute left-1/2 top-0 h-px w-48 -translate-x-1/2"
        style={{ background: 'linear-gradient(to right, transparent, rgba(124,58,237,0.5), transparent)' }}
        aria-hidden="true"
      />

      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center justify-between gap-6 sm:flex-row">
          <div className="flex items-center gap-3">
            <div className="h-8 w-8 overflow-hidden rounded-md">
              <Image src="/logo.png" alt="9.9 VPN Logo" width={32} height={32} className="h-full w-full object-cover" />
            </div>
            <span className="text-sm font-bold text-white">
              9.9 <span className="text-gradient">VPN</span>
            </span>
          </div>

          <p className="text-center text-sm text-slate-500">
            © {currentYear} 9.9 VPN. {t.footer.rights}
          </p>

          <div className="flex items-center gap-6">
            {[
              ['#features', t.nav.features],
              ['#download', t.nav.download],
              ['#contact', t.nav.contact],
            ].map(([href, label]) => (
              <a
                key={href}
                href={href}
                onClick={(e) => {
                  e.preventDefault();
                  document.querySelector(href)?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="text-sm text-slate-500 transition-colors hover:text-slate-300"
              >
                {label}
              </a>
            ))}
          </div>
        </div>
      </div>
    </footer>
  );
}
