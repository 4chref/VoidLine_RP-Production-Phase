import { installInboundBridge } from './plugins/ox-adapter';
import { createPinia } from 'pinia';
import { createApp, ref } from 'vue'
import App from './App.vue'
import "./global.scss";
import 'animate.css';

createApp(App)
    .use(createPinia())
    .mount('#app');

if (import.meta.env.DEV) {
    document.body.style.backgroundColor = "grey";
}

// VoidLine: translate ox_inventory's SendNUIMessage traffic into the window
// messages the AVP stores already listen for. Must run before the app mounts
// so the very first setupInventory is not missed.
installInboundBridge();