import { useCallback, useEffect, useMemo, useState } from "react";
import { useNuiEvent } from "@/hooks/useNuiEvent";
import { fetchNui, IS_BROWSER } from "@/utils/nui";
import { useUiScale } from "@/hooks/useUiScale";
import { DEFAULT_CITIES } from "@/utils/zones";
import { activeForecast } from "@/utils/weather";
import { setLocale, t } from "@/utils/locale";
import { setConfig } from "@/utils/config";
import { toast } from "@/utils/toast";
import type {
    ForecastEntry,
    WeatherArea,
    WeatherAreaKind,
    WeatherState,
    WeatherType,
    ZonePoint,
} from "@/types";
import Header from "@/components/Header";
import Toast from "@/components/ui/Toast";
import MapPanel from "@/components/MapPanel";
import WeatherPanel from "@/components/WeatherPanel";
import TempOverlay from "@/components/TempOverlay";
import ChangeStaticWeatherModal from "@/components/modals/ChangeStaticWeatherModal";
import CreateZoneModal, {
    type CreateZoneData,
} from "@/components/modals/CreateZoneModal";
import RenameZoneModal from "@/components/modals/RenameZoneModal";
import AddWeatherModal from "@/components/modals/AddWeatherModal";
import EditWeatherModal from "@/components/modals/EditWeatherModal";

