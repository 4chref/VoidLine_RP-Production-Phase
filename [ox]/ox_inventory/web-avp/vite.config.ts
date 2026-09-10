import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  build: {
    // VoidLine: was '../../html' (AVP's own NUI folder). Retargeted so this
    // build can never overwrite ox_inventory's working web/build -- that stays
    // the live UI until this one is verified in game.
    outDir: '../web/avp-build',
    emptyOutDir: true
  },
  base: './',
  assetsInclude: []
})
