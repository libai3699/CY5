'use client';

import { copy, type Lang } from '@/lib/i18n';

export default function Hero({ lang }: { lang: Lang }) {
  const t = copy[lang].hero;

  return (
    <section className="relative flex min-h-screen items-center justify-center overflow-hidden pt-16">
      <div
        className="absolute inset-0"
        style={{
          background:
            'linear-gradient(135deg, #0a0a0f 0%, #1a0a2e 30%, #0f1a3e 60%, #0a0a0f 100%)',
        }}
        aria-hidden="true"
      />
      <div
        className="pointer-events-none absolute left-1/4 top-1/4 h-96 w-96 rounded-full opacity-20 blur-3xl"
        style={{ background: 'radial-gradient(circle, #7c3aed 0%, transparent 70%)' }}
        aria-hidden="true"
      />
      <div
        className="pointer-events-none absolute bottom-1/4 right-1/4 h-80 w-80 rounded-full opacity-15 blur-3xl"
        style={{ background: 'radial-gradient(circle, #2563eb 0%, transparent 70%)' }}
        aria-hidden="true"
      />
      <div
        className="pointer-events-none absolute inset-0 opacity-5"
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)',
          backgroundSize: '60px 60px',
        }}
        aria-hidden="true"
      />

      <div className="relative z-10 mx-auto max-w-4xl px-4 text-center sm:px-6 lg:px-8">
        <div className="animate-fade-in mb-8 inline-flex items-center gap-2 rounded-full border border-purple-500/30 bg-purple-500/10 px-4 py-2 text-sm font-medium text-purple-300">
          <span className="inline-block h-2 w-2 rounded-full bg-green-400" style={{ boxShadow: '0 0 6px #4ade80' }} />
          {t.badge}
        </div>

        <h1 className="animate-fade-in-up mb-6 text-4xl font-extrabold leading-tight text-white sm:text-5xl md:text-6xl lg:text-7xl">
          {t.titleA}
          <br />
          <span className="text-gradient">{t.titleB}</span>
        </h1>

        <p className="animate-fade-in-up-delay-1 mx-auto mb-10 max-w-2xl text-lg leading-relaxed text-slate-400 sm:text-xl">
          {t.descA}
          <br className="hidden sm:block" />
          {t.descB}
        </p>

        <div className="animate-fade-in-up-delay-2 flex flex-col items-center justify-center gap-4 sm:flex-row">
          <a
            href="#download"
            onClick={(e) => {
              e.preventDefault();
              document.querySelector('#download')?.scrollIntoView({ behavior: 'smooth' });
            }}
            className="btn-gradient flex min-h-[52px] w-full items-center justify-center gap-2 rounded-full px-8 py-4 text-base font-bold text-white shadow-lg shadow-purple-500/30 sm:w-auto"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M12 16l-6-6h4V4h4v6h4l-6 6z" fill="currentColor" />
              <path d="M20 18H4v2h16v-2z" fill="currentColor" />
            </svg>
            {t.primary}
          </a>
          <a
            href="#features"
            onClick={(e) => {
              e.preventDefault();
              document.querySelector('#features')?.scrollIntoView({ behavior: 'smooth' });
            }}
            className="flex min-h-[52px] w-full items-center justify-center gap-2 rounded-full border border-white/20 px-8 py-4 text-base font-semibold text-slate-300 transition-all duration-200 hover:border-white/40 hover:text-white sm:w-auto"
          >
            {t.secondary}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M9 18l6-6-6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </a>
        </div>

        <div className="animate-fade-in-up-delay-3 mx-auto mt-16 grid max-w-lg grid-cols-3 gap-6">
          {t.stats.map((stat) => (
            <div key={stat.label} className="text-center">
              <div className="text-gradient text-2xl font-extrabold sm:text-3xl">{stat.value}</div>
              <div className="mt-1 text-xs text-slate-500 sm:text-sm">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>

      <div
        className="pointer-events-none absolute bottom-0 left-0 right-0 h-32"
        style={{ background: 'linear-gradient(to bottom, transparent, #0a0a0f)' }}
        aria-hidden="true"
      />
    </section>
  );
}
