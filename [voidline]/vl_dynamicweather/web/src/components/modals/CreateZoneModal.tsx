import { useEffect, useRef, useState } from "react";
import type { WeatherType } from "@/types";
import { defaultTemp } from "@/utils/weather";
import { ZONE_COLORS } from "@/utils/zones";
import { t } from "@/utils/locale";
import Modal from "@/components/ui/Modal";
import WeatherSelect from "@/components/ui/WeatherSelect";
import TempInput from "@/components/ui/TempInput";
import PrimaryButton from "@/components/ui/PrimaryButton";
import FieldLabel from "@/components/ui/FieldLabel";
import ColorPicker, { labelColorFor } from "@/components/ui/ColorPicker";

export interface CreateZoneData {
    name: string;
    color: string;
    labelColor: string;
    weather: WeatherType;
    temperature: number;
}

interface CreateZoneModalProps {
    defaultName: string;
    // Başlangıç renk paleti index'i (yeni zone sırasına göre)
    colorIndex: number;
    onClose: () => void;
    onCreate: (data: CreateZoneData) => void;
}

// Figma: node 1-255 (Create Weather Zone). Yeni eleman: "Zone Name & Color" satırı
// (renk swatch + isim input). Renk swatch'a tıklayınca palet arasında döner.
export default function CreateZoneModal({
    defaultName,
    colorIndex,
    onClose,
    onCreate,
}: CreateZoneModalProps) {
    const [name, setName] = useState("");
    const [color, setColor] = useState(
        ZONE_COLORS[colorIndex % ZONE_COLORS.length].color
    );
    const [weather, setWeather] = useState<WeatherType>();
    const [temp, setTemp] = useState<number | "">("");
    const [paletteOpen, setPaletteOpen] = useState(false);
    const paletteRef = useRef<HTMLDivElement>(null);

    // Palet açıkken dışarı tıklayınca kapat
    useEffect(() => {
        if (!paletteOpen) return;
        const onDown = (e: MouseEvent) => {
            if (paletteRef.current && !paletteRef.current.contains(e.target as Node)) {
                setPaletteOpen(false);
            }
        };
        document.addEventListener("mousedown", onDown);
        return () => document.removeEventListener("mousedown", onDown);
    }, [paletteOpen]);

    const create = () => {
        const w = weather ?? "CLEAR";
        onCreate({
            name: name.trim() || defaultName,
            color,
            labelColor: labelColorFor(color),
            weather: w,
            temperature: temp === "" ? defaultTemp(w) : temp,
        });
    };

    return (
        <Modal
            title={t("modals.createZoneTitle")}
            onClose={onClose}
            footer={
                <PrimaryButton onClick={create} disabled={!weather}>
                    {t("modals.createZoneCta")}
                </PrimaryButton>
            }
        >
            <FieldLabel>{t("modals.zoneNameColor")}</FieldLabel>
            <div className="flex items-center gap-[8px]">
                <div ref={paletteRef} className="relative shrink-0">
                    <button
                        type="button"
                        onClick={() => setPaletteOpen((o) => !o)}
                        className="flex size-[56px] items-center justify-center rounded-[16px] border-2 border-white/10 bg-white/5 transition-colors hover:bg-white/10"
                        title={t("map.tools.changeColor")}
                    >
                        <span
                            className="size-[20px] rounded-full ring-2 ring-white/15"
                            style={{ backgroundColor: color }}
                        />
                    </button>
                    {paletteOpen && (
                        <div className="cdw-card-in absolute left-0 top-[64px] z-[20] rounded-[16px] border border-white/10 bg-[#242424] p-[16px] shadow-[0px_16px_40px_rgba(0,0,0,0.5)]">
                            <ColorPicker value={color} onChange={setColor} />
                        </div>
                    )}
                </div>
                <input
                    autoFocus
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder={t("modals.myZone")}
                    className="h-[56px] flex-1 rounded-[16px] bg-black/25 px-[20px] text-[16px] font-semibold tracking-[-0.64px] text-white transition-shadow placeholder:text-white/20 focus:outline-none focus:ring-2 focus:ring-[rgb(var(--cdw-accent-rgb)_/_0.4)]"
                />
            </div>

            <FieldLabel>{t("modals.currentWeather")}</FieldLabel>
            <WeatherSelect
                value={weather}
                onChange={(w) => {
                    setWeather(w);
                    if (temp === "") setTemp(defaultTemp(w));
                }}
            />

            <FieldLabel>{t("modals.temperature")}</FieldLabel>
            <TempInput value={temp} onChange={setTemp} />
        </Modal>
    );
}
