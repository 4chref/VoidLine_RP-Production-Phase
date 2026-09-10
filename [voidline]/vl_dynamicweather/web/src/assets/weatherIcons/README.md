# Weather ikonları

Her hava tipi için 32×32 SVG ikonlar buraya konur. **Kaynak:** Figma node `1-1523` ("Weathers").

## Kural
Dosya adı **WeatherType ile birebir** olmalı (büyük harf, `.svg`):

```
EXTRASUNNY.svg  CLEAR.svg  NEUTRAL.svg  SMOG.svg  FOGGY.svg
CLOUDS.svg  OVERCAST.svg  CLEARING.svg  RAIN.svg  THUNDER.svg
SNOWLIGHT.svg  SNOW.svg  BLIZZARD.svg  XMAS.svg  HALLOWEEN.svg
```

Dosya eklendikçe `@/utils/weatherIcon.ts` (Vite `import.meta.glob`) otomatik eşler.
İkonu olmayan tip için `icon-rainy.svg` fallback kullanılır.

## Not
Figma setinde **OVERCAST yok**, iki tane **FOGGY** var. OVERCAST için ayrı ikon
export edilene kadar fallback görünür (ya da ikinci FOGGY, OVERCAST.svg olarak kaydedilebilir).
