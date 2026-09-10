import { useRef, useState, type ReactNode } from "react";
import type { WeatherAreaKind, WeatherZone, ZonePoint } from "@/types";
import { polygonsOverlap } from "@/utils/geometry";
import { t } from "@/utils/locale";
import ZoneMap, { type ZoneMapHandle } from "@/components/ZoneMap";
import WindModal from "@/components/modals/WindModal";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import tooltipArrow from "@/assets/tooltip-arrow.svg";
import toolShape from "@/assets/tool-shape.svg";
import toolSelectBg from "@/assets/tool-select-bg.svg";
import toolText from "@/assets/tool-text.svg";
import toolLayers from "@/assets/tool-layers.svg";
import toolDelete from "@/assets/tool-delete.svg";
import toolUndo from "@/assets/tool-undo.svg";
import toolRedo from "@/assets/tool-redo.svg";
import toolReset from "@/assets/tool-reset.svg";
// Bu iki araç ikonu accent renkli daire zemine sahip (Figma: fill var(--fill-0, #DC143C)).
// Raw (?raw) alıp inline render ederiz; #DC143C fallback'ini tema değişkenine bağlarız —
// <img> ile CSS değişkeni çözülmez, DOM'a inline edilince çözülür.
import toolPencilRaw from "@/assets/tool-pencil.svg?raw";
import toolConfirmRaw from "@/assets/tool-confirm.svg?raw";

