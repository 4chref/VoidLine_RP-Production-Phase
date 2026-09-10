import type { WeatherType } from "@/types";

// ────────────────────────────────────────────────────────────────
// i18n — modül seviyesi t() (provider yok, en az churn).
// Kanonik anahtar seti + İngilizce fallback burada; oyun içinde gerçek
// metinler locale/*.lua'dan gelir (client → getLocale → setLocale ile üzerine yazılır).
// Eksik anahtar EN fallback'e, o da yoksa anahtarın kendisine düşer.
// Bu obje locale/en.lua'nın `ui` bölümüyle EŞ tutulmalı.
// ────────────────────────────────────────────────────────────────

const EN = {
    header: { subtitle: "Dynamic Weather", close: "Close" },
    panel: {
        areas: "Areas",
        upNext: "Up Next",
        dynamic: "Dynamic",
        static: "Static",
        noForecast: "No scheduled weather yet.",
        addWeather: "Add New Weather",
        enableHint: "Enable dynamic weather to adjust forecast schedules.",
        changeStatic: "Change Static Weather",
        changeStaticAll: "Change Static Weather For All",
        enableDynamic: "Enable Dynamic Weather",
        disableDynamic: "Disable Dynamic Weather",
        noZones: "No zones drawn yet.",
        reorder: "Reorder",
        confirm: "Confirm",
        wide: "Wide",
    },
    map: {
        zoneEditor: "Zone Editor",
        forecast: "Forecast",
        draw: "Draw",
        reset: "Reset",
        drawHint: "Click Draw to add a zone.",
        overlap: "Zones cannot overlap — adjust the shape and try again.",
        zoneBase: "Zone Base",
        cityWide: "City Wide",
        changeDirection: "Change Direction",
        info: {
            title: "Zone Editor Help",
            draw: "Draw: click on the map to add corner points.",
            box: "Box: click for a ready rectangle — drag corners to resize, drag the center to move.",
            move: "Shape: drag corner points to reposition them.",
            addPoint: "Shape: double-click an edge to add a new corner point.",
            curve: "Shape: drag the mid-edge handle to curve that edge.",
            confirm: "Press Confirm to create the zone.",
        },
        tools: {
            drawZone: "Draw zone",
            shape: "Shape",
            box: "Box",
            rename: "Rename zone",
            hide: "Hide zones",
            undo: "Undo point",
            redo: "Redo point",
            resetDraft: "Reset draft",
            confirm: "Confirm zone",
            changeColor: "Change color",
            delete: "Delete zone",
        },
    },
    modals: {
        selectType: "Select Weather Type",
        temperature: "Temperature",
        time: "Time",
        addWeatherCta: "Add Weather",
        myZone: "My Zone",
        centigrade: "Centigrade",
        changeStaticTitle: "Change Static Weather",
        createZoneTitle: "Create Weather Zone",
        createZoneCta: "Create Weather Zone",
        zoneNameColor: "Zone Name & Color",
        currentWeather: "Current Weather",
        renameTitle: "Rename Zone",
        renameCta: "Save",
        zoneName: "Zone Name",
        addTitle: "Add New Weather",
        editTitle: "Edit Weather",
        editCta: "Save Weather Details",
        prevCastTime: "Previous weather casting time is {time}",
        currentlyAt: "Currently {weather} at {time}",
        windTitle: "Wind",
        windDirection: "Direction",
        windSpeed: "Speed",
        windAuto: "Automatic",
        cancel: "Cancel",
        confirm: "Confirm",
        deleteCta: "Delete",
        deleteZoneTitle: "Delete Zone",
        deleteZoneMessage: "Are you sure you want to delete this zone? This action cannot be undone.",
    },
    toast: {
        weatherSet: "Weather updated",
        weatherAllSet: "Weather set for all areas",
        dynamicOn: "Dynamic mode enabled",
        dynamicOff: "Dynamic mode disabled",
        zoneCreated: "Zone created",
        zoneRenamed: "Zone renamed",
        zoneDeleted: "Zone deleted",
        forecastAdded: "Forecast added",
        forecastUpdated: "Forecast updated",
        forecastRemoved: "Forecast removed",
        windSet: "Wind updated",
        windAuto: "Wind set to automatic",
    },
    relative: {
        now: "Now",
        inMin: "In {n} Min",
        inHour: "In {n} Hour",
        inHours: "In {n} Hours",
    },
    // Hava tipi etiketleri (WeatherType anahtarlı). Sıcaklık (temp) kodda kalır.
    weather: {
        EXTRASUNNY: "Extra Sunny",
        CLEAR: "Clear",
        NEUTRAL: "Neutral",
        SMOG: "Smog",
        FOGGY: "Foggy",
        CLOUDS: "Cloudy",
        OVERCAST: "Overcast",
        CLEARING: "Clearing",
        RAIN: "Rainy",
        THUNDER: "Thunder",
        SNOWLIGHT: "Light Snow",
        SNOW: "Snow",
        BLIZZARD: "Blizzard",
        XMAS: "Xmas",
        HALLOWEEN: "Halloween",
    },
};

type Dict = Record<string, unknown>;

// Aktif sözlük — başta EN; setLocale ile oyun içindeki dil üzerine yazılır.
let dict: Dict = EN as Dict;

// Basit derin birleştirme (fetched'i EN kopyasının üstüne). structuredClone
// yerine JSON kopya — eski CEF sürümleriyle uyumlu.
function deepMerge(base: Dict, over: Dict): Dict {
    for (const k of Object.keys(over)) {
        const ov = over[k];
        if (ov && typeof ov === "object" && !Array.isArray(ov)) {
            base[k] = deepMerge((base[k] as Dict) ?? {}, ov as Dict);
        } else if (ov != null && ov !== "") {
            base[k] = ov;
        }
    }
    return base;
}

// Oyun içinden (getLocale) gelen `ui` sözlüğünü EN fallback üstüne uygula.
export function setLocale(fetched: Dict | null | undefined): void {
    if (fetched && typeof fetched === "object" && Object.keys(fetched).length > 0) {
        dict = deepMerge(JSON.parse(JSON.stringify(EN)) as Dict, fetched);
    }
}

function lookup(path: string): string | undefined {
    let cur: unknown = dict;
    for (const seg of path.split(".")) {
        if (cur == null || typeof cur !== "object") return undefined;
        cur = (cur as Dict)[seg];
    }
    return typeof cur === "string" ? cur : undefined;
}

// t("panel.areas") — nokta yollu anahtar; eksikse anahtarın kendisi döner.
// vars ile {n}/{time}/{weather} yer tutucuları doldurulur.
export function t(path: string, vars?: Record<string, string | number>): string {
    let s = lookup(path) ?? path;
    if (vars) {
        for (const [k, v] of Object.entries(vars)) {
            s = s.replace("{" + k + "}", String(v));
        }
    }
    return s;
}

export function tWeather(type: WeatherType): string {
    return t("weather." + type);
}
