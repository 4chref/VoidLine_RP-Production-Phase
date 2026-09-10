import iconFallback from "@/assets/icon-rainy.svg";
import type { WeatherType } from "@/types";

// Drop-in: web/src/assets/weatherIcons/<WEATHER>.svg dosyaları eklendikçe otomatik eşlenir.
// Dosya adı WeatherType ile birebir olmalı (ör. EXTRASUNNY.svg). Kaynak: Figma node 1-1523.
// Henüz ikon yoksa fallback (icon-rainy) döner — build kırılmaz.
const modules = import.meta.glob("../assets/weatherIcons/*.svg", {
    eager: true,
    query: "?url",
    import: "default",
}) as Record<string, string>;

const ICONS: Partial<Record<WeatherType, string>> = {};
for (const path in modules) {
    const name = path.split("/").pop()!.replace(/\.svg$/, "") as WeatherType;
    ICONS[name] = modules[path];
}

export function weatherIcon(weather: WeatherType): string {
    return ICONS[weather] ?? iconFallback;
}
