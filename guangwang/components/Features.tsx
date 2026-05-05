import { copy, type Lang } from '@/lib/i18n';

const iconPaths = [
  'M13 2L3 14h9l-1 8 10-12h-9l1-8z',
  'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
  'M8 12l3 3 5-5',
  'M5 5h14v14H5z',
];

function FeatureIcon({ index }: { index: number }) {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d={iconPaths[index]}
        stroke="url(#feature-grad)"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <defs>
        <linearGradient id="feature-grad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#a78bfa" />
          <stop offset="100%" stopColor="#60a5fa" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export default function Features({ lang }: { lang: Lang }) {
  const t = copy[lang].features;

  return (
    <section id="features" className="relative overflow-hidden py-20 sm:py-28">
      <div
        className="pointer-events-none absolute left-1/2 top-0 h-20 w-px -translate-x-1/2"
        style={{ background: 'linear-gradient(to bottom, transparent, rgba(124,58,237,0.5), transparent)' }}
        aria-hidden="true"
      />

      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="animate-fade-in-up mb-16 text-center">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-purple-500/30 bg-purple-500/10 px-4 py-2 text-sm font-medium text-purple-300">
            {t.badge}
          </div>
          <h2 className="mb-4 text-3xl font-extrabold text-white sm:text-4xl md:text-5xl">
            {t.titleA}
            <span className="text-gradient"> 9.9 VPN</span>
          </h2>
          <p className="mx-auto max-w-2xl text-lg text-slate-400">{t.subtitle}</p>
        </div>

        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {t.items.map((feature, index) => (
            <div
              key={feature[0]}
              className={`glass-card group p-6 transition-all duration-300 hover:-translate-y-1 hover:border-purple-500/30 animate-fade-in-up-delay-${index + 1}`}
            >
              <div className="mb-5 flex h-14 w-14 items-center justify-center rounded-2xl border border-white/10 bg-gradient-to-br from-purple-500/20 to-blue-500/20 transition-all duration-300 group-hover:from-purple-500/30 group-hover:to-blue-500/30">
                <FeatureIcon index={index} />
              </div>
              <h3 className="mb-3 text-lg font-bold text-white">{feature[0]}</h3>
              <p className="text-sm leading-relaxed text-slate-400">{feature[1]}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
