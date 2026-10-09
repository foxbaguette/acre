import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: process.env.BASE_PATH ?? '/',
  plugins: [react()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) }
  },
  server: { port: 5192, strictPort: true },
  preview: { port: 5193, strictPort: true },
  build: {
    target: 'es2022',
    // WharfKit is loaded on first use (src/wallet/session.ts) and gets its own chunks.
    chunkSizeWarningLimit: 700
  }
})
