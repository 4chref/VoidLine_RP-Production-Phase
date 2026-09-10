import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  base: './',
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
    // Tek React örneği — @dnd-kit gibi hook kullanan bağımlılıklarla
    // "Invalid hook call" (çift React kopyası) hatasını önler
    dedupe: ['react', 'react-dom'],
  },
  build: {
    outDir: '../html',
    emptyOutDir: true,
    assetsDir: './',
    rollupOptions: {
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name].[ext]',
      },
    },
  },
})
