import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync } from 'node:fs'

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'))

export default defineConfig({
  base: './',
  plugins: [react()],
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  esbuild: { drop: ['console', 'debugger'], legalComments: 'none' },
  build: {
    outDir: 'dist', target: 'es2020', reportCompressedSize: false, chunkSizeWarningLimit: 1200, modulePreload: { polyfill: false },
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes('node_modules')) return undefined
          if (/node_modules\/(react|react-dom|scheduler)\//.test(id)) return 'vendor-react'
          if (id.includes('@supabase')) return 'vendor-supabase'
          if (id.includes('@capacitor') || id.includes('@capgo')) return 'vendor-capacitor'
          return undefined
        },
      },
    },
  },
})
