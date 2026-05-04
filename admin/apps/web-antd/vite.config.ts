import { defineConfig } from '@vben/vite-config';

const config = require('./src/configs');

export default defineConfig(async () => {
  return {
    application: {},
    vite: {
      define: {
        'import.meta.env.VITE_APP_TITLE': JSON.stringify(config.APP_TITLE),
        'import.meta.env.VITE_APP_NAMESPACE': JSON.stringify(config.APP_NAMESPACE),
        'import.meta.env.VITE_APP_VERSION': JSON.stringify(config.APP_VERSION),
        'import.meta.env.VITE_GLOB_API_URL': JSON.stringify(config.API_BASE_URL),
        'import.meta.env.VITE_PORT': JSON.stringify(config.PORT),
        'import.meta.env.VITE_BASE': JSON.stringify(config.BASE),
        'import.meta.env.VITE_NITRO_MOCK': JSON.stringify(config.NITRO_MOCK),
        'import.meta.env.VITE_DEVTOOLS': JSON.stringify(config.DEVTOOLS),
        'import.meta.env.VITE_INJECT_APP_LOADING': JSON.stringify(config.INJECT_APP_LOADING),
        'import.meta.env.VITE_APP_STORE_SECURE_KEY': JSON.stringify(config.STORE_SECURE_KEY),
      },
      server: {
        port: config.PORT,
        proxy: {
          '/api': {
            changeOrigin: true,
            rewrite: (path) => path.replace(/^\/api/, ''),
            target: config.API_BASE_URL,
            ws: true,
          },
        },
      },
    },
  };
});
