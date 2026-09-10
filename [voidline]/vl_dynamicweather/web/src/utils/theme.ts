// UI accent teması. Renk Config.Theme'den gelir (client → getConfig.themeColor),
// App mount'ta applyTheme ile uygulanır. İki tüketim yolu:
//   • CSS (Tailwind arbitrary + index.css): var(--cdw-accent) [solid],
//     rgb(var(--cdw-accent-rgb) / a) [opaklık], var(--cdw-accent-dark) [koyu ton].
//   • JS/canvas (Leaflet — var() ÇALIŞMAZ): getAccent() / getAccentDark() gerçek hex döner.
// Varsayılan #DC143C (index.css :root'ta da tanımlı → config gelmeden önce de doğru render).

const DEFAULT_ACCENT = "#DC143C";

let accent = DEFAULT_ACCENT;
let accentDark = "#4D000F";
let onAccent = "#FFFFFF"; // accent zemini üzerindeki yazı/ikon rengi (oto siyah/beyaz)

// "#abc" / "abc" / "#aabbcc" / "aabbcc" → "#AABBCC"; geçersizse null.
function normalizeHex(input: unknown): string | null {
    if (typeof input !== "string") return null;
    let h = input.trim();
    if (h[0] !== "#") h = "#" + h;
    if (/^#[0-9a-fA-F]{3}$/.test(h)) {
        h = "#" + h[1] + h[1] + h[2] + h[2] + h[3] + h[3];
    }
    return /^#[0-9a-fA-F]{6}$/.test(h) ? h.toUpperCase() : null;
}

function channels(hex: string): [number, number, number] {
    return [
        parseInt(hex.slice(1, 3), 16),
        parseInt(hex.slice(3, 5), 16),
        parseInt(hex.slice(5, 7), 16),
    ];
}

// Accent'ın koyu tonu (buton kenarı vb.). Tüm renklerde doğal bir koyu gölge verir.
// #DC143C için ~#4B0714 → orijinal tasarımın #4D000F'una çok yakın.
function darken(hex: string, factor: number): string {
    const [r, g, b] = channels(hex);
    const to2 = (n: number) => Math.round(n * factor).toString(16).padStart(2, "0");
    return ("#" + to2(r) + to2(g) + to2(b)).toUpperCase();
}

// WCAG göreli parlaklık (0=siyah, 1=beyaz).
function relLuminance(hex: string): number {
    const lin = channels(hex).map((v) => {
        const c = v / 255;
        return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}

// Accent üzerine gelen yazı/ikon rengi: açık accent (cyan/beyaz/sarı...) → siyah,
// koyu accent (kırmızı/mor...) → beyaz. Eşik ~0.35 kırmızıyı beyazda tutar.
function contrastColor(hex: string): string {
    return relLuminance(hex) > 0.35 ? "#000000" : "#FFFFFF";
}

// Config renginden CSS değişkenlerini + JS accent'i günceller. Geçersiz renkte default kalır.
export function applyTheme(color: unknown): void {
    const hex = normalizeHex(color);
    if (!hex) return;
    accent = hex;
    accentDark = darken(hex, 0.34);
    onAccent = contrastColor(hex);
    const [r, g, b] = channels(hex);
    const root = document.documentElement;
    root.style.setProperty("--cdw-accent", accent);
    root.style.setProperty("--cdw-accent-rgb", `${r} ${g} ${b}`);
    root.style.setProperty("--cdw-accent-dark", accentDark);
    root.style.setProperty("--cdw-on-accent", onAccent);
}

// Leaflet/canvas gibi var() desteklemeyen yerler için gerçek hex.
export function getAccent(): string {
    return accent;
}

export function getAccentDark(): string {
    return accentDark;
}

// Accent zemini üzerindeki içerik rengi (oto siyah/beyaz).
export function getOnAccent(): string {
    return onAccent;
}
