import { useEffect, useRef, useState } from "react";
import type { WeatherType } from "@/types";
import { WEATHER_TYPES } from "@/utils/weather";
import { t, tWeather } from "@/utils/locale";

interface WeatherSelectProps {
    value?: WeatherType;
    onChange: (weather: WeatherType) => void;
    placeholder?: string;
}

// Figma 1:1 — kapalı kutu: bg #202020, h-56, rounded-20, sağda chevron.
// Not: Figma'da yalnızca kapalı hâl var; açık liste stili kutuyla tutarlı seçildi
// (bkz. TASKS.md "Açık kararlar").
export default function WeatherSelect({ value, onChange, placeholder }: WeatherSelectProps) {
    const ph = placeholder ?? t("modals.selectType");
    const [open, setOpen] = useState(false);
    const ref = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const onDoc = (e: MouseEvent) => {
            if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
        };
        document.addEventListener("mousedown", onDoc);
        return () => document.removeEventListener("mousedown", onDoc);
    }, []);

    return (
        <div ref={ref} className="relative">
            <button
                type="button"
                onClick={() => setOpen((o) => !o)}
                className="flex h-[56px] w-full items-center justify-between rounded-[20px] border border-white/5 bg-[#202020] px-[20px]"
            >
                <span
                    className={`text-[16px] font-semibold tracking-[-0.64px] text-white ${
                        value ? "" : "opacity-20"
                    }`}
                >
                    {value ? tWeather(value) : ph}
                </span>
                <svg
                    className={`size-[20px] text-white transition-transform ${open ? "rotate-180" : ""}`}
                    viewBox="0 0 20 20"
                    fill="none"
                >
                    <path d="M5 8l5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
            </button>

            {open && (
                <div className="absolute left-0 right-0 top-[62px] z-[10] max-h-[240px] overflow-y-auto rounded-[16px] border border-white/5 bg-[#202020] p-[6px] shadow-[0px_20px_40px_0px_rgba(0,0,0,0.5)]">
                    {WEATHER_TYPES.map((weather) => (
                        <button
                            key={weather}
                            type="button"
                            onClick={() => {
                                onChange(weather);
                                setOpen(false);
                            }}
                            className={`block w-full rounded-[10px] px-[14px] py-[10px] text-left text-[15px] font-semibold tracking-[-0.5px] transition-colors ${
                                value === weather
                                    ? "bg-[var(--cdw-accent)] text-[var(--cdw-on-accent)]"
                                    : "text-white/70 hover:bg-white/10"
                            }`}
                        >
                            {tWeather(weather)}
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}
