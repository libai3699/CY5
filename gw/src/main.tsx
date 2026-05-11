import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { siteConfigEndpoint } from './config';
import { decryptSiteConfig, normalizeSiteConfig } from './crypto';
import { copy, detectBrowserLang } from './i18n';
import type { DownloadConfig, Lang } from './types';
import './styles.css';

function Logo({ size = 42 }: { size?: number }) {
  return (
    <img className="logo-img" src={`${import.meta.env.BASE_URL}logo.png`} width={size} height={size} alt="9.9 VPN Logo" />
  );
}

function scrollToSection(event: React.MouseEvent<HTMLAnchorElement>, hash: string, after?: () => void) {
  event.preventDefault();
  document.querySelector(hash)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  after?.();
}

function Navbar({ lang, setLang }: { lang: Lang; setLang: (lang: Lang) => void }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const t = copy[lang].nav;
  const links = [
    { href: '#features', label: t.features },
    { href: '#guide', label: t.guide },
    { href: '#download', label: t.download },
    { href: '#contact', label: t.contact },
  ];

  const closeMenu = () => setMenuOpen(false);

  return (
    <header className="nav">
      <a className="brand" href="#top" aria-label="9.9 VPN" onClick={(event) => scrollToSection(event, '#top')}>
        <Logo />
        <span>9.9 VPN</span>
      </a>
      <nav>
        {links.map((link) => (
          <a key={link.href} href={link.href} onClick={(event) => scrollToSection(event, link.href, closeMenu)}>{link.label}</a>
        ))}
        <button type="button" className="ghost-btn" onClick={() => setLang(lang === 'zh' ? 'en' : 'zh')}>
          {t.lang}
        </button>
      </nav>
      <button
        type="button"
        className="menu-btn"
        onClick={() => setMenuOpen((open) => !open)}
        aria-label={menuOpen ? t.closeMenu : t.openMenu}
        aria-expanded={menuOpen}
      >
        <span />
        <span />
        <span />
      </button>
      {menuOpen && (
        <div className="mobile-menu">
          {links.map((link) => (
            <a key={link.href} href={link.href} onClick={(event) => scrollToSection(event, link.href, closeMenu)}>{link.label}</a>
          ))}
          <button
            type="button"
            onClick={() => {
              setLang(lang === 'zh' ? 'en' : 'zh');
              closeMenu();
            }}
          >
            {t.lang}
          </button>
        </div>
      )}
    </header>
  );
}

function Hero({ lang }: { lang: Lang }) {
  const t = copy[lang].hero;
  return (
    <section id="top" className="hero">
      <div className="aurora aurora-a" />
      <div className="aurora aurora-b" />
      <div className="hero-grid" />
      <div className="hero-content reveal">
        <div className="pill">{t.badge}</div>
        <h1>
          <span>{t.titleA}</span>
          <strong>{t.titleB}</strong>
        </h1>
        <p>{t.subtitle}</p>
        <div className="trial-highlight">
          <strong>{t.trialHighlight}</strong>
          <span>{t.trialText}</span>
        </div>
        <div className="hero-actions">
          <a className="primary-btn hero-btn" href="#download" onClick={(event) => scrollToSection(event, '#download')}>{t.primary}</a>
          <a className="secondary-btn hero-btn" href="#contact" onClick={(event) => scrollToSection(event, '#contact')}>{t.secondary}</a>
        </div>
        <div className="stats">
          {[t.statA, t.statB, t.statC].map((item, index) => (
            <div className="stat" key={item} style={{ animationDelay: `${index * 120}ms` }}>
              <span>{index === 0 ? '120+' : index === 1 ? 'AES' : '24/7'}</span>
              <small>{item}</small>
            </div>
          ))}
        </div>
      </div>
      <div className="phone-stage reveal delay-1" aria-hidden="true">
        <div className="orbit orbit-a" />
        <div className="orbit orbit-b" />
        <div className="phone">
          <div className="phone-top" />
          <Logo size={88} />
          <div className="signal-bars">
            <span />
            <span />
            <span />
            <span />
          </div>
          <div className="phone-line wide" />
          <div className="phone-line" />
          <div className="phone-button">CONNECTED</div>
        </div>
      </div>
    </section>
  );
}

