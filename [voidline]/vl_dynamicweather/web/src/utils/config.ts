// UI config (oyun içinde client → getConfig ile gelir). Modül seviyesi, locale
// ile aynı desen: mount'ta bir kez set edilir, format fonksiyonları okur.

import { applyTheme } from "./theme";

type TimeFormat = "12" | "24";

let timeFormat: TimeFormat = "12";

export function setConfig(cfg: unknown) {
    if (cfg && typeof cfg === "object") {
        const tf = (cfg as { timeFormat?: unknown }).timeFormat;
        if (tf === "24" || tf === "12") timeFormat = tf;
        // UI accent rengi (Config.Theme) — geçersizse theme.ts default'ta kalır
        applyTheme((cfg as { themeColor?: unknown }).themeColor);
        // Rüzgar şeridi akış animasyonu (perf). false → kök sınıf ile animasyon kapatılır.
        const flow = (cfg as { windRibbonFlow?: unknown }).windRibbonFlow;
        document.documentElement.classList.toggle("cdw-no-ribbon-flow", flow === false);
    }
}

export function is24h(): boolean {
    return timeFormat === "24";
}
