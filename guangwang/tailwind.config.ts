import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          purple: '#7c3aed',
          blue: '#2563eb',
        },
        bg: {
          dark: '#0a0a0f',
          darker: '#0f0a1e',
        },
      },
      backgroundImage: {
        'gradient-primary': 'linear-gradient(135deg, #7c3aed 0%, #2563eb 100%)',
        'gradient-dark': 'linear-gradient(135deg, #0a0a0f 0%, #0f0a1e 100%)',
      },
      keyframes: {
        fadeInUp: {
          '0%': {
            opacity: '0',
            transform: 'translateY(24px)',
          },
          '100%': {
            opacity: '1',
            transform: 'translateY(0)',
          },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
      },
      animation: {
        'fade-in-up': 'fadeInUp 0.6s ease-out forwards',
        'fade-in-up-delay-1': 'fadeInUp 0.6s ease-out 0.1s forwards',
        'fade-in-up-delay-2': 'fadeInUp 0.6s ease-out 0.2s forwards',
        'fade-in-up-delay-3': 'fadeInUp 0.6s ease-out 0.3s forwards',
        'fade-in-up-delay-4': 'fadeInUp 0.6s ease-out 0.4s forwards',
        'fade-in': 'fadeIn 0.6s ease-out forwards',
        shimmer: 'shimmer 2s linear infinite',
      },
    },
  },
  plugins: [],
};

export default config;
