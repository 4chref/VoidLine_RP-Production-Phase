import { useRef, useState } from "react";
import {
    DndContext,
    PointerSensor,
    closestCenter,
    useSensor,
    useSensors,
    type DragEndEvent,
} from "@dnd-kit/core";
import {
    SortableContext,
    useSortable,
    verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import type { ForecastEntry, WeatherArea } from "@/types";
import {
    activeForecast,
    formatCastTime,
    nextForecast,
    relativeCastLabel,
} from "@/utils/weather";
import { t, tWeather } from "@/utils/locale";
import { weatherIcon } from "@/utils/weatherIcon";
import cloudPlaceholder from "@/assets/cloud-placeholder.svg";
import tempGraph from "@/assets/temp-graph.svg";

// "PALETO BAY" → "Paleto Bay" (şehir adları büyük harfli saklanır; etikette şık dursun)
const titleCase = (s: string) =>
    s.toLowerCase().replace(/(^|\s)\S/g, (c) => c.toUpperCase());

type Clock = { hour: number; minute: number } | undefined;

interface WeatherPanelProps {
    // Aktif katmandaki (City Wide → şehirler, Zone Base → zone'lar) alanlar
    areas: WeatherArea[];
    selectedArea: WeatherArea | null;
    // Oyun içi saat — dinamik alanın o anki aktif havasını hesaplamak için
    clock: Clock;
    onSelectArea: (id: number) => void;
    onClearSelection: () => void;
    onOpenStaticModal: () => void;
    // Liste görünümü (seçim yok): tüm alanları tek statik havaya çek
    onChangeStaticAll: () => void;
    onToggleDynamic: () => void;
    onAddForecast: () => void;
    onEditForecast: (index: number) => void;
    onRemoveForecast: (index: number) => void;
    onReorderForecast: (from: number, to: number) => void;
}

// Küçük saat ikonu (rozet içi)
function ClockIcon({ className }: { className?: string }) {
    return (
        <svg viewBox="0 0 24 24" className={className} fill="none">
            <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
            <path
                d="M12 7v5l3 2"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>
    );
}

// Sürükle tutamacı (≡)
function GripIcon() {
    return (
        <span className="flex flex-col gap-[3px] px-[2px]">
            <span className="h-[2px] w-[12px] rounded-full bg-current" />
            <span className="h-[2px] w-[12px] rounded-full bg-current" />
            <span className="h-[2px] w-[12px] rounded-full bg-current" />
        </span>
    );
}

// Bulut + artı ikonu (Figma node 1-445 / image 378) — Add New Weather kartı.
// currentColor ile buton metninin crimson rengini alır.
function AddWeatherIcon({ className }: { className?: string }) {
    return (
        <svg viewBox="0 0 32 32" className={className} fill="currentColor">
            <path d="M15.4221 3.3419C15.6044 3.32092 16.0434 3.32627 16.2454 3.33104C18.3612 3.381 20.4673 4.29588 21.9367 5.81117C22.3813 6.26052 22.7746 6.75775 23.1094 7.29375C23.8108 8.42146 24.355 10.0744 24.3344 11.4111C24.5423 11.416 24.7458 11.4689 24.9475 11.5163C28.8467 12.4331 31.1569 16.4135 30.0808 20.2401C29.5719 22.0252 28.3767 23.5358 26.7565 24.4417C26.4025 24.6402 26.0008 24.8544 25.6044 24.9512C25.3444 25.0146 23.4396 25.0196 23.2098 24.9469C23.0069 24.8827 22.8083 24.7365 22.6181 24.6387C22.3823 24.5177 22.1315 24.4406 21.8777 24.369C21.9919 24.2262 22.1481 24.076 22.2719 23.9308C23.6769 22.3012 22.8996 19.7107 20.8356 19.1215C20.2076 18.9421 19.2395 19.0019 18.5716 19.0018L16.0938 19.0021L12.4491 19.0014C11.7109 19.0006 10.7408 18.951 10.036 19.0805C8.41329 19.3785 7.38077 21.1142 7.76012 22.6933C7.93623 23.4262 8.35769 24.0375 8.97615 24.4662C9.16438 24.5967 9.35552 24.695 9.54423 24.8179C8.9656 24.7958 8.222 24.7875 7.64725 24.8C6.5349 24.8242 6.19363 24.7606 5.24446 24.1548C3.49604 23.0508 2.26644 21.2887 1.83357 19.2667C1.40079 17.2658 1.78713 15.1749 2.90635 13.4607C4.02485 11.719 5.80115 10.5827 7.8101 10.1488C7.82629 9.93275 7.88023 9.73575 7.93521 9.52675C8.23296 8.39479 8.79215 7.30654 9.52467 6.39617C10.5978 5.08121 12.0462 4.12456 13.6769 3.65375C14.3073 3.47535 14.774 3.4114 15.4221 3.3419Z" />
            <path d="M11.6828 24.0142C12.0935 23.9817 12.8017 24.0029 13.2383 24.0031L16.0929 24.0037L18.6412 24.0025C18.9271 24.0025 19.2778 24.0223 19.5545 24.0027C20.2789 23.9517 21.0012 24.2975 21.1578 25.0825C21.2251 25.4352 21.1474 25.8002 20.9422 26.0948C20.708 26.4329 20.3989 26.5989 20.0024 26.67C19.7537 26.6994 19.0537 26.6794 18.7672 26.6792L16.2905 26.6785L13.2468 26.6796C12.8508 26.6796 12.0377 26.7019 11.6815 26.6654C11.4712 26.6419 11.2697 26.5683 11.0937 26.4508C10.7928 26.2479 10.5868 25.9319 10.5223 25.5746C10.4566 25.2202 10.5374 24.8542 10.7465 24.5604C10.9783 24.2296 11.2972 24.0844 11.6828 24.0142Z" />
            <path d="M17.168 21.1828C17.2005 21.5935 17.1792 22.3017 17.179 22.7383L17.1784 25.5929L17.1796 28.1412C17.1796 28.4271 17.1599 28.7778 17.1794 29.0545C17.2305 29.7789 16.8846 30.5012 16.0996 30.6578C15.7469 30.7251 15.3819 30.6474 15.0874 30.4422C14.7492 30.208 14.5832 29.8989 14.5121 29.5024C14.4828 29.2537 14.5028 28.5537 14.503 28.2672L14.5036 25.7905L14.5026 22.7468C14.5026 22.3508 14.4803 21.5377 14.5167 21.1815C14.5403 20.9712 14.6138 20.7697 14.7313 20.5937C14.9342 20.2928 15.2503 20.0868 15.6076 20.0223C15.9619 19.9566 16.328 20.0374 16.6217 20.2465C16.9526 20.4783 17.0978 20.7972 17.168 21.1828Z" />
        </svg>
    );
}

// "Up Next" çizelge kartı — Figma node 1-459: [sol sürükle tutamacı]
// [hava kartı: isim + sarı saat rozeti + hava + °C + "In X"] [sağ Edit/Delete].
// @dnd-kit useSortable ile sürüklerken diğer kartlar pürüzsüz kayar.
function SortableForecastCard({
    id,
    areaName,
    entry,
    clock,
    onEdit,
    onDelete,
}: {
    id: string;
    areaName: string;
    entry: ForecastEntry;
    clock: Clock;
    onEdit: () => void;
    onDelete: () => void;
}) {
    const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
        useSortable({ id });
    const style: React.CSSProperties = {
        transform: CSS.Transform.toString(transform),
        transition,
        zIndex: isDragging ? 20 : undefined,
        opacity: isDragging ? 0.9 : 1,
    };
    // İki-adımlı silme: ilk tık onay ister (3sn), ikinci tık siler
    const [confirming, setConfirming] = useState(false);
    const confirmTimer = useRef<number | null>(null);
    const handleDeleteClick = () => {
        if (confirming) {
            if (confirmTimer.current) window.clearTimeout(confirmTimer.current);
            setConfirming(false);
            onDelete();
        } else {
            setConfirming(true);
            confirmTimer.current = window.setTimeout(() => setConfirming(false), 3000);
        }
    };
    return (
        <div ref={setNodeRef} style={style} className="flex items-center gap-[10px]">
            {/* Sürükle tutamacı — sadece buradan sürüklenir (butonlar tıklanabilir kalır) */}
            <button
                type="button"
                {...attributes}
                {...listeners}
                aria-label={t("panel.reorder")}
                className="shrink-0 cursor-grab touch-none text-white/30 transition-colors hover:text-white/60 active:cursor-grabbing"
            >
                <GripIcon />
            </button>

            {/* Hava kartı */}
            <div className="relative h-[145px] flex-1 overflow-clip rounded-[20px] border border-white/5 bg-white/10 shadow-[0px_42px_25px_0px_rgba(0,0,0,0.07),0px_19px_19px_0px_rgba(0,0,0,0.12),0px_5px_10px_0px_rgba(0,0,0,0.14)]">
                <img
                    src={tempGraph}
                    alt=""
                    className="pointer-events-none absolute bottom-0 left-[45px] h-[95px] w-[233px]"
                />
                <p className="absolute left-[15px] top-[15px] text-[16px] font-medium text-white">
                    {areaName}
                </p>
                <span className="absolute right-[11px] top-[11px] flex items-center gap-[6px] rounded-[6px] bg-[#dcb714] px-[8px] py-[6px] text-[14px] font-medium tracking-[-0.56px] text-black">
                    <ClockIcon className="size-[16px]" />
                    {formatCastTime(entry.atHour, entry.atMinute)}
                </span>
                <div className="absolute left-[15px] top-[46px] flex items-center gap-[8px]">
                    <img src={weatherIcon(entry.weather)} alt="" className="size-[32px]" />
                    <span className="text-[14px] font-medium tracking-[-0.56px] text-white [text-shadow:0px_2px_1.9px_rgba(0,0,0,0.95)]">
                        {tWeather(entry.weather)}
                    </span>
                </div>
                <p className="absolute bottom-[14px] left-[15px] bg-gradient-to-b from-white to-[#999] bg-clip-text text-[40px] font-bold tracking-[-1.6px] text-transparent">
                    {entry.temperature}°
                </p>
                <p className="absolute bottom-[16px] right-[16px] text-[16px] font-semibold tracking-[-0.64px] text-white/50">
                    {relativeCastLabel(entry, clock)}
                </p>
            </div>

            {/* Edit / Delete */}
            <div className="flex shrink-0 flex-col justify-center gap-[16px]">
                <button
                    onClick={onEdit}
                    className="relative flex size-[40px] items-center justify-center overflow-clip rounded-[14px] border-2 border-[var(--cdw-accent-dark)] bg-[var(--cdw-accent)] text-[var(--cdw-on-accent)]"
                >
                    <svg viewBox="0 0 20 20" className="size-[18px]" fill="currentColor">
                        <path d="M10.3412 5.42358C10.4181 5.43058 10.698 5.73666 10.7717 5.81042L11.4914 6.53097L13.508 8.54799C13.8491 8.88918 14.2503 9.3118 14.6017 9.63386C13.9875 10.2156 13.3647 10.8608 12.763 11.4625L9.46742 14.7588L8.21845 16.0077C7.70436 16.5209 7.03535 17.2426 6.35059 17.4941C5.51958 17.8042 4.56661 17.6839 3.6929 17.7102C3.40344 17.7029 3.10693 17.7269 2.81917 17.6968C2.51892 17.6653 2.30189 17.3899 2.2893 17.1019C2.27527 16.7807 2.28409 16.4644 2.28295 16.1476L2.28763 15.2891C2.2921 14.6887 2.29435 14.1343 2.53368 13.5697C2.83083 12.8687 3.48691 12.2874 4.02253 11.7516L5.11032 10.6641L8.61969 7.1543L9.73323 6.04119C9.91417 5.86043 10.1795 5.61076 10.3412 5.42358Z" />
                        <path d="M14.0981 2.29617C15.0119 2.16688 15.7649 2.99725 16.3442 3.58317C16.9367 4.18231 17.713 4.82906 17.7121 5.73589C17.7141 5.99926 17.6515 6.2591 17.5296 6.49262C17.2911 6.95715 16.755 7.46943 16.3807 7.84514L15.4671 8.75921C15.3821 8.66419 15.2664 8.5535 15.1748 8.46137L11.248 4.53508C11.5309 4.23074 11.8463 3.92035 12.1446 3.62983C12.7263 3.06337 13.2428 2.40914 14.0981 2.29617Z" />
                    </svg>
                    <span className="pointer-events-none absolute inset-0 rounded-[inherit] shadow-[inset_0px_4px_2px_0px_rgba(255,255,255,0.25)]" />
                </button>
                <button
                    onClick={handleDeleteClick}
                    title={confirming ? t("panel.confirm") : undefined}
                    className={`flex size-[40px] items-center justify-center rounded-[13px] border-[1.5px] transition-colors ${
                        confirming
                            ? "border-[var(--cdw-accent-dark)] bg-[var(--cdw-accent)] text-[var(--cdw-on-accent)]"
                            : "border-white/10 bg-white/10 text-white/70 hover:bg-white/20"
                    }`}
                >
                    {confirming ? (
                        <svg viewBox="0 0 24 24" className="size-[18px]" fill="none">
                            <path
                                d="M5 12l5 5L20 7"
                                stroke="currentColor"
                                strokeWidth="2"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            />
                        </svg>
                    ) : (
                        <svg viewBox="0 0 20 20" className="size-[18px]" fill="currentColor">
                            <path d="M16.3188 13.0469C16.2548 14.0913 16.2041 14.92 16.1002 15.5819C15.9935 16.2608 15.8228 16.8262 15.4814 17.3207C15.1691 17.7731 14.767 18.1549 14.3007 18.4418C13.7909 18.7555 13.2217 18.8927 12.5442 18.9583L7.43949 18.9582C6.76125 18.8924 6.19143 18.755 5.68133 18.4408C5.21469 18.1533 4.81245 17.7708 4.50023 17.3177C4.15894 16.8223 3.9888 16.2562 3.88298 15.5763C3.77978 14.9134 3.73019 14.0835 3.66768 13.0377L3.125 3.95825H16.875L16.3188 13.0469Z" />
                            <path fillRule="evenodd" clipRule="evenodd" d="M11.1221 1.06905C11.593 1.11117 12.0356 1.25488 12.4157 1.53834C12.6968 1.74798 12.892 2.0046 13.0588 2.28252C13.2134 2.54006 13.3691 2.86116 13.5456 3.22541L13.9013 3.959H17.4993C17.9596 3.959 18.3327 4.3321 18.3327 4.79233C18.3327 5.25257 17.9596 5.62566 17.4993 5.62566C12.4992 5.62566 7.49951 5.62566 2.49935 5.62566C2.03912 5.62566 1.66602 5.25257 1.66602 4.79233C1.66602 4.3321 2.03912 3.959 2.49935 3.959H6.17415L6.47065 3.30855C6.64278 2.93088 6.79437 2.59826 6.94665 2.33136C7.11091 2.04347 7.30536 1.77705 7.58986 1.5588C7.97462 1.26363 8.4261 1.11399 8.9076 1.07015C9.2701 1.03715 9.63552 1.0417 9.99935 1.04228C10.425 1.04296 10.8077 1.04093 11.1221 1.06905ZM8.00582 3.959H12.0491C11.8602 3.5695 11.7393 3.32264 11.6298 3.14025C11.4696 2.8733 11.2776 2.75629 10.9736 2.7291C10.7575 2.70977 10.4759 2.709 10.0281 2.709C9.5691 2.709 9.28018 2.7098 9.05868 2.72995C8.74693 2.75834 8.5526 2.87981 8.39427 3.1573C8.29052 3.33914 8.17757 3.58255 8.00582 3.959Z" />
                        </svg>
                    )}
                </button>
            </div>
        </div>
    );
}

const ACTION_BUTTON_CLASSES =
    "relative h-[48px] w-full overflow-clip rounded-[16px] border-2 border-[var(--cdw-accent-dark)] bg-[var(--cdw-accent)] " +
    "text-[16px] font-medium tracking-[-0.64px] text-[var(--cdw-on-accent)] transition-[filter] hover:brightness-110 " +
    "shadow-[0px_42px_25px_0px_rgba(0,0,0,0.11),0px_19px_19px_0px_rgba(0,0,0,0.19),0px_5px_10px_0px_rgba(0,0,0,0.22)]";

function ActionButton({ label, onClick }: { label: string; onClick: () => void }) {
    return (
        <button onClick={onClick} className={ACTION_BUTTON_CLASSES}>
            {label}
            <span className="pointer-events-none absolute inset-0 rounded-[inherit] shadow-[inset_0px_4px_2px_0px_rgba(255,255,255,0.25)]" />
        </button>
    );
}

// Alan kartı — hem seçili "Current Weather" kartı hem de listedeki satırlar bunu kullanır.
// Figma 1-10 / 1-402 kartı ile birebir. onClick verilirse tıklanabilir (liste) olur.
// Dinamik alanda o anki AKTİF forecast girdisinin havası/sıcaklığı gösterilir (#4).
function AreaCard({
    area,
    clock,
    onClick,
}: {
    area: WeatherArea;
    clock: Clock;
    onClick?: () => void;
}) {
    const active = area.dynamic ? activeForecast(area.forecast, clock) : null;
    const weather = active?.weather ?? area.weather;
    const temperature = active?.temperature ?? area.temperature;
    // Sağ-alt etiket: dinamikse "Up Next → <sonraki>", değilse "<Ad> Wide" (şehir) / "<Ad>" (zone)
    const next = area.dynamic ? nextForecast(area.forecast, clock) : null;
    const card = (
        <div className="relative h-[145px] w-full shrink-0 overflow-clip rounded-[20px] border border-white/5 bg-white/10 shadow-[0px_42px_25px_0px_rgba(0,0,0,0.07),0px_19px_19px_0px_rgba(0,0,0,0.12),0px_5px_10px_0px_rgba(0,0,0,0.14)] transition-colors duration-200 group-hover:border-white/15 group-hover:bg-white/[0.15]">
            <img
                src={tempGraph}
                alt=""
                className="pointer-events-none absolute bottom-0 left-[45px] h-[95px] w-[233px]"
            />
            <p className="absolute left-[15px] top-[15px] text-[16px] font-medium text-white">
                {area.name}
            </p>
            <span className="absolute right-[11px] top-[11px] rounded-[6px] bg-white px-[16px] py-[8px] text-[14px] font-medium tracking-[-0.56px] text-black">
                {area.dynamic ? t("panel.dynamic") : t("panel.static")}
            </span>
            <div className="absolute left-[15px] top-[46px] flex items-center gap-[8px]">
                <img src={weatherIcon(weather)} alt="" className="size-[32px]" />
                <p className="text-[14px] font-medium tracking-[-0.56px] text-white [text-shadow:0px_2px_1.9px_rgba(0,0,0,0.95)]">
                    {tWeather(weather)}
                </p>
            </div>
            <p className="absolute bottom-[14px] left-[15px] bg-gradient-to-b from-white to-[#999] bg-clip-text text-[40px] font-bold tracking-[-1.6px] text-transparent">
                {temperature}°
            </p>
            <p className="absolute bottom-[18px] right-[16px] whitespace-nowrap text-[13px] font-medium tracking-[-0.3px] text-white/50">
                {next
                    ? `${t("panel.upNext")} → ${tWeather(next.weather)}`
                    : area.kind === "city"
                      ? `${titleCase(area.name)} ${t("panel.wide")}`
                      : area.name}
            </p>
        </div>
    );

    if (!onClick) return card;
    return (
        <button
            onClick={onClick}
            className="group block w-full rounded-[20px] text-left outline-none transition-[transform,box-shadow] duration-200 ease-out hover:-translate-y-[2px] hover:shadow-[0px_16px_32px_-10px_rgba(0,0,0,0.45)] focus-visible:ring-2 focus-visible:ring-[rgb(var(--cdw-accent-rgb)_/_0.4)]"
        >
            {card}
        </button>
    );
}

export default function WeatherPanel({
    areas,
    selectedArea,
    clock,
    onSelectArea,
    onClearSelection,
    onOpenStaticModal,
    onChangeStaticAll,
    onToggleDynamic,
    onAddForecast,
    onEditForecast,
    onRemoveForecast,
    onReorderForecast,
}: WeatherPanelProps) {
    // Kararlı sürükle id'leri — girdi nesnesi kimliğine göre (yerel reorder nesne
    // referanslarını korur; sunucu sync yeni nesne → yeni id, sorun değil).
    const idMapRef = useRef(new WeakMap<ForecastEntry, string>());
    const idSeqRef = useRef(0);
    const entryId = (entry: ForecastEntry) => {
        let id = idMapRef.current.get(entry);
        if (!id) {
            id = `fc-${idSeqRef.current++}`;
            idMapRef.current.set(entry, id);
        }
        return id;
    };

    // Sürükleme yalnızca tutamaçtan; 5px eşiği butonların tıklanabilirliğini korur
    const sensors = useSensors(
        useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
    );

    const forecast = selectedArea?.forecast ?? [];
    const ids = forecast.map(entryId);

    const handleDragEnd = (e: DragEndEvent) => {
        const { active, over } = e;
        if (!over || active.id === over.id) return;
        const from = ids.indexOf(String(active.id));
        const to = ids.indexOf(String(over.id));
        if (from !== -1 && to !== -1) onReorderForecast(from, to);
    };

    return (
        <div className="flex w-[420px] shrink-0 flex-col gap-[16px] overflow-clip rounded-[32px] border-[1.5px] border-white/5 bg-white/5 p-[16px]">
            {selectedArea ? (
                // ── Detay görünümü ──────────────────────────────────
                <div
                    key="detail"
                    className="cdw-view-in flex min-h-0 flex-1 flex-col gap-[16px]"
                >
                    <button
                        onClick={onClearSelection}
                        className="flex items-center gap-[6px] self-start text-[14px] font-medium text-white/50 transition-colors hover:text-white"
                    >
                        <span className="text-[18px] leading-none">‹</span> {t("panel.areas")}
                    </button>

                    <AreaCard area={selectedArea} clock={clock} />

                    {/* İçerik: dinamikse çizelge, statikse placeholder */}
                    <div className="min-h-0 flex-1 overflow-y-auto">
                        {selectedArea.dynamic ? (
                            <div className="flex flex-col gap-[16px]">
                                <p className="text-[14px] font-medium text-white/30">{t("panel.upNext")}</p>
                                {forecast.length === 0 && (
                                    <p className="py-[8px] text-center text-[14px] text-white/40">
                                        {t("panel.noForecast")}
                                    </p>
                                )}
                                <DndContext
                                    sensors={sensors}
                                    collisionDetection={closestCenter}
                                    onDragEnd={handleDragEnd}
                                >
                                    <SortableContext
                                        items={ids}
                                        strategy={verticalListSortingStrategy}
                                    >
                                        <div className="flex flex-col gap-[16px]">
                                            {forecast.map((entry, i) => (
                                                <SortableForecastCard
                                                    key={ids[i]}
                                                    id={ids[i]}
                                                    areaName={selectedArea.name}
                                                    entry={entry}
                                                    clock={clock}
                                                    onEdit={() => onEditForecast(i)}
                                                    onDelete={() => onRemoveForecast(i)}
                                                />
                                            ))}
                                        </div>
                                    </SortableContext>
                                </DndContext>
                                <button
                                    onClick={onAddForecast}
                                    className="flex h-[145px] w-full flex-col items-center justify-center gap-[11px] rounded-[20px] border-2 border-[rgb(var(--cdw-accent-rgb)_/_0.45)] bg-[rgb(var(--cdw-accent-rgb)_/_0.1)] text-[16px] font-medium text-[var(--cdw-accent)] shadow-[0px_42px_25px_0px_rgba(0,0,0,0.07),0px_19px_19px_0px_rgba(0,0,0,0.12),0px_5px_10px_0px_rgba(0,0,0,0.14)] transition-colors hover:bg-[rgb(var(--cdw-accent-rgb)_/_0.16)]"
                                >
                                    <AddWeatherIcon className="size-[32px]" />
                                    {t("panel.addWeather")}
                                </button>
                            </div>
                        ) : (
                            <div className="flex h-full items-center justify-center">
                                <div className="flex w-[232px] flex-col items-center gap-[24px] opacity-20">
                                    <img src={cloudPlaceholder} alt="" className="size-[64px]" />
                                    <p className="text-center text-[16px] font-medium text-white">
                                        {t("panel.enableHint")}
                                    </p>
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Aksiyonlar: statikse Change Static + Enable Dynamic; dinamikse Disable Dynamic */}
                    <div className="flex flex-col gap-[16px]">
                        {!selectedArea.dynamic && (
                            <ActionButton label={t("panel.changeStatic")} onClick={onOpenStaticModal} />
                        )}
                        <ActionButton
                            label={
                                selectedArea.dynamic
                                    ? t("panel.disableDynamic")
                                    : t("panel.enableDynamic")
                            }
                            onClick={onToggleDynamic}
                        />
                    </div>
                </div>
            ) : (
                // ── Liste görünümü (seçim yok) — kartlar + alt "hepsine uygula" butonu
                <div key="list" className="cdw-view-in flex min-h-0 flex-1 flex-col gap-[16px]">
                    <div className="flex min-h-0 flex-1 flex-col gap-[16px] overflow-y-auto">
                        {areas.map((area) => (
                            <div key={area.id} className="cdw-card-in shrink-0">
                                <AreaCard
                                    area={area}
                                    clock={clock}
                                    onClick={() => onSelectArea(area.id)}
                                />
                            </div>
                        ))}
                        {areas.length === 0 && (
                            <div className="flex h-full items-center justify-center">
                                <p className="text-center text-[14px] text-white/30">
                                    {t("panel.noZones")}
                                </p>
                            </div>
                        )}
                    </div>
                    {areas.length > 0 && (
                        <ActionButton
                            label={t("panel.changeStaticAll")}
                            onClick={onChangeStaticAll}
                        />
                    )}
                </div>
            )}
        </div>
    );
}
