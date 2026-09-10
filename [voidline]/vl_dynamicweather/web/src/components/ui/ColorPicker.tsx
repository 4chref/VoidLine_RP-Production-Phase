import { useRef } from "react";

// ── HSV ↔ hex yardımcıları ───────────────────────────────────────
function hsvToRgb(h: number, s: number, v: number): [number, number, number] {
    const c = v * s;
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    const m = v - c;
    let r = 0,
        g = 0,
        b = 0;
    if (h < 60) [r, g, b] = [c, x, 0];
    else if (h < 120) [r, g, b] = [x, c, 0];
    else if (h < 180) [r, g, b] = [0, c, x];
    else if (h < 240) [r, g, b] = [0, x, c];
    else if (h < 300) [r, g, b] = [x, 0, c];
    else [r, g, b] = [c, 0, x];
    return [
        Math.round((r + m) * 255),
        Math.round((g + m) * 255),
        Math.round((b + m) * 255),
    ];
}

const hx = (n: number) => n.toString(16).padStart(2, "0");

export function hsvToHex(h: number, s: number, v: number): string {
    const [r, g, b] = hsvToRgb(h, s, v);
    return `#${hx(r)}${hx(g)}${hx(b)}`;
}

export function hexToHsv(hex: string): { h: number; s: number; v: number } {
    const m = /^#?([0-9a-fA-F]{6})$/.exec(hex || "");
    let r = 138,
        g = 250,
        b = 0; // fallback (lime)
    if (m) {
        const i = parseInt(m[1], 16);
        r = (i >> 16) & 255;
        g = (i >> 8) & 255;
        b = i & 255;
    }
    r /= 255;
    g /= 255;
    b /= 255;
    const max = Math.max(r, g, b),
        min = Math.min(r, g, b),
        d = max - min;
    let h = 0;
    if (d) {
        if (max === r) h = (((g - b) / d) % 6 + 6) % 6;
        else if (max === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h *= 60;
    }
    return { h, s: max ? d / max : 0, v: max };
}

// Zone etiketi için koyu ton — seçilen rengin koyusu (metin kontrastı)
export function labelColorFor(hex: string): string {
    const { h, s } = hexToHsv(hex);
    return hsvToHex(h, Math.max(0.5, s), 0.28);
}

interface Props {
    value: string;
    onChange: (hex: string) => void;
}

// HSV renk çarkı (açı=ton, yarıçap=doygunluk) + parlaklık slider'ı. Bağımsız,
// FiveM CEF'te native color input'a güvenmeden çalışır. transform:scale altında
// da doğru: getBoundingClientRect ve clientX aynı ölçekli uzayda, oran korunur.
export default function ColorPicker({ value, onChange }: Props) {
    const { h, s, v } = hexToHsv(value);
    const wheelRef = useRef<HTMLDivElement>(null);
    const barRef = useRef<HTMLDivElement>(null);

    const pickWheel = (cx: number, cy: number) => {
        const el = wheelRef.current;
        if (!el) return;
        const r = el.getBoundingClientRect();
        const dx = cx - (r.left + r.width / 2);
        const dy = cy - (r.top + r.height / 2);
        const sat = Math.min(1, Math.hypot(dx, dy) / (r.width / 2));
        const hue = ((Math.atan2(dx, -dy) * 180) / Math.PI + 360) % 360; // tepe=0, saat yönü
        onChange(hsvToHex(hue, sat, v || 1));
    };

    const pickBar = (cx: number) => {
        const el = barRef.current;
        if (!el) return;
        const r = el.getBoundingClientRect();
        const t = Math.max(0, Math.min(1, (cx - r.left) / r.width));
        onChange(hsvToHex(h, s, t));
    };

    const drag =
        (fn: (cx: number, cy: number) => void) => (e: React.PointerEvent) => {
            e.preventDefault();
            fn(e.clientX, e.clientY);
            const move = (ev: PointerEvent) => fn(ev.clientX, ev.clientY);
            const up = () => {
                window.removeEventListener("pointermove", move);
                window.removeEventListener("pointerup", up);
            };
            window.addEventListener("pointermove", move);
            window.addEventListener("pointerup", up);
        };

    // Çark tutamaç konumu (yüzde): ton→açı (tepeden saat yönü), doygunluk→yarıçap
    const rad = (h * Math.PI) / 180;
    const thumbX = 50 + Math.sin(rad) * s * 50;
    const thumbY = 50 - Math.cos(rad) * s * 50;

    return (
        <div className="flex flex-col items-center gap-[14px]">
            <div
                ref={wheelRef}
                onPointerDown={drag(pickWheel)}
                className="relative size-[180px] cursor-crosshair touch-none rounded-full"
                style={{
                    background:
                        "radial-gradient(circle at center, #fff, rgba(255,255,255,0) 100%), conic-gradient(from 0deg, red, #ff0, lime, cyan, blue, magenta, red)",
                }}
            >
                <span
                    className="pointer-events-none absolute size-[16px] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_1px_4px_rgba(0,0,0,0.6)]"
                    style={{ left: `${thumbX}%`, top: `${thumbY}%`, backgroundColor: value }}
                />
            </div>
            <div
                ref={barRef}
                onPointerDown={drag((cx) => pickBar(cx))}
                className="relative h-[18px] w-[180px] cursor-pointer touch-none rounded-full"
                style={{ background: `linear-gradient(to right, #000, ${hsvToHex(h, s, 1)})` }}
            >
                <span
                    className="pointer-events-none absolute top-1/2 size-[16px] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_1px_4px_rgba(0,0,0,0.6)]"
                    style={{ left: `${v * 100}%`, backgroundColor: value }}
                />
            </div>
        </div>
    );
}
