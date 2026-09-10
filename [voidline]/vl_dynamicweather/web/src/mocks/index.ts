import { registerMock } from "@/utils/nui";
import type { WeatherState } from "@/types";

// Tarayıcıda geliştirme yaparken kullanılan sahte veriler.
// Oyun içinde bunların yerini client/nui.lua callback'leri alır.

const mockState: WeatherState = {
    currentWeather: "CLEAR",
    // GLOBAL rüzgar mock'u (backend GetWindSpeed/GetWindDirection ile dolduracak)
    windSpeed: 6.0,
    windDirection: 45,
    windAuto: true,
    clock: { hour: 14, minute: 30 },
    forecast: [
        { weather: "CLOUDS", temperature: 20, atHour: 15, atMinute: 12 },
        { weather: "OVERCAST", temperature: 18, atHour: 16, atMinute: 45 },
        { weather: "RAIN", temperature: 16, atHour: 18, atMinute: 0 },
        { weather: "CLEARING", temperature: 19, atHour: 18, atMinute: 40 },
        { weather: "CLEAR", temperature: 26, atHour: 19, atMinute: 40 },
    ],
};

// Yalnızca UI'nin gerçekten çağırdığı (fetchNui) event'ler için mock.
export function setupMocks() {
    registerMock("getState", () => mockState);

    registerMock("setWeather", (data) => {
        mockState.currentWeather = data.weather;
        return { success: true };
    });

    registerMock("toggleDynamic", () => ({ success: true }));

    // Alanlar (şehir + zone): boş dönerse UI varsayılan şehirleri (DEFAULT_CITIES) kullanır
    registerMock("getAreas", () => []);

    // Locale: tarayıcı önizlemesinde boş → locale.ts'teki İngilizce fallback kullanılır
    registerMock("getLocale", () => ({}));
    // Config: önizlemede 12s varsayılan (24s test için "24" yap). themeColor ile
    // accent rengini önizlemede test edebilirsin (ör. "#55E6FF").
    registerMock("getConfig", () => ({ timeFormat: "12", themeColor: "#FF5558" }));

    const ok = () => ({ success: true });
    registerMock("createZone", ok);
    registerMock("renameZone", ok);
    registerMock("addForecastEntry", ok);
    registerMock("editForecastEntry", ok);
    registerMock("removeForecastEntry", ok);
    registerMock("setForecast", ok);
    registerMock("close", ok);
}
