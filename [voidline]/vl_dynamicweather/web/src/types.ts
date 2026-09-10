// Lua tarafındaki GlobalState.weather yapısıyla birebir aynı tutulmalı
export type WeatherType =
    | "EXTRASUNNY"
    | "CLEAR"
    | "NEUTRAL"
    | "SMOG"
    | "FOGGY"
    | "CLOUDS"
    | "OVERCAST"
    | "CLEARING"
    | "RAIN"
    | "THUNDER"
    | "SNOWLIGHT"
    | "SNOW"
    | "BLIZZARD"
    | "XMAS"
    | "HALLOWEEN";

// Dinamik moddaki bir hava alanının çizelge girişi.
// "cast time" = bu havanın devreye gireceği oyun içi saat (Edit/Add modallarındaki Time).
export interface ForecastEntry {
    weather: WeatherType;
    // Kullanıcı girişi sıcaklık (defaultTemp ön-dolgu). İleride Config'e taşınacak.
    temperature: number;
    atHour: number; // 0-23
    atMinute: number; // 0-59
}

// Havanın uygulandığı alan türü.
// city = 4 hazır bölge (hatları sabit, biz belirleriz); zone = admin'in çizdiği özel alan.
// Çakışmada ZONE kazanır (bkz. PROJECT.md §2).
export type WeatherAreaKind = "city" | "zone";

// Şehir ve zone'ları tek modelde birleştiren birim.
// Her alan bağımsız olarak static (tek hava) ya da dynamic (forecast çizelgesi) olabilir.
export interface WeatherArea {
    id: number;
    kind: WeatherAreaKind;
    name: string;
    // Poligon çizgi/dolgu rengi ve etiket rengi (hex)
    color: string;
    labelColor: string;
    points: ZonePoint[];
    // Mevcut/statik hava + kullanıcı girişi sıcaklık
    weather: WeatherType;
    temperature: number;
    // Bu alan dinamik mi? Dinamikse forecast çizelgesi arasında otomatik geçer.
    dynamic: boolean;
    forecast: ForecastEntry[];
}

export interface ZonePoint {
    // GTA V dünya koordinatları
    x: number;
    y: number;
}

export interface WeatherZone {
    id: number;
    name: string;
    // Poligon çizgi/dolgu rengi (hex)
    color: string;
    // Harita üzerindeki etiket rengi (hex, koyu ton)
    labelColor: string;
    points: ZonePoint[];
    // Bu bölgeye atanmış hava durumu (yoksa sunucu geneli geçerli)
    weather?: WeatherType;
    // Sıcaklık (rüzgar şeridi renklendirmesi için; WeatherArea'da zorunlu)
    temperature?: number;
    // Etiketi centroid'den kaydırmak için (GTA dünya birimi; y negatif = ekranda aşağı)
    labelOffset?: ZonePoint;
}

export interface WeatherState {
    currentWeather: WeatherType;
    // Rüzgar GLOBAL (GTA'da tek). Backend GetWindSpeed()/GetWindDirection() ile doldurur.
    windSpeed: number;
    // Rüzgarın estiği yön, derece (0-359). GetWindDirection() vektörü → heading.
    windDirection: number;
    // Rüzgar otomatik mi (rastgele döngü) yoksa admin manuel mi ayarladı
    windAuto: boolean;
    clock: {
        hour: number;
        minute: number;
    };
    forecast: ForecastEntry[];
}
