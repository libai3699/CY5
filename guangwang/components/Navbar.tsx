'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';
import { copy, type Lang } from '@/lib/i18n';

interface NavbarProps {
  lang: Lang;
  onToggleLang: () => void;
}

export default function Navbar({ lang, onToggleLang }: NavbarProps) {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const t = copy[lang].nav;

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    handleScroll();
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
    e.preventDefault();
    setMenuOpen(false);
    document.querySelector(href)?.scrollIntoView({ behavior: 'smooth' });
  };

  const links = [
    { href: '#features', label: t.features },
    { href: '#download', label: t.download },
    { href: '#contact', label: t.contact },
  ];

  return (
    <header
      className={`fixed top-0 z-50 w-full transition-all duration-300 ${
        scrolled
          ? 'border-b border-white/10 bg-black/40 shadow-lg shadow-black/20 backdrop-blur-md'
          : 'border-b border-white/5 bg-black/15 backdrop-blur-sm'
      }`}
    >
      <nav className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 overflow-hidden rounded-md shadow-lg shadow-purple-500/30">
              <Image src="/logo.png" alt="9.9 VPN Logo" width={36} height={36} className="h-full w-full object-cover" priority />
            </div>
            <span className="text-lg font-bold tracking-tight text-white">
              9.9 <span className="text-gradient">VPN</span>
            </span>
          </div>

          <div className="hidden items-center gap-8 md:flex">
            {links.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={(e) => handleNavClick(e, link.href)}
                className="text-sm font-medium text-slate-300 transition-colors duration-200 hover:text-white"
              >
                {link.label}
              </a>
            ))}
            <button
              type="button"
              onClick={onToggleLang}
              className="min-h-[40px] rounded-full border border-white/15 px-4 text-sm font-semibold text-slate-200 transition hover:border-white/35 hover:text-white"
            >
              {t.language}
            </button>
            <a
              href="#download"
              onClick={(e) => handleNavClick(e, '#download')}
              className="btn-gradient flex min-h-[44px] items-center rounded-full px-5 py-2 text-sm font-semibold text-white"
            >
              {t.freeDownload}
            </a>
          </div>

          <button
            className="flex min-h-[44px] min-w-[44px] items-center justify-center rounded-lg p-2 text-slate-300 transition-colors hover:bg-white/10 hover:text-white md:hidden"
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label={menuOpen ? t.closeMenu : t.openMenu}
            aria-expanded={menuOpen}
          >
            {menuOpen ? (
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            ) : (
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M4 6h16M4 12h16M4 18h16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            )}
          </button>
        </div>

        {menuOpen && (
          <div className="space-y-1 border-t border-white/10 py-4 md:hidden">
            {links.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={(e) => handleNavClick(e, link.href)}
                className="flex min-h-[44px] items-center rounded-lg px-4 py-3 text-sm font-medium text-slate-300 transition-colors hover:bg-white/5 hover:text-white"
              >
                {link.label}
              </a>
            ))}
            <button
              type="button"
              onClick={() => {
                setMenuOpen(false);
                onToggleLang();
              }}
              className="flex min-h-[44px] w-full items-center rounded-lg px-4 py-3 text-left text-sm font-medium text-slate-300 transition-colors hover:bg-white/5 hover:text-white"
            >
              {t.language}
            </button>
            <div className="px-4 pt-2">
              <a
                href="#download"
                onClick={(e) => handleNavClick(e, '#download')}
                className="btn-gradient flex min-h-[44px] w-full items-center justify-center rounded-full px-5 py-3 text-center text-sm font-semibold text-white"
              >
                {t.freeDownload}
              </a>
            </div>
          </div>
        )}
      </nav>
    </header>
  );
}
