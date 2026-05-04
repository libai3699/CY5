import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import vueJsx from '@vitejs/plugin-vue-jsx';
import Components from 'unplugin-vue-components/vite';
import { AntDesignVueResolver } from 'unplugin-vue-components/resolvers';
import { resolve } from 'path';

const config = require('./src/configs');

export default defineConfig({
  plugins: [
    vue(),
    vueJsx(),
    Components({
      resolvers: [
        AntDesignVueResolver({
          importStyle: false,
        }),
      ],
    }),
  ],
  
  resolve: {
    alias: {
      '#': resolve(__dirname, 'src'),
      '@': resolve(__dirname, 'src'),
    },
  },

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
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: config.API_BASE_URL,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
        ws: true,
      },
    },
  },

  build: {
    target: 'es2015',
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    chunkSizeWarningLimit: 1500,
    rollupOptions: {
      output: {
        manualChunks: {
          'vue-vendor': ['vue', 'vue-router', 'pinia'],
          'antd-vendor': ['ant-design-vue', '@ant-design/icons-vue'],
        },
      },
    },
  },
});