export default function App() {
    // Tarayıcıda geliştirme sırasında panel direkt açık gelsin
    const [visible, setVisible] = useState(IS_BROWSER);
    const [state, setState] = useState<WeatherState | null>(null);
    // Tüm hava alanları (4 hazır şehir + çizilen zone'lar)
    const [areas, setAreas] = useState<WeatherArea[]>(DEFAULT_CITIES);
    // Harita/liste düzenleme katmanı: City Wide (şehirler) ↔ Zone Base (zone'lar)
    const [layer, setLayer] = useState<WeatherAreaKind>("city");
    const [selectedAreaId, setSelectedAreaId] = useState<number | null>(null);
    const [staticModalOpen, setStaticModalOpen] = useState(false);
    // "Change Static Weather For All" — aktif katmandaki tüm alanlara uygula
    const [staticAllOpen, setStaticAllOpen] = useState(false);
    const [renameOpen, setRenameOpen] = useState(false);
    const [addForecastOpen, setAddForecastOpen] = useState(false);
    const [editForecastIndex, setEditForecastIndex] = useState<number | null>(null);
    // Çizim onaylandığında bekleyen zone noktaları — doluysa Create Zone modalı açılır
    const [pendingPoints, setPendingPoints] = useState<ZonePoint[] | null>(null);
    // Locale yüklenince yeniden render tetiklemek için (t() modül değişkeni okur)
    const [, setLocaleTick] = useState(0);
    const scale = useUiScale();

    const visibleAreas = useMemo(
        () => areas.filter((a) => a.kind === layer),
        [areas, layer]
    );
    const selectedArea = areas.find((a) => a.id === selectedAreaId) ?? null;

    // Harita için: dinamik alanların hava/sıcaklığını o anki AKTİF forecast
    // girdisine çöz — böylece harita üzerindeki hava ikonu (ve rüzgar şeridi rengi)
    // dinamik modda saate göre güncellenir (sağ paneldeki kartla aynı mantık).
    const mapAreas = useMemo(
        () =>
            visibleAreas.map((a) => {
                if (!a.dynamic) return a;
                const active = activeForecast(a.forecast, state?.clock);
                return active
                    ? { ...a, weather: active.weather, temperature: active.temperature }
                    : a;
            }),
        [visibleAreas, state?.clock]
    );

    const refreshState = useCallback(async () => {
        const data = await fetchNui<WeatherState>("getState");
        if (data?.currentWeather) setState(data);
    }, []);

    const refreshAreas = useCallback(async () => {
        const data = await fetchNui<WeatherArea[]>("getAreas");
        if (Array.isArray(data) && data.length > 0) setAreas(data);
    }, []);

    // Panel her açıldığında hem state hem alanları tazele (mount = resource start
    // olabilir, o an backend state'i henüz gelmemiş olur)
    useNuiEvent<boolean>("setVisible", (show) => {
        setVisible(show);
        if (show) {
            refreshState();
            refreshAreas();
        }
    });
    useNuiEvent<WeatherState>("updateState", setState);
    // Server otoriter alanları push eder (her cdw:sync) → optimistic drift'i düzeltir,
    // çoklu-admin senkron. Boş/geçersizse yok say.
    useNuiEvent<WeatherArea[]>("updateAreas", (data) => {
        if (Array.isArray(data) && data.length > 0) setAreas(data);
    });

    useEffect(() => {
        if (IS_BROWSER) refreshState();
        refreshAreas();
    }, [refreshState, refreshAreas]);

    // Locale + config'i bir kez çek (oturum başına sabit). Boş dönerse varsayılan kalır.
    useEffect(() => {
        fetchNui<Record<string, unknown>>("getLocale").then((loc) => {
            setLocale(loc);
            setLocaleTick((n) => n + 1); // fetched locale ile yeniden render
        });
        fetchNui<Record<string, unknown>>("getConfig").then((cfg) => {
            setConfig(cfg);
            setLocaleTick((n) => n + 1); // saat formatı uygulansın
        });
    }, []);

    const close = useCallback(() => {
        setVisible(false);
        fetchNui("close");
    }, []);

    useEffect(() => {
        const onKey = (e: KeyboardEvent) => {
            if (e.key === "Escape" && visible) close();
        };
        window.addEventListener("keydown", onKey);
        return () => window.removeEventListener("keydown", onKey);
    }, [visible, close]);

    // Seçili alana statik hava + sıcaklık ata
    const setAreaWeather = (id: number, weather: WeatherType, temperature: number) => {
        setAreas((prev) =>
            prev.map((a) => (a.id === id ? { ...a, weather, temperature, dynamic: false } : a))
        );
        const area = areas.find((a) => a.id === id);
        fetchNui("setWeather", { areaId: id, kind: area?.kind, weather, temperature });
        toast(t("toast.weatherSet"));
    };

    // Aktif katmandaki (şehir/zone) TÜM alanları tek statik havaya çek (dinamik → static)
    const setAllWeather = (weather: WeatherType, temperature: number) => {
        setAreas((prev) =>
            prev.map((a) =>
                a.kind === layer ? { ...a, weather, temperature, dynamic: false } : a
            )
        );
        fetchNui("setWeatherAll", { kind: layer, weather, temperature });
        toast(t("toast.weatherAllSet"));
        setStaticAllOpen(false);
    };

    // Seçili alanın dinamik modunu aç/kapat
    const toggleAreaDynamic = () => {
        if (!selectedArea) return;
        const enabled = !selectedArea.dynamic;
        setAreas((prev) =>
            prev.map((a) => (a.id === selectedArea.id ? { ...a, dynamic: enabled } : a))
        );
        fetchNui("toggleDynamic", { areaId: selectedArea.id, kind: selectedArea.kind, enabled });
        toast(t(enabled ? "toast.dynamicOn" : "toast.dynamicOff"));
    };

    // Rüzgar: manuel ayar ({direction,speed}) veya otomatik ({auto:true})
    const setWind = (data: { auto: true } | { direction: number; speed: number }) => {
        fetchNui("setWind", data);
        toast(t("auto" in data ? "toast.windAuto" : "toast.windSet"));
    };

    // ── Forecast (dinamik çizelge) CRUD — seçili alan üzerinde ──────
    // Liste SAATE GÖRE sıralı tutulur: ekleme/düzenlemede girdi doğru zaman
    // aralığına yerleşir (en alta değil). Sürükle-bırak (reorderForecast) iki
    // havanın saatlerini takas eder; çıktısı zaten sıralı olduğu için bozulmaz.
    // Server tarafı da aynı sıralamayı uygular (otoriter).
    const byTime = (a: ForecastEntry, b: ForecastEntry) =>
        a.atHour * 60 + a.atMinute - (b.atHour * 60 + b.atMinute);

    const updateForecast = (fn: (list: ForecastEntry[]) => ForecastEntry[]) => {
        if (!selectedArea) return;
        setAreas((prev) =>
            prev.map((a) =>
                a.id === selectedArea.id ? { ...a, forecast: fn(a.forecast) } : a
            )
        );
    };

    const addForecast = (entry: ForecastEntry) => {
        if (!selectedArea) return;
        updateForecast((list) => [...list, entry].sort(byTime));
        fetchNui("addForecastEntry", {
            areaId: selectedArea.id,
            kind: selectedArea.kind,
            entry,
        });
        setAddForecastOpen(false);
        toast(t("toast.forecastAdded"));
    };

    const saveForecast = (index: number, entry: ForecastEntry) => {
        if (!selectedArea) return;
        updateForecast((list) =>
            list.map((e, i) => (i === index ? entry : e)).sort(byTime)
        );
        fetchNui("editForecastEntry", { areaId: selectedArea.id, index, entry });
        setEditForecastIndex(null);
        toast(t("toast.forecastUpdated"));
    };

    const removeForecast = (index: number) => {
        if (!selectedArea) return;
        updateForecast((list) => list.filter((_, i) => i !== index));
        fetchNui("removeForecastEntry", { areaId: selectedArea.id, index });
        toast(t("toast.forecastRemoved"));
    };

    // Sürükle-bırak ile forecast kartlarını yeniden sırala.
    // Saatler KRONOLOJİK SLOT olarak sabit kalır: mevcut saatler artan sıralanıp
    // pozisyonlara atanır → sürükleme "hangi hava ne zaman" atamasını değiştirir,
    // liste hep kronolojik kalır. Tüm forecast dizisi server'a set edilir (#3).
    const reorderForecast = (from: number, to: number) => {
        if (!selectedArea || from === to) return;
        const list = selectedArea.forecast;
        if (from < 0 || from >= list.length || to < 0 || to >= list.length) return;
        const next = [...list];
        const [moved] = next.splice(from, 1);
        if (!moved) return;
        next.splice(to, 0, moved);
        const slots = list
            .map((e) => e.atHour * 60 + e.atMinute)
            .sort((a, b) => a - b);
        const retimed: ForecastEntry[] = next.map((e, i) => ({
            ...e,
            atHour: Math.floor(slots[i] / 60),
            atMinute: slots[i] % 60,
        }));
        setAreas((prev) =>
            prev.map((a) =>
                a.id === selectedArea.id ? { ...a, forecast: retimed } : a
            )
        );
        fetchNui("setForecast", {
            areaId: selectedArea.id,
            kind: selectedArea.kind,
            forecast: retimed,
        });
    };

    // Çizim onaylanınca Create Zone modalını aç (noktaları beklet)
    const handleZoneCreated = useCallback(
        (points: ZonePoint[]) => setPendingPoints(points),
        []
    );
    // Stabil referans — ZoneMap redraw effect'inin deps'inde; her render'da yeni
    // fonksiyon olsaydı harita 2sn'de bir gereksiz yeniden çizilirdi (perf).
    const handleZoneClick = useCallback(
        (zone: { id: number }) => setSelectedAreaId(zone.id),
        []
    );

    // Modal onaylanınca zone'u oluştur, Zone Base katmanına geç ve seç
    const createZoneFromModal = (data: CreateZoneData) => {
        if (!pendingPoints) return;
        const zone: WeatherArea = {
            id: Math.max(0, ...areas.map((a) => a.id)) + 1,
            kind: "zone",
            name: data.name,
            color: data.color,
            labelColor: data.labelColor,
            points: pendingPoints,
            weather: data.weather,
            temperature: data.temperature,
            dynamic: false,
            forecast: [],
        };
        setAreas((prev) => [...prev, zone]);
        setLayer("zone");
        setSelectedAreaId(zone.id);
        setPendingPoints(null);
        fetchNui("createZone", { zone });
        toast(t("toast.zoneCreated"));
    };

    // Seçili zone'u sil (yalnız kind=='zone')
    const deleteZone = () => {
        if (!selectedArea || selectedArea.kind !== "zone") return;
        const id = selectedArea.id;
        setAreas((prev) => prev.filter((a) => a.id !== id));
        setSelectedAreaId(null);
        fetchNui("deleteZone", { areaId: id });
        toast(t("toast.zoneDeleted"));
    };

    const zoneCount = areas.filter((a) => a.kind === "zone").length;

    // Sıcaklık overlay'i panelden BAĞIMSIZ, her zaman render edilir (soğuk frost).
    // Panel kapalıyken de görünür; bu yüzden erken return'den ÖNCE.
    if (!visible) return <TempOverlay panelOpen={false} />;

    return (
        <>
        <TempOverlay panelOpen={true} />
        <div className="relative flex h-full w-full items-center justify-center overflow-hidden bg-[radial-gradient(ellipse_at_center,rgba(20,27,31,0)_35%,rgba(20,27,31,0.85)_100%)]">
            {/* Ölçekleme transform:scale ile — CSS zoom, Chromium sürümleri
                arasında offsetWidth'i tutarsız döndürüyor (FiveM CEF legacy zoom =
                offsetWidth zoomlu, Chrome 128+ = zoomsuz) ve Leaflet tıklama
                koordinatları bozuluyor. transform her sürümde deterministik.
                Dış sarmalayıcı ölçekli boyutu kaplar → flex ortalaması doğru. */}
            <div style={{ width: 1492 * scale, height: 956 * scale }}>
                <div
                    style={{ transform: `scale(${scale})`, transformOrigin: "top left" }}
                    className="relative flex h-[956px] w-[1492px] flex-col overflow-clip rounded-[40px] border-2 border-white/15 bg-black/95"
                >
                    <Header clock={state?.clock} onClose={close} />
                    <div className="flex min-h-0 flex-1 gap-[16px] px-[16px] pb-[16px]">
                        <MapPanel
                            zones={mapAreas}
                            layer={layer}
                            onLayerChange={(l) => {
                                setLayer(l);
                                setSelectedAreaId(null);
                            }}
                            onZoneCreated={handleZoneCreated}
                            onZoneClick={handleZoneClick}
                            selectedId={selectedAreaId}
                            windDirection={state?.windDirection}
                            windSpeed={state?.windSpeed}
                            windAuto={state?.windAuto}
                            onSetWind={setWind}
                            canRename={selectedArea?.kind === "zone"}
                            onRequestRename={() => {
                                if (selectedArea?.kind === "zone") setRenameOpen(true);
                            }}
                            onRequestDelete={deleteZone}
                            onClearSelection={() => setSelectedAreaId(null)}
                        />
                        <WeatherPanel
                            areas={visibleAreas}
                            selectedArea={selectedArea}
                            clock={state?.clock}
                            onSelectArea={setSelectedAreaId}
                            onClearSelection={() => setSelectedAreaId(null)}
                            onOpenStaticModal={() => setStaticModalOpen(true)}
                            onChangeStaticAll={() => setStaticAllOpen(true)}
                            onToggleDynamic={toggleAreaDynamic}
                            onAddForecast={() => setAddForecastOpen(true)}
                            onEditForecast={(i) => setEditForecastIndex(i)}
                            onRemoveForecast={removeForecast}
                            onReorderForecast={reorderForecast}
                        />
                    </div>
                    {staticModalOpen && selectedArea && (
                        <ChangeStaticWeatherModal
                            initialWeather={selectedArea.weather}
                            initialTemperature={selectedArea.temperature}
                            onClose={() => setStaticModalOpen(false)}
                            onConfirm={(weather, temperature) => {
                                setAreaWeather(selectedArea.id, weather, temperature);
                                setStaticModalOpen(false);
                            }}
                        />
                    )}
                    {staticAllOpen && (
                        <ChangeStaticWeatherModal
                            onClose={() => setStaticAllOpen(false)}
                            onConfirm={setAllWeather}
                        />
                    )}
                    {pendingPoints && (
                        <CreateZoneModal
                            defaultName={`ZONE ${zoneCount + 1}`}
                            colorIndex={zoneCount}
                            onClose={() => setPendingPoints(null)}
                            onCreate={createZoneFromModal}
                        />
                    )}
                    {renameOpen && selectedArea && (
                        <RenameZoneModal
                            currentName={selectedArea.name}
                            onClose={() => setRenameOpen(false)}
                            onSave={(name) => {
                                setAreas((prev) =>
                                    prev.map((a) =>
                                        a.id === selectedArea.id ? { ...a, name } : a
                                    )
                                );
                                fetchNui("renameZone", { areaId: selectedArea.id, name });
                                setRenameOpen(false);
                                toast(t("toast.zoneRenamed"));
                            }}
                        />
                    )}
                    {addForecastOpen && selectedArea && (
                        <AddWeatherModal
                            previousTime={
                                selectedArea.forecast.length
                                    ? {
                                          hour: selectedArea.forecast[
                                              selectedArea.forecast.length - 1
                                          ].atHour,
                                          minute: selectedArea.forecast[
                                              selectedArea.forecast.length - 1
                                          ].atMinute,
                                      }
                                    : undefined
                            }
                            onClose={() => setAddForecastOpen(false)}
                            onAdd={addForecast}
                        />
                    )}
                    {editForecastIndex !== null &&
                        selectedArea?.forecast[editForecastIndex] && (
                            <EditWeatherModal
                                entry={selectedArea.forecast[editForecastIndex]}
                                onClose={() => setEditForecastIndex(null)}
                                onSave={(entry) => saveForecast(editForecastIndex, entry)}
                            />
                        )}

                    <Toast />
                </div>
            </div>
        </div>
        </>
    );
}