// Daire zemini → accent; üstteki glyph (beyaz #FEFEFE / "white") → accent üzerinde
// okunabilir kontrast rengi (oto siyah/beyaz). Böylece açık temada glyph kaybolmaz.
const themeSvg = (svg: string) =>
    svg
        .replace(/#DC143C/gi, "var(--cdw-accent)")
        .replace(/#FEFEFE/gi, "var(--cdw-on-accent)")
        .replace(/,\s*white\)/gi, ", var(--cdw-on-accent))");
const toolPencilSvg = themeSvg(toolPencilRaw);
const toolConfirmSvg = themeSvg(toolConfirmRaw);

type Tab = "forecast" | "zones";

// Araç butonu üstünde hover'da beliren bilgi baloncuğu (tasarımdaki beyaz etiket)
function ToolTip({ text }: { text: string }) {
    return (
        <div className="pointer-events-none absolute -top-[6px] left-1/2 z-[1100] flex -translate-x-1/2 -translate-y-full items-center justify-center rounded-[11px] bg-white p-[10px] opacity-0 shadow-[0px_6px_16px_0px_rgba(0,0,0,0.25)] transition-opacity duration-150 group-hover:opacity-100">
            <p className="whitespace-nowrap text-[15px] font-semibold leading-none text-black">
                {text}
            </p>
            <img
                src={tooltipArrow}
                alt=""
                className="absolute left-1/2 top-full h-[8px] w-[16px] -translate-x-1/2 -translate-y-px rotate-180"
            />
        </div>
    );
}

function ToolButton({
    icon,
    iconSvg,
    alt,
    tooltip,
    active,
    activeVariant = "ring",
    disabled,
    onClick,
    children,
}: {
    icon?: string;
    // Inline (tema uyumlu) SVG markup'ı — accent'i CSS değişkeniyle çözebilmek için.
    iconSvg?: string;
    alt: string;
    tooltip?: string;
    active?: boolean;
    // "ring": beyaz seçim halkası (araç seçimi). "dark": koyulaşır (gizle/kapat toggle'ı).
    activeVariant?: "ring" | "dark";
    disabled?: boolean;
    onClick?: () => void;
    children?: ReactNode;
}) {
    const ringActive = active && activeVariant === "ring";
    const darkActive = active && activeVariant === "dark";
    return (
        <div className="group relative">
            <button
                onClick={onClick}
                disabled={disabled}
                aria-label={alt}
                className={`relative size-[48px] rounded-full transition-transform hover:scale-105 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:scale-100 ${
                    ringActive ? "ring-[3px] ring-white" : ""
                }`}
            >
                {icon && <img src={icon} alt={alt} className="block size-full" />}
                {iconSvg && (
                    <span
                        aria-label={alt}
                        className="block size-full [&>svg]:block [&>svg]:size-full"
                        dangerouslySetInnerHTML={{ __html: iconSvg }}
                    />
                )}
                {children}
                {/* Gizle toggle'ı aktifken: koyulaşır (zone'ların gizlendiğini anlatır) */}
                {darkActive && (
                    <span className="pointer-events-none absolute inset-0 rounded-full bg-black/60 ring-1 ring-inset ring-white/15" />
                )}
            </button>
            {tooltip && <ToolTip text={tooltip} />}
        </div>
    );
}

// Forecast sekmesindeki yuvarlak katman butonu (Zone Base / City Wide)
function LayerButton({
    active,
    onClick,
    title,
    children,
}: {
    active: boolean;
    onClick: () => void;
    title: string;
    children: React.ReactNode;
}) {
    return (
        <button
            onClick={onClick}
            title={title}
            className={`flex size-[48px] items-center justify-center rounded-full transition-colors ${
                active
                    ? "bg-[var(--cdw-accent)] text-[var(--cdw-on-accent)]"
                    : "bg-black/40 text-white hover:bg-black/60"
            }`}
        >
            {children}
        </button>
    );
}

interface MapPanelProps {
    zones: WeatherZone[];
    layer: WeatherAreaKind;
    onLayerChange: (layer: WeatherAreaKind) => void;
    onZoneCreated: (points: ZonePoint[]) => void;
    onZoneClick: (zone: WeatherZone) => void;
    selectedId?: number | null;
    // Global rüzgar (Forecast'te bölge şeritleri için)
    windDirection?: number;
    windSpeed?: number;
    windAuto?: boolean;
    onSetWind: (data: { auto: true } | { direction: number; speed: number }) => void;
    // Rename (T) / Delete — seçili zone varsa aktif
    canRename: boolean;
    onRequestRename: () => void;
    onRequestDelete: () => void;
    // Yeni zone çizimine başlarken (Draw/Box) önceki seçimi temizle
    onClearSelection: () => void;
}

export default function MapPanel({
    zones,
    layer,
    onLayerChange,
    onZoneCreated,
    onZoneClick,
    selectedId,
    windDirection,
    windSpeed,
    windAuto,
    onSetWind,
    canRename,
    onRequestRename,
    onRequestDelete,
    onClearSelection,
}: MapPanelProps) {
    // Varsayılan: Forecast sekmesi (görüntüleme). Çizim ancak Zone Editor'de.
    const [tab, setTab] = useState<Tab>("forecast");
    const [drawing, setDrawing] = useState(false);
    // Shape modu: kenarları yay yapmak için (Draw ile karşılıklı dışlar)
    const [shaping, setShaping] = useState(false);
    // Dolma-kalem (tool-shape.svg) aracı — davranış henüz tanımlanmadı (placeholder)
    const [boxMode, setBoxMode] = useState(false);
    // ZoneMap'teki aktif taslağın nokta sayısı (taslak araçlarını göster + Box'ı gate'le)
    const [draftCount, setDraftCount] = useState(0);
    // Çizilen hariç diğer zone'ları gizle (Hide/Show toggle)
    const [hideOthers, setHideOthers] = useState(false);
    // Çakışma uyarısı (kısa süreli toast)
    const [drawError, setDrawError] = useState<string | null>(null);
    // Rüzgar kontrol modalı
    const [windOpen, setWindOpen] = useState(false);
    // Zone silme onayı — ekran ortasında pop-up (yanlış-tık koruması)
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
    // Bölge editörü yardım balonu (sağ alt "i")
    const [infoOpen, setInfoOpen] = useState(false);
    const mapRef = useRef<ZoneMapHandle>(null);

    const switchTab = (t: Tab) => {
        setTab(t);
        setDrawing(false);
        setShaping(false);
        setBoxMode(false);
        mapRef.current?.clearDraft(); // sekme değişince bekleyen taslağı at
        // Zone Editor → zone katmanı; Forecast → City Wide (varsayılan)
        onLayerChange(t === "zones" ? "zone" : "city");
    };

    const confirmDraft = () => {
        // Taslağı temizlemeden al — çakışma varsa korunmalı ki kullanıcı düzeltsin
        const points = mapRef.current?.peekDraft();
        if (!points) return;
        // Yeni zone mevcut zone'larla üst üste gelemez
        const clash = zones.some(
            (z) => z.points.length >= 3 && polygonsOverlap(points, z.points)
        );
        if (clash) {
            setDrawError(t("map.overlap"));
            window.setTimeout(() => setDrawError(null), 3000);
            return;
        }
        mapRef.current?.clearDraft();
        setDrawing(false);
        setShaping(false);
        setBoxMode(false);
        onZoneCreated(points);
    };

    const isEditor = tab === "zones";
    // Zone Editor'de araçlar (Draw/Shape/Box/Hide) hep açık; Rename + Delete yalnız
    // bir zone seçiliyken animasyonla belirir. Taslak araçları (undo/redo/reset/
    // confirm) bir mod aktifken YA DA ortada bir taslak varken görünür (mod'u
    // kapatınca taslak dururken kaybolmasınlar).
    const draftActive = drawing || shaping || boxMode || draftCount > 0;
    // Box yeni dikdörtgen ancak boş taslakta oluşturur; taslak varken tıklanamaz
    const boxDisabled = draftCount > 0 && !boxMode;
    // Shape yalnız 3+ noktalı taslakta iş yapar; öncesinde tıklanamaz
    const shapeDisabled = draftCount < 3;
    const revealCls = (open: boolean) =>
        `transition-all duration-200 ease-out ${
            open ? "opacity-100 translate-x-0" : "pointer-events-none -translate-x-[8px] opacity-0"
        }`;
    const fadeCls = (open: boolean) =>
        `transition-opacity duration-200 ${open ? "opacity-100" : "pointer-events-none opacity-0"}`;

    return (
        <div className="relative flex-1 overflow-clip rounded-[32px] border-[1.5px] border-white/5 bg-[#84bcf0]">
            <ZoneMap
                ref={mapRef}
                zones={hideOthers ? [] : zones}
                drawing={drawing}
                shaping={shaping}
                boxMode={boxMode}
                onDraftChange={setDraftCount}
                selectedId={selectedId}
                showWeather={!isEditor}
                showRibbons={!isEditor && layer === "city"}
                windDirection={windDirection}
                windSpeed={6}
                onZoneClick={onZoneClick}
            />

            {/* Harita üstü karartma — tasarımdaki black/20 overlay */}
            <div className="pointer-events-none absolute inset-0 z-[900] bg-black/20" />

            {/* Çakışma uyarısı (üst-orta, kısa süreli) */}
            {drawError && (
                <div className="absolute left-1/2 top-[84px] z-[1100] -translate-x-1/2 rounded-[12px] border border-white/15 bg-[rgb(var(--cdw-accent-rgb)_/_0.95)] px-[16px] py-[10px] text-[14px] font-medium text-[var(--cdw-on-accent)] shadow-[0px_10px_25px_0px_rgba(0,0,0,0.35)]">
                    {drawError}
                </div>
            )}

            {/* Sekmeler */}
            <div className="absolute left-[22px] top-[22px] z-[1000] flex items-center gap-[8px]">
                <button
                    onClick={() => switchTab("zones")}
                    className={`relative flex h-[40px] items-center justify-center rounded-[31px] px-[20px] text-[16px] font-semibold leading-none transition-all duration-200 ${
                        isEditor
                            ? "border border-white/10 bg-white/75 text-black shadow-[inset_0px_0px_5.5px_0px_rgba(255,255,255,0.25)]"
                            : "bg-black/40 text-white"
                    }`}
                >
                    {t("map.zoneEditor")}
                </button>
                <button
                    onClick={() => switchTab("forecast")}
                    className={`relative flex h-[40px] items-center justify-center rounded-[31px] px-[20px] text-[16px] font-semibold leading-none transition-all duration-200 ${
                        !isEditor
                            ? "border border-white/10 bg-white/75 text-black shadow-[inset_0px_0px_5.5px_0px_rgba(255,255,255,0.25)]"
                            : "bg-black/40 text-white"
                    }`}
                >
                    {t("map.forecast")}
                </button>
            </div>

            {isEditor ? (
                <div key="editor" className="cdw-controls-in">
                    {/* Çizim araçları (sol alt) — başta yalnız Draw, moda girince açılır */}
                    <div className="absolute bottom-[25.5px] left-[28.5px] z-[1000] flex items-center gap-[8px]">
                        <ToolButton
                            iconSvg={toolPencilSvg}
                            alt={t("map.tools.drawZone")}
                            tooltip={t("map.draw")}
                            active={drawing}
                            onClick={() => {
                                setDrawing((d) => !d);
                                setShaping(false);
                                setBoxMode(false);
                                onClearSelection(); // yeni çizim: önceki seçimi bırak
                            }}
                        />
                        {/* Şekil (dolma-kalem) — box hatlarına eğim/kavis ver; taslak yokken tıklanamaz */}
                        <ToolButton
                            icon={toolShape}
                            alt={t("map.tools.shape")}
                            tooltip={t("map.tools.shape")}
                            active={shaping}
                            disabled={shapeDisabled}
                            onClick={() => {
                                setShaping((s) => !s);
                                setDrawing(false);
                                setBoxMode(false);
                            }}
                        />
                        {/* Box (kesikli kare) — hazır dikdörtgen aracı; taslak varken tıklanamaz */}
                        <ToolButton
                            alt={t("map.tools.box")}
                            tooltip={t("map.tools.box")}
                            active={boxMode}
                            disabled={boxDisabled}
                            onClick={() => {
                                setBoxMode((b) => !b);
                                setDrawing(false);
                                setShaping(false);
                                onClearSelection(); // yeni çizim: önceki seçimi bırak
                            }}
                        >
                            <img src={toolSelectBg} alt="" className="block size-full" />
                            <svg
                                className="absolute left-1/2 top-1/2 size-[24px] -translate-x-1/2 -translate-y-1/2"
                                viewBox="0 0 24 24"
                                fill="none"
                            >
                                <rect
                                    x="3"
                                    y="3"
                                    width="18"
                                    height="18"
                                    rx="3"
                                    stroke="white"
                                    strokeWidth="2"
                                    strokeDasharray="4 3.4"
                                    strokeLinecap="round"
                                />
                            </svg>
                        </ToolButton>
                        {/* Diğerlerini gizle */}
                        <ToolButton
                            icon={toolLayers}
                            alt={t("map.tools.hide")}
                            tooltip={t("map.tools.hide")}
                            active={hideOthers}
                            activeVariant="dark"
                            onClick={() => setHideOthers((h) => !h)}
                        />
                        {/* Adlandır — yalnız zone seçiliyken belirir */}
                        <div className={revealCls(canRename)}>
                            <ToolButton
                                icon={toolText}
                                alt={t("map.tools.rename")}
                                tooltip={t("map.tools.rename")}
                                disabled={!canRename}
                                onClick={onRequestRename}
                            />
                        </div>
                        {/* Sil (tool-delete.svg) — yalnız zone seçiliyken belirir; ortada pop-up onay */}
                        <div className={revealCls(canRename)} style={{ transitionDelay: canRename ? "60ms" : "0ms" }}>
                            <ToolButton
                                icon={toolDelete}
                                alt={t("map.tools.delete")}
                                tooltip={t("map.tools.delete")}
                                disabled={!canRename}
                                onClick={() => setDeleteDialogOpen(true)}
                            />
                        </div>
                    </div>

                    {/* Undo / Redo (sağ orta, dikey) — yalnız taslak modunda */}
                    <div
                        className={`absolute right-[26px] top-1/2 z-[1000] flex -translate-y-1/2 flex-col gap-[16px] ${fadeCls(
                            draftActive
                        )}`}
                    >
                        <ToolButton
                            icon={toolUndo}
                            alt={t("map.tools.undo")}
                            tooltip={t("map.tools.undo")}
                            onClick={() => mapRef.current?.undoPoint()}
                        />
                        <ToolButton
                            icon={toolRedo}
                            alt={t("map.tools.redo")}
                            tooltip={t("map.tools.redo")}
                            onClick={() => mapRef.current?.redoPoint()}
                        />
                    </div>

                    {/* Reset / Confirm (sağ alt) — yalnız taslak modunda */}
                    <div
                        className={`absolute bottom-[25.5px] right-[28.5px] z-[1000] flex items-center gap-[8px] ${fadeCls(
                            draftActive
                        )}`}
                    >
                        <ToolButton
                            icon={toolReset}
                            alt={t("map.tools.resetDraft")}
                            tooltip={t("map.reset")}
                            onClick={() => mapRef.current?.clearDraft()}
                        />
                        <ToolButton
                            iconSvg={toolConfirmSvg}
                            alt={t("map.tools.confirm")}
                            tooltip={t("map.tools.confirm")}
                            onClick={confirmDraft}
                        />
                    </div>

                    {/* Info / yardım (sağ üst) */}
                    <button
                        onClick={() => setInfoOpen((o) => !o)}
                        aria-label={t("map.info.title")}
                        className={`absolute right-[22px] top-[22px] z-[1100] flex size-[48px] items-center justify-center rounded-full border-[1.5px] transition-colors ${
                            infoOpen
                                ? "border-white/25 bg-white/20 text-white"
                                : "border-white/10 bg-black/40 text-white/70 hover:bg-black/55"
                        }`}
                    >
                        <svg
                            viewBox="0 0 24 24"
                            className="size-[22px]"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="2"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <circle cx="12" cy="12" r="9" />
                            <path d="M12 11v5" />
                            <path d="M12 7.5h.01" />
                        </svg>
                    </button>

                    {/* Info balonu — sağ üstten aşağı açılır, tıkla-dışarı ile kapanır */}
                    {infoOpen && (
                        <>
                            <div
                                className="absolute inset-0 z-[1090]"
                                onClick={() => setInfoOpen(false)}
                            />
                            <div className="cdw-card-in absolute right-[22px] top-[80px] z-[1100] w-[320px] rounded-[16px] border border-white/10 bg-[#1a1a1a] p-[18px] shadow-[0px_18px_45px_rgba(0,0,0,0.55)]">
                                <p className="mb-[12px] text-[15px] font-semibold tracking-[-0.4px] text-white">
                                    {t("map.info.title")}
                                </p>
                                <ul className="flex flex-col gap-[9px] text-[13px] leading-[1.45] text-white/60">
                                    {[
                                        "map.info.draw",
                                        "map.info.box",
                                        "map.info.move",
                                        "map.info.addPoint",
                                        "map.info.curve",
                                        "map.info.confirm",
                                    ].map((k) => (
                                        <li key={k} className="flex gap-[8px]">
                                            <span className="text-[var(--cdw-accent)]">•</span>
                                            <span>{t(k)}</span>
                                        </li>
                                    ))}
                                </ul>
                            </div>
                        </>
                    )}

                    {/* Başlangıç ipucu (Figma Frame 35065) — taslak yokken alt-orta.
                        Ortalama transform'suz (flex) yapılır ki cdw-card-in'in
                        translateY animasyonu -translate-x'i ezmesin. */}
                    {draftCount === 0 && (
                        <div className="pointer-events-none absolute inset-x-0 bottom-[34px] z-[1000] flex justify-center">
                            <div className="cdw-card-in flex items-center gap-[9px] whitespace-nowrap rounded-full border border-white/10 bg-black/70 px-[16px] py-[9px] text-[14px] font-medium text-white/90 shadow-[0px_8px_20px_rgba(0,0,0,0.35)]">
                                <span className="flex size-[18px] shrink-0 items-center justify-center rounded-full bg-[#f5c518] text-[12px] font-bold leading-none text-black">
                                    i
                                </span>
                                {t("map.drawHint")}
                            </div>
                        </div>
                    )}
                </div>
            ) : (
                <div key="forecast" className="cdw-controls-in">
                    {/* Katman geçişi: Zone Base / City Wide (sol alt) */}
                    <div className="absolute bottom-[25.5px] left-[28.5px] z-[1000] flex items-center gap-[8px]">
                        <LayerButton
                            active={layer === "zone"}
                            onClick={() => onLayerChange("zone")}
                            title={t("map.zoneBase")}
                        >
                            <svg viewBox="0 0 24 24" className="size-[22px]" fill="currentColor">
                                <path d="M11.4994 1.63152C11.6228 1.6187 11.9224 1.62145 12.0541 1.62188C13.5617 1.63657 15.0327 2.08801 16.289 2.92154C18.0238 4.07026 19.2274 5.86473 19.6321 7.9056C20.4226 11.9637 17.3634 15.027 14.671 17.5628C13.9495 18.2425 13.4718 18.8869 12.4569 19.0844C12.4361 19.091 12.2733 19.1139 12.2441 19.1166C11.572 19.1772 10.8766 18.9652 10.3576 18.5325C10.1864 18.3874 10.0236 18.2325 9.86202 18.0755C7.51587 15.7958 4.63991 13.3137 4.27582 9.84785C4.07557 7.94168 4.78601 5.95013 5.96762 4.48821C7.02979 3.19321 8.47837 2.27198 10.1016 1.85921C10.6049 1.73198 10.9901 1.6852 11.4994 1.63152ZM12.2263 12.6051C14.0114 12.479 15.3563 10.9295 15.2299 9.14438C15.1034 7.35926 13.5536 6.01473 11.7685 6.14149C9.98393 6.26823 8.63985 7.81751 8.76624 9.60213C8.89263 11.3868 10.4416 12.7311 12.2263 12.6051Z" />
                                <path d="M3.8682 15.3781C4.0761 15.36 4.26059 15.3894 4.44902 15.4819C4.8109 15.6632 5.02759 16.045 4.99768 16.4486C4.97434 16.7377 4.82098 17.0271 4.71502 17.2942C4.52145 17.7824 3.87096 19.2889 4.04387 19.7747C4.10413 19.9442 4.22284 20.0821 4.38573 20.1586C4.74177 20.326 5.23615 20.3285 5.62423 20.3478C6.43027 20.388 7.24498 20.3713 8.0522 20.3714L11.8355 20.3716L15.4577 20.3714L17.1637 20.3646C17.7639 20.363 18.9639 20.3963 19.4937 20.2028C19.681 20.1344 19.8398 20.02 19.9239 19.8339C20.1774 19.2735 19.3321 17.4489 19.1135 16.8744C18.9914 16.5533 18.936 16.28 19.0848 15.955C19.201 15.701 19.3934 15.5262 19.6562 15.4314C19.9115 15.3393 20.189 15.3592 20.4335 15.4747C20.5853 15.5459 20.7156 15.656 20.8112 15.7935C21.0159 16.0835 21.4245 17.2557 21.559 17.6296C21.6598 17.8571 21.8317 18.4314 21.8912 18.6883C22.0812 19.5077 22.0431 20.2416 21.5903 20.9689C21.1885 21.6141 20.5532 22.0505 19.8117 22.2019C18.7046 22.428 17.3723 22.3764 16.2365 22.3766L12.0792 22.3769L7.80248 22.3766C6.77984 22.3766 5.81029 22.3922 4.78326 22.2999C3.46588 22.1816 2.39573 21.4963 2.06512 20.1591C1.79249 19.0564 2.36774 17.8439 2.73284 16.8256C2.85251 16.4917 3.00404 16.1141 3.16974 15.8011C3.31496 15.5559 3.60446 15.4357 3.8682 15.3781Z" />
                            </svg>
                        </LayerButton>
                        <LayerButton
                            active={layer === "city"}
                            onClick={() => onLayerChange("city")}
                            title={t("map.cityWide")}
                        >
                            <svg viewBox="0 0 24 24" className="size-[22px]" fill="currentColor">
                                <path d="M20.4045 3.13065C20.7865 3.09227 21.1701 3.14466 21.5184 3.30662C22.4655 3.74702 22.6726 4.76076 22.7227 5.70127C22.7643 6.48237 22.7534 7.26438 22.7535 8.05116L22.7537 11.6545L22.7534 14.7992C22.7534 15.42 22.759 16.0288 22.7315 16.6488C22.6543 18.3847 21.6737 18.8869 20.2459 19.5068L19.032 20.0265C18.5866 20.2165 17.9829 20.4974 17.5388 20.656C16.9593 20.9344 16.3565 21.0943 15.7451 21.2624C15.7551 20.9341 15.7363 20.5038 15.7363 20.1635L15.7365 17.4441V9.12809L15.7363 6.27435L15.7366 5.46738C15.737 5.30029 15.7321 5.06387 15.7596 4.90379C15.839 4.82376 16.4018 4.59584 16.5413 4.54226C17.761 4.07415 19.1079 3.31048 20.4045 3.13065Z" />
                                <path d="M7.20923 2.78784L7.23793 2.79575C7.25346 2.82511 7.25112 2.8317 7.25146 2.86434L7.25288 6.16084L7.2526 12.4605L7.25301 16.7055C7.25329 17.4452 7.26926 18.2483 7.25027 18.9809C6.78509 19.1091 6.29271 19.3192 5.82348 19.4572C4.51482 19.8417 3.02355 20.5603 1.88473 19.423C1.41869 18.8592 1.29665 18.1786 1.26248 17.4661C1.22613 16.7081 1.23564 15.9384 1.23538 15.1793L1.23532 11.6292L1.23598 8.88123C1.23601 7.95219 1.14467 6.71465 1.60024 5.88475C2.05285 5.06022 3.13845 4.61425 3.94859 4.20487C4.77568 3.78695 5.63641 3.35798 6.49707 3.01237C6.71096 2.92603 6.98607 2.85601 7.20923 2.78784Z" />
                                <path d="M8.75645 2.74561C8.99236 2.8024 9.21366 2.83453 9.4465 2.91204C11.0823 3.45668 12.6498 4.24809 14.2503 4.87946C14.2705 6.21264 14.253 7.58492 14.2529 8.9215L14.2529 16.671L14.2519 19.9184L14.2555 20.768C14.2561 20.8859 14.2618 21.1616 14.2438 21.2635C14.0883 21.2062 13.9276 21.1819 13.772 21.1357C13.5946 21.0827 13.3929 21.0216 13.2198 20.9559C12.3781 20.6368 11.5464 20.2701 10.7175 19.9184L9.47469 19.3899C9.2283 19.2846 8.99572 19.1943 8.75524 19.0735C8.72158 18.6568 8.7351 18.1169 8.73514 17.691L8.73569 15.4595L8.73619 8.44739L8.73617 4.42507L8.73508 3.28317C8.73594 3.17068 8.73552 2.84668 8.75645 2.74561Z" />
                            </svg>
                        </LayerButton>
                    </div>

                    {/* Change Direction (sağ alt) — GİZLENDİ (butonu görmüyoruz), kodu
                        korunuyor; rüzgar şeritleri sabit hız 6 gibi davranır
                        (aşağıda ZoneMap windSpeed={6}). Tekrar açmak için false → true. */}
                    {false && (
                        <button
                            onClick={() => setWindOpen(true)}
                            title={t("map.changeDirection")}
                            className="absolute bottom-[25.5px] right-[28.5px] z-[1000] flex size-[48px] items-center justify-center rounded-full bg-black/40 text-white transition-colors hover:bg-black/60"
                        >
                            <svg viewBox="0 0 24 24" className="size-[22px]" fill="none">
                                <path
                                    d="M12 19V5M6 11l6-6 6 6"
                                    stroke="currentColor"
                                    strokeWidth="2"
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                />
                            </svg>
                        </button>
                    )}
                </div>
            )}

            {windOpen && (
                <WindModal
                    direction={windDirection ?? 0}
                    speed={windSpeed ?? 0}
                    auto={windAuto ?? true}
                    onClose={() => setWindOpen(false)}
                    onApply={(data) => {
                        onSetWind(data);
                        setWindOpen(false);
                    }}
                />
            )}

            {deleteDialogOpen && (
                <ConfirmDialog
                    title={t("modals.deleteZoneTitle")}
                    message={t("modals.deleteZoneMessage")}
                    confirmLabel={t("modals.deleteCta")}
                    cancelLabel={t("modals.cancel")}
                    onCancel={() => setDeleteDialogOpen(false)}
                    onConfirm={() => {
                        onRequestDelete();
                        setDeleteDialogOpen(false);
                    }}
                />
            )}
        </div>
    );
}
