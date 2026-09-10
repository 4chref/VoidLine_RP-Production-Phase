import { useState } from "react";

interface TimeInputProps {
    hour: number;
    minute: number;
    onChange: (hour: number, minute: number) => void;
}

const clamp = (v: number, max: number) => Math.max(0, Math.min(max, v));
const two = (n: number) => String(n).padStart(2, "0");

// Figma 1-1018 Time alanı: iki kutu (SS : DD), bg black/25, h-48, rounded-16, w-104.
//
// Düzenlerken serbest yazılabilsin diye "editing" kutusunda yerel taslak (draft)
// gösterilir; boşaltmak/kısmi yazmak serbesttir ve yalnız geçerli rakam varken
// üst state'e commit edilir. Odak dışındayken değer prop'tan (00 dolgulu) türetilir.
// (Eski sürüm value'yu hep padStart+maxLength=2 ile doldurduğu için baştaki
//  haneyi değiştirmek/silmek imkânsızdı.)
export default function TimeInput({ hour, minute, onChange }: TimeInputProps) {
    const box =
        "h-[48px] w-[104px] rounded-[16px] bg-black/25 text-center text-[16px] font-semibold tracking-[-0.64px] text-white transition-shadow placeholder:text-white/20 focus:outline-none focus:ring-2 focus:ring-[rgb(var(--cdw-accent-rgb)_/_0.4)]";

    const [editing, setEditing] = useState<"h" | "m" | null>(null);
    const [draft, setDraft] = useState("");

    const hVal = editing === "h" ? draft : two(hour);
    const mVal = editing === "m" ? draft : two(minute);

    const startEdit = (which: "h" | "m", e: React.FocusEvent<HTMLInputElement>) => {
        setEditing(which);
        setDraft(which === "h" ? two(hour) : two(minute));
        e.target.select(); // tümünü seç → yazınca komple değişsin
    };

    const change = (which: "h" | "m", raw: string) => {
        const digits = raw.replace(/\D/g, "").slice(0, 2);
        setDraft(digits);
        if (digits === "") return; // boşken üst state'i değiştirme
        const v = clamp(parseInt(digits, 10), which === "h" ? 23 : 59);
        if (which === "h") onChange(v, minute);
        else onChange(hour, v);
    };

    return (
        <div className="flex items-center gap-[13px]">
            <input
                inputMode="numeric"
                maxLength={2}
                value={hVal}
                onFocus={(e) => startEdit("h", e)}
                onChange={(e) => change("h", e.target.value)}
                onBlur={() => setEditing(null)}
                className={box}
            />
            <span className="text-[20px] font-semibold tracking-[-0.8px] text-white/20">:</span>
            <input
                inputMode="numeric"
                maxLength={2}
                value={mVal}
                onFocus={(e) => startEdit("m", e)}
                onChange={(e) => change("m", e.target.value)}
                onBlur={() => setEditing(null)}
                className={box}
            />
        </div>
    );
}
