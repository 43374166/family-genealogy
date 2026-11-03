import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

/**
 * 开发环境把 /api 反向代理到 Go 服务端，生产环境默认与 API 同源。
 * 当前默认连接云端（10443）；本地联调在 .env.local 中覆盖 VITE_PROXY_TARGET。
 */
export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const proxyTarget = env.VITE_PROXY_TARGET || 'https://family.fishdream.xyz:10443';
  const apiProxy = {
    '/api': {
      target: proxyTarget,
      changeOrigin: true,
      secure: false,
    },
  };

  return {
    base: '/',
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, 'src'),
      },
    },
    server: {
      host: '127.0.0.1',
      port: 5173,
      strictPort: true,
      proxy: command === 'serve' ? apiProxy : undefined,
    },
    preview: {
      host: '127.0.0.1',
      port: 4173,
      strictPort: true,
      proxy: apiProxy,
    },
    build: {
      outDir: 'dist',
      sourcemap: env.VITE_SOURCE_MAP === 'true',
      chunkSizeWarningLimit: 900,
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (!id.includes('node_modules')) return undefined;
            if (id.includes('@xyflow')) return 'vendor-flow';
            if (id.includes('@douyinfe')) return 'vendor-semi';
            if (
              /node_modules[\\/](react|react-dom|react-router|react-router-dom|scheduler|react-redux|@reduxjs|redux|immer|reselect|use-sync-external-store)[\\/]/.test(
                id,
              )
            ) {
              return 'vendor-react';
            }
            if (id.includes('@dagrejs') || id.includes('dagre')) return 'vendor-layout';
            return undefined;
          },
        },
      },
    },
  };
});
