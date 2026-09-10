import type { ForecastEntry, WeatherType } from "@/types";
import { t } from "@/utils/locale";
import { is24h } from "@/utils/config";

// UI'da gösterilen okunabilir isim ve temsili sıcaklık değerleri.
// Oyun tarafında gerçek sıcaklık verisi olmadığı için hava tipine göre sabitlenir.
export const WEATHER_META: Record<WeatherType, { label: string; temp: number }> = {
    EXTRASUNNY: { label: "Extra Sunny", temp: 30 },
    CLEAR: { label: "Clear", temp: 26 },
    NEUTRAL: { label: "Neutral", temp: 22 },
    SMOG: { label: "Smog", temp: 24 },
    FOGGY: { label: "Foggy", temp: 15 },
    CLOUDS: { label: "Cloudy", temp: 20 },
    OVERCAST: { label: "Overcast", temp: 18 },
    CLEARING: { label: "Clearing", temp: 19 },
    RAIN: { label: "Rainy", temp: 16 },
    THUNDER: { label: "Thunder", temp: 15 },
    SNOWLIGHT: { label: "Light Snow", temp: 2 },
    SNOW: { label: "Snow", temp: -1 },
    BLIZZARD: { label: "Blizzard", temp: -6 },
    XMAS: { label: "Xmas", temp: -3 },
    HALLOWEEN: { label: "Blood Orange", temp: 47 },
};

export const WEATHER_TYPES = Object.keys(WEATHER_META) as WeatherType[];

// Modal açılırken sıcaklık ön-dolgusu (öneri). Gerçek değer kullanıcı girişidir.
// TEK NOKTA: ileride bu değerler Config'ten okunacak — o zaman burası değişir.
export function defaultTemp(weather: WeatherType): number {
    return WEATHER_META[weather].temp;
}

// Sıcaklık → renk (sıcak turuncu → ılık yeşil/teal → soğuk mavi).
// Rüzgar şeridi gradient'inde kullanılır. Eşikler preview'de ayarlanabilir; tek nokta.
export function tempColor(temp: number): string {
    if (temp >= 36) return "#FF3B30"; // aşırı sıcak — kırmızı
    if (temp >= 30) return "#FA7B00"; // kavurucu — turuncu
    if (temp >= 24) return "#FAD900"; // sıcak — sarı
    if (temp >= 18) return "#CCFA00"; // ılık — lime
    if (temp >= 11) return "#00FAA3"; // serin — teal
    if (temp >= 4) return "#7FD8FF"; // soğuk — açık buz mavisi
    if (temp >= -6) return "#54B9FF"; // yağmurlu/çok soğuk — buz mavisi
    return "#3A97F0"; // karlı/dondurucu (blizzard -6..) — buz mavisi (koyu değil)
}

// Sıcaklığa göre opaklık — U şekli: ılık/yeşil (18°) en şeffaf, hem sıcak (kırmızı)
// hem soğuk (buz mavisi) uçlar daha opak/görünür. Böylece maviler yeşile karışmıyor.
export function tempOpacity(temp: number): number {
    const o = 0.45 + (Math.abs(temp - 18) / 40) * 0.5;
    return Math.max(0.45, Math.min(0.7, o));
}

// Saat gösterimi — Config.TimeFormat'e göre 24s (20:00) ya da 12s (8:00 PM).
export function formatClock(hour: number, minute: number): string {
    const mm = String(minute).padStart(2, "0");
    if (is24h()) return `${String(hour).padStart(2, "0")}:${mm}`;
    const period = hour >= 12 ? "PM" : "AM";
    const h = hour % 12 === 0 ? 12 : hour % 12;
    return `${h}:${mm} ${period}`;
}

// Forecast girişinin cast-time'ını seçili formatta gösterir.
export function formatCastTime(hour: number, minute: number): string {
    return formatClock(hour, minute);
}

// Dinamik alanın o anki AKTİF forecast girdisi — Lua scheduleWeather ile birebir:
// cast-time'ı şimdiye eşit/küçük en geç giriş; hiçbiri yoksa gün başına sarıp en son
// giriş (dün akşamdan devam). clock ~2sn'de güncellendiği için kart otomatik yenilenir.
export function activeForecast(
    forecast: ForecastEntry[],
    clock: { hour: number; minute: number } | undefined
): ForecastEntry | null {
    if (!forecast || forecast.length === 0 || !clock) return null;
    const nowMin = clock.hour * 60 + clock.minute;
    let best: ForecastEntry | null = null;
    let bestMin = -1;
    let latest: ForecastEntry | null = null;
    let latestMin = -1;
    for (const e of forecast) {
        const m = e.atHour * 60 + e.atMinute;
        if (m > latestMin) {
            latest = e;
            latestMin = m;
        }
        if (m <= nowMin && m > bestMin) {
            best = e;
            bestMin = m;
        }
    }
    return best ?? latest;
}

// Bir sonraki forecast girdisine kalan süreyi "In 1 Hour" / "In 25 Min" biçiminde
// döndürür (Figma "Up Next" kartı). Sonraki giriş yoksa gün başına sarar.
export function relativeCastLabel(
    entry: ForecastEntry,
    clock: { hour: number; minute: number } | undefined
): string {
    if (!clock) return formatCastTime(entry.atHour, entry.atMinute);
    const nowMin = clock.hour * 60 + clock.minute;
    let diff = entry.atHour * 60 + entry.atMinute - nowMin;
    if (diff < 0) diff += 1440; // ertesi güne sar
    return relativeFromMinutes(diff);
}

// Dinamik alanın SONRAKİ forecast girdisi — cast-time'ı şu andan sonraki en yakın
// (gün başına sarar). Kart "Up Next → X" için. Girdi yoksa null.
export function nextForecast(
    forecast: ForecastEntry[],
    clock: { hour: number; minute: number } | undefined
): ForecastEntry | null {
    if (!forecast || forecast.length === 0 || !clock) return null;
    const nowMin = clock.hour * 60 + clock.minute;
    let best: ForecastEntry | null = null;
    let bestDiff = Infinity;
    for (const e of forecast) {
        let diff = e.atHour * 60 + e.atMinute - nowMin;
        if (diff <= 0) diff += 1440; // ertesi güne sar
        if (diff < bestDiff) {
            bestDiff = diff;
            best = e;
        }
    }
    return best;
}

// Kalan oyun-dakikasını "Now" / "In X Min" / "In X Hour(s)" biçiminde döndürür.
export function relativeFromMinutes(diff: number): string {
    if (diff <= 0) return t("relative.now");
    if (diff < 60) return t("relative.inMin", { n: diff });
    const h = Math.round(diff / 60);
    return h > 1 ? t("relative.inHours", { n: h }) : t("relative.inHour", { n: h });
}
