'use client';

import { useEffect, useState } from 'react';
import Navbar from '@/components/Navbar';
import Hero from '@/components/Hero';
import Features from '@/components/Features';
import DownloadSection from '@/components/DownloadSection';
import ContactSection from '@/components/ContactSection';
import Footer from '@/components/Footer';
import BackToTop from '@/components/BackToTop';
import { detectBrowserLang, nextLang, type Lang } from '@/lib/i18n';

export default function Home() {
  const [lang, setLang] = useState<Lang>('en');

  useEffect(() => {
    setLang(detectBrowserLang());
  }, []);

  return (
    <>
      <Navbar lang={lang} onToggleLang={() => setLang((value) => nextLang(value))} />
      <Hero lang={lang} />
      <Features lang={lang} />
      <DownloadSection lang={lang} />
      <ContactSection lang={lang} />
      <Footer lang={lang} />
      <BackToTop lang={lang} />
    </>
  );
}