function Features({ lang }: { lang: Lang }) {
  const t = copy[lang].features;
  return (
    <section id="features" className="section">
      <div className="section-inner">
        <div className="section-heading reveal">
          <div className="pill">{t.badge}</div>
          <h2>{t.titleA}<span>{t.titleB}</span></h2>
        </div>
        <div className="feature-grid">
          {t.items.map(([title, text], index) => (
            <article className="feature-card reveal" style={{ animationDelay: `${index * 90}ms` }} key={title}>
              <div className="feature-icon">{index + 1}</div>
              <h3>{title}</h3>
              <p>{text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function GuideSection({ lang }: { lang: Lang }) {
  const t = copy[lang].guide;
  return (
    <section id="guide" className="section guide-section">
      <div className="section-inner">
        <div className="section-heading reveal">
          <div className="pill blue">{t.badge}</div>
          <h2>{t.titleA}<span>{t.titleB}</span></h2>
          <p>{t.subtitle}</p>
        </div>
        <div className="guide-grid">
          {t.steps.map(([title, text], index) => (
            <article className="guide-card reveal" style={{ animationDelay: `${index * 90}ms` }} key={title}>
              <div className="guide-index">{index + 1}</div>
              <h3>{title}</h3>
              <p>{text}</p>
            </article>
          ))}
        </div>
        <div className="guide-tip reveal">
          <strong>{t.tipTitle}</strong>
          <span>{t.tipText}</span>
        </div>
      </div>
    </section>
  );
}

function DownloadCard({ name, version, url, text, unavailable }: { name: string; version: string; url: string; text: string; unavailable: string }) {
  const disabled = !url;
  return (
    <article className="download-card reveal">
      <Logo size={80} />
      <h3>{name}</h3>
      {version ? <span className="version">v{version}</span> : <span className="version muted">No version</span>}
      <span className="apk-pill">Android APK</span>
      {disabled ? (
        <button className="primary-btn disabled" type="button" disabled>{unavailable}</button>
      ) : (
        <a className="primary-btn" href={url} download>{text}</a>
      )}
    </article>
  );
}

function DownloadSection({ lang, config, error, loading }: { lang: Lang; config: DownloadConfig | null; error: string; loading: boolean }) {
  const t = copy[lang].download;
  return (
    <section id="download" className="section download-section">
      <div className="section-inner narrow">
        <div className="section-heading reveal">
          <div className="pill">{t.badge}</div>
          <h2>{t.titleA}<span>{t.titleB}</span></h2>
          <p>{t.subtitle}</p>
        </div>
        {error && <div className="error-box">{t.error}</div>}
        <div className="download-alert reveal">
          <strong>{t.mainlandNoticeTitle}</strong>
          <span>{t.mainlandNoticeText}</span>
        </div>
        <div className="download-grid">
          {loading ? (
            <>
              <div className="skeleton-card" />
              <div className="skeleton-card" />
            </>
          ) : (
            <>
              <DownloadCard name={t.vpnName} version={config?.vpn_version ?? ''} url={config?.vpn_apk ?? ''} text={t.downloadNow} unavailable={t.unavailable} />
              <DownloadCard name={t.accName} version={config?.acc_version ?? ''} url={config?.acc_apk ?? ''} text={t.downloadNow} unavailable={t.unavailable} />
            </>
          )}
        </div>
        <p className="note reveal">{t.note}</p>
      </div>
    </section>
  );
}

function PaymentMethodsSection({ lang }: { lang: Lang }) {
  const t = copy[lang].payments;
  const icons = ['contact-icons/USDT.png', 'contact-icons/wechat.png', 'contact-icons/alipay.png'].map(
    (path) => `${import.meta.env.BASE_URL}${path}`,
  );
  return (
    <section id="payments" className="section payment-section">
      <div className="section-inner">
        <div className="section-heading reveal">
          <div className="pill">{t.badge}</div>
          <h2>{t.titleA}<span>{t.titleB}</span></h2>
          <p>{t.subtitle}</p>
        </div>
        <div className="payment-grid">
          {t.items.map(([title, text], index) => (
            <article className="payment-card reveal" style={{ animationDelay: `${index * 90}ms` }} key={title}>
              <div className="payment-icon">
                <img src={icons[index]} alt="" />
              </div>
              <h3>{title}</h3>
              <p>{text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function ContactSection({ lang, config, loading }: { lang: Lang; config: DownloadConfig | null; loading: boolean }) {
  const t = copy[lang].contact;
  const [copied, setCopied] = useState('');
  const items = useMemo(() => {
    if (!config) return [];
    return [
      ['contact_wechat', t.wechat, config.contact_wechat, '#', `${import.meta.env.BASE_URL}contact-icons/wechat.png`],
      ['contact_telegram', t.telegram, config.contact_telegram, config.contact_telegram.startsWith('http') ? config.contact_telegram : `https://t.me/${config.contact_telegram.replace('@', '')}`, `${import.meta.env.BASE_URL}contact-icons/telegram.png`],
      ['telegram_subscription_url', t.telegramSubscription, config.telegram_subscription_url, config.telegram_subscription_url, `${import.meta.env.BASE_URL}contact-icons/telegram.png`],
      ['contact_qq', t.qq, config.contact_qq, `tencent://message/?uin=${config.contact_qq}`, `${import.meta.env.BASE_URL}contact-icons/qq.png`],
      ['contact_email', t.email, config.contact_email, `mailto:${config.contact_email}`, `${import.meta.env.BASE_URL}contact-icons/gmail.png`],
    ].filter((item) => String(item[2]).trim());
  }, [config, t]);

  return (
    <section id="contact" className="section contact-section">
      <div className="section-inner">
        <div className="section-heading reveal">
          <div className="pill blue">{t.badge}</div>
          <h2>{t.titleA}<span>{t.titleB}</span></h2>
          <p>{t.subtitle}</p>
        </div>
        {loading || items.length === 0 ? (
          <div className="contact-placeholder reveal">{loading ? t.loading : t.unavailable}</div>
        ) : (
          <div className="contact-grid">
            {items.map(([key, label, value, href, icon]) => (
            <article className="contact-card reveal" key={key}>
              <div className="contact-icon">
                {icon ? <img src={String(icon)} alt="" /> : String(label).slice(0, 2).toUpperCase()}
              </div>
              <small>{label}</small>
              <a href={href} target={String(href).startsWith('http') ? '_blank' : undefined} rel="noreferrer">{value}</a>
              <button
                type="button"
                onClick={async () => {
                  await navigator.clipboard.writeText(String(value));
                  setCopied(String(key));
                  window.setTimeout(() => setCopied(''), 1200);
                }}
              >
                {copied === key ? t.copied : t.copy}
              </button>
            </article>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

function BackToTop({ lang }: { lang: Lang }) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    function onScroll() {
      setVisible(window.scrollY > 460);
    }

    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <button
      type="button"
      className={`back-top ${visible ? 'show' : ''}`}
      onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
      aria-label={lang === 'zh' ? '返回顶部' : 'Back to top'}
      title={lang === 'zh' ? '返回顶部' : 'Back to top'}
    >
      <span aria-hidden="true">↑</span>
    </button>
  );
}

function App() {
  const [lang, setLang] = useState<Lang>(detectBrowserLang());
  const [config, setConfig] = useState<DownloadConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (window.location.hash) {
      window.history.replaceState(null, '', window.location.pathname + window.location.search);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function loadConfig() {
      try {
        const res = await fetch(siteConfigEndpoint, { cache: 'no-store' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.error) throw new Error(data.error);
        const encrypted = data.encrypted ?? data.data?.encrypted;
        const nextConfig = encrypted
          ? await decryptSiteConfig(encrypted)
          : normalizeSiteConfig(data);
        if (!cancelled) setConfig(nextConfig);
      } catch (err) {
        console.error('[site-config]', err);
        if (!cancelled) setError('failed');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void loadConfig();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <>
      <Navbar lang={lang} setLang={setLang} />
      <Hero lang={lang} />
      <Features lang={lang} />
      <GuideSection lang={lang} />
      <DownloadSection lang={lang} config={config} error={error} loading={loading} />
      <PaymentMethodsSection lang={lang} />
      <ContactSection lang={lang} config={config} loading={loading} />
      <footer><Logo size={32} /><span>{copy[lang].footer}</span></footer>
      <BackToTop lang={lang} />
    </>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
