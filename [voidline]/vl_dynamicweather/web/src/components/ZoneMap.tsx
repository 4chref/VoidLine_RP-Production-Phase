import {
    forwardRef,
    useEffect,
    useImperativeHandle,
    useRef,
} from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import atlasUrl from "@/assets/atlas.webp";
import type { WeatherZone, ZonePoint } from "@/types";
import { WEATHER_META, tempColor, tempOpacity } from "@/utils/weather";
import { weatherIcon } from "@/utils/weatherIcon";
import { WIND_RIBBONS } from "@/utils/windRibbons";
import { getAccent } from "@/utils/theme";

export interface ZoneMapHandle {
    // Taslaktaki son noktayı geri alır; kalan nokta sayısını döner
    undoPoint: () => number;
    // Geri alınan son noktayı tekrar ekler; taslaktaki nokta sayısını döner
    redoPoint: () => number;
    // Taslağı kapatıp noktaları döner (3'ten az nokta varsa null)
    confirmDraft: () => ZonePoint[] | null;
    // Taslağı TEMİZLEMEDEN yoğun poligonu döner (çakışma kontrolü için)
    peekDraft: () => ZonePoint[] | null;
    clearDraft: () => void;
}

interface ZoneMapProps {
    zones: WeatherZone[];
    drawing: boolean;
    // Shape modu: kenarları sürüklenebilir kontrol tutamağıyla yaya çevir
    shaping: boolean;
    // Box modu: haritaya tıkla → hazır dikdörtgen; köşelerden resize, ortadan taşı
    boxMode?: boolean;
    // Taslak nokta sayısı değişince bildir (MapPanel taslak araçlarını gösterir)
    onDraftChange?: (count: number) => void;
    // Seçili alan id'si — vurgulanır, diğerleri sönükleşir
    selectedId?: number | null;
    // Forecast'te bölgelerde hava ikonu göster
    showWeather?: boolean;
    // Şehir (City Wide) rüzgar kurdeleleri göster (Figma vektörleri)
    showRibbons?: boolean;
    windDirection?: number;
    windSpeed?: number;
    onZoneClick?: (zone: WeatherZone) => void;
}

// codem-phone MapsApp.vue ile aynı CRS: GTA V dünya koordinatlarını
// (x=lng, y=lat) atlas görselinin pikseline çeviren affine dönüşüm.
const gtaCRS = L.extend({}, L.CRS.Simple, {
    projection: L.Projection.LonLat,
    scale(zoom: number) {
        return Math.pow(2, zoom);
    },
    zoom(sc: number) {
        return Math.log(sc) / 0.6931471805599453;
    },
    distance(pos1: L.LatLngLiteral, pos2: L.LatLngLiteral) {
        const dx = pos2.lng - pos1.lng;
        const dy = pos2.lat - pos1.lat;
        return Math.sqrt(dx * dx + dy * dy);
    },
    transformation: new L.Transformation(0.02072, 117.3, -0.0205, 172.8),
    infinite: false,
});

const DEFAULT_CENTER: L.LatLngExpression = [-300, -1500];

function toLatLng(p: ZonePoint): [number, number] {
    return [p.y, p.x];
}

function pointFromLatLng(ll: L.LatLng): ZonePoint {
    return { x: Math.round(ll.lng), y: Math.round(ll.lat) };
}

function midpoint(a: ZonePoint, b: ZonePoint): ZonePoint {
    return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
}

// Bir noktanın AB doğru parçasına en kısa uzaklığı (çift-tık ile köşe ekleme:
// en yakın kenarı bulmak için)
function distToSeg(p: ZonePoint, a: ZonePoint, b: ZonePoint): number {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    let t = len2 ? ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2 : 0;
    t = Math.max(0, Math.min(1, t));
    const cx = a.x + t * dx;
    const cy = a.y + t * dy;
    return Math.hypot(p.x - cx, p.y - cy);
}

// Quadratic bézier örnekleme (uç noktalar hariç ara noktalar)
function sampleQuad(p0: ZonePoint, c: ZonePoint, p1: ZonePoint, seg: number): ZonePoint[] {
    const out: ZonePoint[] = [];
    for (let i = 1; i < seg; i++) {
        const t = i / seg;
        const mt = 1 - t;
        out.push({
            x: mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x,
            y: mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y,
        });
    }
    return out;
}

// Köşe noktalarını (ve varsa kenar eğrilerini) yoğun bir poligon halkasına düzleştirir.
function buildRing(points: ZonePoint[], curves: Map<number, ZonePoint>): ZonePoint[] {
    const n = points.length;
    if (n < 3) return [...points];
    const ring: ZonePoint[] = [];
    for (let i = 0; i < n; i++) {
        ring.push(points[i]);
        const ctrl = curves.get(i);
        if (ctrl) ring.push(...sampleQuad(points[i], ctrl, points[(i + 1) % n], 16));
    }
    return ring;
}

function zoneCenter(points: ZonePoint[]): [number, number] {
    const lat = points.reduce((sum, p) => sum + p.y, 0) / points.length;
    const lng = points.reduce((sum, p) => sum + p.x, 0) / points.length;
    return [lat, lng];
}

// Etiket konumu için görsel merkez = poligonun sınır kutusu (bbox) merkezi.
// Vertex ortalaması (centroid) düzensiz hatlarda kenara kayar; bbox merkezi
// bölgenin ortasına daha yakın durur → etiket şehirde ortalı görünür.
function zoneBboxCenter(points: ZonePoint[]): [number, number] {
    let minX = Infinity,
        maxX = -Infinity,
        minY = Infinity,
        maxY = -Infinity;
    for (const p of points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
    }
    return [(minY + maxY) / 2, (minX + maxX) / 2];
}

function zoneLabelIcon(zone: WeatherZone, showWeather: boolean): L.DivIcon {
    // Forecast'te ismin üstünde hava ikonu (beyaz); Zone Editor'de sadece isim
    const icon = showWeather
        ? `<img class="zone-weather-img" src="${weatherIcon(zone.weather ?? "CLEAR")}" alt=""/>`
        : "";
    return L.divIcon({
        className: "zone-label-icon",
        html: `<div class="zone-label" style="color:${zone.labelColor}">${icon}<span>${zone.name}</span></div>`,
        iconSize: undefined,
    });
}

const SVGNS = "http://www.w3.org/2000/svg";

// Bir polyline'a dikey (kuzey→güney) çok-duraklı gradient uygular.
// stops: [{ offset 0-1, color }] — her şehrin kendi konumundaki tempColor'ı.
function applyRibbonGradient(
    poly: L.Polyline,
    id: string,
    stops: { offset: number; color: string; opacity?: number }[]
) {
    // @ts-expect-error Leaflet iç alanı
    const path: SVGPathElement | undefined = poly._path;
    if (!path) return;
    const svg = path.ownerSVGElement;
    if (!svg) return;
    let defs = svg.querySelector("defs");
    if (!defs) {
        defs = document.createElementNS(SVGNS, "defs");
        svg.insertBefore(defs, svg.firstChild);
    }
    svg.querySelector(`#${id}`)?.remove();
    const grad = document.createElementNS(SVGNS, "linearGradient");
    grad.setAttribute("id", id);
    grad.setAttribute("x1", "0");
    grad.setAttribute("y1", "0");
    grad.setAttribute("x2", "0");
    grad.setAttribute("y2", "1");
    for (const s of stops) {
        const stop = document.createElementNS(SVGNS, "stop");
        stop.setAttribute("offset", String(s.offset));
        stop.setAttribute("stop-color", s.color);
        if (s.opacity != null) stop.setAttribute("stop-opacity", String(s.opacity));
        grad.appendChild(stop);
    }
    defs.appendChild(grad);
    path.setAttribute("stroke", `url(#${id})`);
}

// Tasarımdaki çizim tutamacı: 8px kare, açık gri dolgu + kırmızı kenarlık
const draftVertexIcon = L.divIcon({
    className: "draw-vertex-icon",
    html: `<span class="draw-vertex"></span>`,
    iconSize: [8, 8],
});

// Shape modu kenar kontrol tutamağı: yuvarlak, sürüklenebilir
const controlHandleIcon = L.divIcon({
    className: "draw-control-icon",
    html: `<span class="draw-control"></span>`,
    iconSize: [14, 14],
});

// Box modu köşe tutamağı — sürüklenebilir, biraz daha büyük (kolay yakalanır)
const boxCornerIcon = L.divIcon({
    className: "box-corner-icon",
    html: `<span class="box-corner"></span>`,
    iconSize: [14, 14],
});

// Shape modu köşe tutamağı — sürüklenip taşınabilir (yeniden konumla), grab imleci
const vertexHandleIcon = L.divIcon({
    className: "vertex-handle-icon",
    html: `<span class="vertex-handle"></span>`,
    iconSize: [14, 14],
});

// Box modu orta taşıma tutamağı — düşük opaklıkta el ikonu
const boxMoveIcon = L.divIcon({
    className: "box-move-icon",
    html: `<span class="box-move"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 11V6a2 2 0 0 0-2-2 2 2 0 0 0-2 2m0 0V4a2 2 0 0 0-2-2 2 2 0 0 0-2 2v2m0 0V5a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7m8-2V4a2 2 0 0 1 2-2 2 2 0 0 1 2 2v10a6 6 0 0 1-6 6h-2a6 6 0 0 1-5.66-4l-1.4-3.8a2 2 0 0 1 3.4-2l.86 1.6"/></svg></span>`,
    iconSize: [40, 40],
});

// İki karşıt köşeden eksene hizalı dikdörtgenin 4 köşesi (kanonik sıra:
// (x0,y0)-(x1,y0)-(x1,y1)-(x0,y1); karşıt çiftler 0-2 ve 1-3)
function boxFrom(a: ZonePoint, b: ZonePoint): ZonePoint[] {
    const x0 = Math.round(Math.min(a.x, b.x));
    const x1 = Math.round(Math.max(a.x, b.x));
    const y0 = Math.round(Math.min(a.y, b.y));
    const y1 = Math.round(Math.max(a.y, b.y));
    return [
        { x: x0, y: y0 },
        { x: x1, y: y0 },
        { x: x1, y: y1 },
        { x: x0, y: y1 },
    ];
}

function centroid(pts: ZonePoint[]): ZonePoint {
    let sx = 0, sy = 0;
    for (const p of pts) {
        sx += p.x;
        sy += p.y;
    }
    return { x: sx / pts.length, y: sy / pts.length };
}

const ZoneMap = forwardRef<ZoneMapHandle, ZoneMapProps>(function ZoneMap(
    {
        zones,
        drawing,
        shaping,
        boxMode = false,
        onDraftChange,
        selectedId,
        showWeather,
        showRibbons,
        windDirection = 0,
        windSpeed = 0,
        onZoneClick,
    },
    ref
) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<L.Map | null>(null);
    const zoneLayerRef = useRef<L.LayerGroup | null>(null);
    // Zone etiketleri: DOM öğesi + dünya bbox'ı — zoom'da fontu alana göre ölçekle
    const labelInfoRef = useRef<
        { el: HTMLElement; minX: number; minY: number; maxX: number; maxY: number }[]
    >([]);

    // Çizim taslağı — render tetiklemeden Leaflet katmanlarında tutulur
    const draftPointsRef = useRef<ZonePoint[]>([]);
    // Geri alınan noktalar (redo için); yeni nokta eklenince temizlenir
    const redoPointsRef = useRef<ZonePoint[]>([]);
    // Kenar kavis kontrol noktaları: kenar index'i → kontrol noktası
    const draftCurvesRef = useRef<Map<number, ZonePoint>>(new Map());
    const draftLayerRef = useRef<L.LayerGroup | null>(null);
    // Yaşayan poligon (sürükleme sırasında setLatLngs ile güncellenir)
    const draftPolyRef = useRef<L.Polygon | null>(null);
    const drawingRef = useRef(drawing);
    drawingRef.current = drawing;
    const shapingRef = useRef(shaping);
    shapingRef.current = shaping;
    const boxModeRef = useRef(boxMode);
    boxModeRef.current = boxMode;
    // onDraftChange prop'unu ref'te tut (bir kez kaydolan harita event'leri
    // güncel prop'a erişsin — bayat closure olmasın)
    const onDraftChangeRef = useRef(onDraftChange);
    onDraftChangeRef.current = onDraftChange;
    const notifyDraft = () =>
        onDraftChangeRef.current?.(draftPointsRef.current.length);

    useEffect(() => {
        const el = containerRef.current;
        if (!el || mapRef.current) return;

        // Ayarlar codem-phone ile birebir — pürüzsüz fractional zoom, animasyonsuz
        const map = L.map(el, {
            crs: gtaCRS,
            minZoom: 2,
            maxZoom: 7,
            zoom: 3,
            center: DEFAULT_CENTER,
            attributionControl: false,
            zoomControl: false,
            scrollWheelZoom: true,
            doubleClickZoom: false,
            touchZoom: true,
            zoomSnap: 0,
            zoomDelta: 0.5,
            wheelPxPerZoomLevel: 120,
            zoomAnimation: false,
            fadeAnimation: false,
            markerZoomAnimation: false,
            inertia: false,
            bounceAtZoomLimits: false,
            maxBoundsViscosity: 0.5,
        });

        const imageSize = 1024;
        const sw = map.unproject([0, imageSize], 2);
        const ne = map.unproject([imageSize, 0], 2);
        const bounds = new L.LatLngBounds(sw, ne);
        map.setMaxBounds(bounds);
        L.imageOverlay(atlasUrl, bounds, { interactive: false }).addTo(map);

        // Açılışta tüm ada görünsün (tasarımdaki genel bakış) — telefondaki
        // zoom 3 dar ekran içindi, geniş panelde fitBounds kullanıyoruz
        const islandBounds = L.latLngBounds([-4000, -4100], [8000, 4600]);
        map.setMinZoom(1);
        map.fitBounds(islandBounds, { padding: [8, 8] });
        map.setMinZoom(map.getZoom() - 0.25);

        map.on("click", (e: L.LeafletMouseEvent) => {
            if (!drawingRef.current && !boxModeRef.current) return;
            // Panel transform:scale (useUiScale) altında. Görsel kutudaki oran ×
            // Leaflet'in kendi (ölçeksiz) boyutu ile konumu bul — offsetWidth
            // transform'dan etkilenmediği için her Chromium sürümünde deterministik.
            let lng = e.latlng.lng;
            let lat = e.latlng.lat;
            const container = containerRef.current;
            if (container) {
                const oe = e.originalEvent as MouseEvent;
                const rect = container.getBoundingClientRect();
                const size = map.getSize();
                const px = ((oe.clientX - rect.left) / rect.width) * size.x;
                const py = ((oe.clientY - rect.top) / rect.height) * size.y;
                const ll = map.containerPointToLatLng(L.point(px, py));
                lng = ll.lng;
                lat = ll.lat;
            }

            // Box modu: ilk tıkta tıklanan noktada hazır dikdörtgen oluştur
            // (görünür alanın küçük bir dilimi kadar). Sonraki tıklar yok sayılır —
            // kullanıcı köşe/orta tutamaçlarıyla düzenler.
            if (boxModeRef.current) {
                if (draftPointsRef.current.length !== 0) return;
                const cx = Math.round(lng);
                const cy = Math.round(lat);
                const b = map.getBounds();
                const h = Math.max(200, Math.round((b.getEast() - b.getWest()) * 0.045));
                draftPointsRef.current = boxFrom(
                    { x: cx - h, y: cy - h },
                    { x: cx + h, y: cy + h }
                );
                redoPointsRef.current = [];
                draftCurvesRef.current.clear();
                redrawDraft();
                return;
            }

            draftPointsRef.current.push({ x: Math.round(lng), y: Math.round(lat) });
            redoPointsRef.current = []; // yeni nokta redo geçmişini geçersiz kılar
            draftCurvesRef.current.clear(); // kenarlar değişti, kavisleri sıfırla
            redrawDraft();
        });

        // Shape modunda çizgiye çift tıkla → en yakın kenara yeni köşe ekle
        map.on("dblclick", (e: L.LeafletMouseEvent) => {
            if (!shapingRef.current) return;
            const pts = draftPointsRef.current;
            if (pts.length < 3) return;
            // Konum (transform-güvenli), click ile aynı yöntem
            let lng = e.latlng.lng;
            let lat = e.latlng.lat;
            const container = containerRef.current;
            if (container) {
                const oe = e.originalEvent as MouseEvent;
                const rect = container.getBoundingClientRect();
                const size = map.getSize();
                const px = ((oe.clientX - rect.left) / rect.width) * size.x;
                const py = ((oe.clientY - rect.top) / rect.height) * size.y;
                const ll = map.containerPointToLatLng(L.point(px, py));
                lng = ll.lng;
                lat = ll.lat;
            }
            const p = { x: Math.round(lng), y: Math.round(lat) };
            // En yakın kenarı bul
            const n = pts.length;
            let bestEdge = 0;
            let bestDist = Infinity;
            for (let i = 0; i < n; i++) {
                const d = distToSeg(p, pts[i], pts[(i + 1) % n]);
                if (d < bestDist) {
                    bestDist = d;
                    bestEdge = i;
                }
            }
            // Poligondan çok uzağa çift tıklanırsa yok say (kazara koruması)
            const b = map.getBounds();
            const thresh = (b.getEast() - b.getWest()) * 0.03;
            if (bestDist > thresh) return;
            // Yeni köşeyi kenarın iki ucu arasına ekle
            pts.splice(bestEdge + 1, 0, p);
            // Kavisleri remap: bölünen kenarı düşür, sonraki kenarları +1 kaydır
            const remapped = new Map<number, ZonePoint>();
            draftCurvesRef.current.forEach((ctrl, edge) => {
                if (edge < bestEdge) remapped.set(edge, ctrl);
                else if (edge > bestEdge) remapped.set(edge + 1, ctrl);
            });
            draftCurvesRef.current = remapped;
            redoPointsRef.current = [];
            redrawDraft();
        });

        // Zoom değişince etiket fontlarını alana göre yeniden ölçekle
        map.on("zoom zoomend", resizeLabels);

        zoneLayerRef.current = L.layerGroup().addTo(map);
        draftLayerRef.current = L.layerGroup().addTo(map);
        mapRef.current = map;

        return () => {
            map.off();
            map.remove();
            mapRef.current = null;
            zoneLayerRef.current = null;
            draftLayerRef.current = null;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Redraw'ı İÇERİK İMZASINA bağla: clock tick'inde App yeni bir `zones` dizisi
    // üretse de içerik aynıysa yeniden çizmeyiz → gereksiz Leaflet layer rebuild ve
    // rüzgar şeridi CSS animasyonunun 2sn'de bir resetlenmesi önlenir. İmza; ad,
    // renk, hava, sıcaklık, nokta sayısını kapsar (rename/hava değişince yenilenir).
    const drawSig = zones
        .map(
            (z) =>
                `${z.id}:${z.weather ?? ""}:${z.temperature ?? ""}:${z.color}:${z.labelColor}:${z.name}:${z.points.length}`
        )
        .join("|");

    // Her zone etiketinin fontunu, alanın o anki ekran (piksel) boyutuna göre
    // ayarla — böylece zoom-out'ta ya da küçük alanlarda yazı dışarı taşmaz.
    function resizeLabels() {
        const map = mapRef.current;
        if (!map) return;
        for (const info of labelInfoRef.current) {
            const p1 = map.latLngToLayerPoint([info.minY, info.minX]);
            const p2 = map.latLngToLayerPoint([info.maxY, info.maxX]);
            const dim = Math.min(Math.abs(p2.x - p1.x), Math.abs(p2.y - p1.y));
            // Alanın kısa kenarının ~%30'u; okunabilirlik için 8-22px arası kısıtla
            const font = Math.max(8, Math.min(22, dim * 0.3));
            info.el.style.fontSize = `${font}px`;
        }
    }

    // Bölgeleri (yeniden) çiz
    useEffect(() => {
        const layer = zoneLayerRef.current;
        if (!layer) return;
        layer.clearLayers();
        labelInfoRef.current = [];

        const hasSelection = selectedId != null;
        for (const zone of zones) {
            if (zone.points.length < 3) continue;
            const isSelected = zone.id === selectedId;
            const dimmed = hasSelection && !isSelected;

            // Vurgu: seçili canlı, seçim varken diğerleri sönük, yoksa normal.
            // 0.6 — şehir altta görünsün diye (0.7 çok kapatıyordu).
            const HI = 0.6;
            const baseFill = isSelected ? HI : dimmed ? 0.14 : 0.5;
            const baseWeight = isSelected ? 4 : 3;

            const polygon = L.polygon(zone.points.map(toLatLng), {
                color: zone.color,
                weight: baseWeight,
                dashArray: "4 6",
                lineJoin: "round",
                fillColor: zone.color,
                fillOpacity: baseFill,
            }).addTo(layer);

            // Etiket (görsel merkez = bbox merkezi + opsiyonel offset)
            const center = zoneBboxCenter(zone.points);
            if (zone.labelOffset) {
                center[0] += zone.labelOffset.y;
                center[1] += zone.labelOffset.x;
            }

            const label = L.marker(center, {
                icon: zoneLabelIcon(zone, !!showWeather),
                interactive: false,
                keyboard: false,
                opacity: dimmed ? 0.4 : 1,
            }).addTo(layer);

            // Etiketi alan-boyutlu ölçekleme için kaydet (dünya bbox'ı ile)
            const labelEl = label
                .getElement()
                ?.querySelector(".zone-label") as HTMLElement | null;
            if (labelEl) {
                let lminX = Infinity,
                    lmaxX = -Infinity,
                    lminY = Infinity,
                    lmaxY = -Infinity;
                for (const p of zone.points) {
                    if (p.x < lminX) lminX = p.x;
                    if (p.x > lmaxX) lmaxX = p.x;
                    if (p.y < lminY) lminY = p.y;
                    if (p.y > lmaxY) lmaxY = p.y;
                }
                labelInfoRef.current.push({
                    el: labelEl,
                    minX: lminX,
                    minY: lminY,
                    maxX: lmaxX,
                    maxY: lmaxY,
                });
            }

            // Hover: sönük olsa bile üstüne gelince poligon + etiket öne çıkar
            polygon.on("mouseover", () => {
                if (drawingRef.current) return;
                polygon.setStyle({ fillOpacity: HI, weight: 4 });
                label.setOpacity(1);
            });
            polygon.on("mouseout", () => {
                polygon.setStyle({ fillOpacity: baseFill, weight: baseWeight });
                label.setOpacity(dimmed ? 0.4 : 1);
            });

            if (onZoneClick) {
                polygon.on("click", (e) => {
                    if (drawingRef.current) return;
                    L.DomEvent.stopPropagation(e);
                    onZoneClick(zone);
                });
            }
        }

        // Yeni çizilen etiketleri o anki zoom'a göre boyutlandır
        resizeLabels();

        // Forecast + City Wide: Figma rüzgar eğrileri (sınırları çaprazlayan kurdeleler).
        // Her kurdele KOMŞU İKİ ŞEHRİN tam sıcaklık renginden gradient (soğuk şehir net mavi).
        if (showRibbons) {
            const cities = zones
                .filter((z) => z.points.length >= 3)
                .map((z) => ({
                    lat: zoneCenter(z.points)[0],
                    temp: z.temperature ?? WEATHER_META[z.weather ?? "CLEAR"].temp,
                }))
                .sort((a, b) => a.lat - b.lat); // güney → kuzey
            const last = cities[cities.length - 1];
            const bandWeight = windSpeed >= 8 ? 30 : windSpeed >= 4 ? 24 : 18;
            const dur = windSpeed > 0 ? Math.max(1.2, 18 / windSpeed) : 3;
            WIND_RIBBONS.forEach((ribbon, idx) => {
                if (ribbon.length < 2 || cities.length === 0) return;
                const lats = ribbon.map((p) => p.y);
                const latlngs = ribbon.map((p) => [p.y, p.x] as [number, number]);

                // Kurdelenin orta noktasını çevreleyen iki komşu şehrin tam sıcaklığı
                const midLat = (Math.max(...lats) + Math.min(...lats)) / 2;
                const northCity = cities.find((c) => c.lat >= midLat) ?? last;
                const southCity =
                    [...cities].reverse().find((c) => c.lat <= midLat) ?? cities[0];
                const topTemp = northCity.temp;
                const botTemp = southCity.temp;
                const band = L.polyline(latlngs, {
                    weight: bandWeight,
                    opacity: 1,
                    interactive: false,
                    className: "wind-ribbon-band",
                }).addTo(layer);
                applyRibbonGradient(band, `wind-ribbon-grad-${idx}`, [
                    { offset: 0, color: tempColor(topTemp), opacity: tempOpacity(topTemp) },
                    { offset: 1, color: tempColor(botTemp), opacity: tempOpacity(botTemp) },
                ]);

                // Ortada akan kesikli beyaz çizgi (yol şerit çizgisi — ince + uzun)
                const line = L.polyline(latlngs, {
                    weight: Math.max(2, Math.round(bandWeight * 0.12)),
                    opacity: 0.85,
                    color: "#ffffff",
                    interactive: false,
                    className: "wind-ribbon-line",
                    dashArray: "16 14",
                }).addTo(layer);
                // @ts-expect-error Leaflet iç alanı
                const lp: SVGPathElement | undefined = line._path;
                if (lp) {
                    lp.style.animationDuration = `${dur.toFixed(1)}s`;
                    if (windDirection > 90 && windDirection < 270)
                        lp.style.animationDirection = "reverse";
                }
            });
        }
        // `zones` içeriği drawSig üzerinden izlenir (referans değil).
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [drawSig, selectedId, showWeather, showRibbons, windDirection, windSpeed, onZoneClick]);

    // Çizim/şekil modunda imleç değişsin. Taslak YALNIZCA Confirm / Reset /
    // sekme değişiminde temizlenir (confirmDraft / clearDraft). Aracı kapatmak
    // veya Draw↔Shape geçişi taslağı KORUR — sadece redraw ile shape kavis
    // tutamaçları eklenir/kaldırılır.
    useEffect(() => {
        const el = containerRef.current;
        if (el) {
            // Draw ve Box modunda crosshair imleç (haritaya tıklama beklenir)
            el.classList.toggle("zone-map-drawing", drawing || boxMode);
            el.classList.toggle("zone-map-shaping", shaping);
        }
        redrawDraft();
    }, [drawing, shaping, boxMode]);

    function redrawDraft() {
        const layer = draftLayerRef.current;
        if (!layer) return;
        layer.clearLayers();
        draftPolyRef.current = null;

        const points = draftPointsRef.current;
        notifyDraft(); // MapPanel'e güncel taslak nokta sayısını bildir
        if (points.length === 0) return;
        const n = points.length;

        // ── Box modu: 4 köşeli dikdörtgen — sürüklenebilir köşeler + orta taşıma ──
        if (boxModeRef.current && n === 4) {
            const poly = L.polygon(points.map(toLatLng), {
                color: getAccent(),
                weight: 3,
                lineJoin: "round",
                fillColor: getAccent(),
                fillOpacity: 0.08,
            });
            poly.addTo(layer);
            draftPolyRef.current = poly;

            const corners = points.map((p) =>
                L.marker(toLatLng(p), { icon: boxCornerIcon, draggable: true, keyboard: false })
            );
            const center = L.marker(toLatLng(centroid(points)), {
                icon: boxMoveIcon,
                draggable: true,
                keyboard: false,
            });

            // poligon + köşe tutamaçlarını güncelle (skip: sürüklenen marker'ı
            // Leaflet zaten konumladığı için atla — çakışmayı önler)
            const syncCorners = (pts: ZonePoint[], skip = -1) => {
                draftPointsRef.current = pts;
                poly.setLatLngs(pts.map(toLatLng));
                pts.forEach((p, idx) => {
                    if (idx !== skip) corners[idx].setLatLng(toLatLng(p));
                });
            };

            // Köşe sürükle → karşıt köşe sabit, dikdörtgen korunur (resize)
            corners.forEach((m, i) => {
                let anchor: ZonePoint = points[(i + 2) % 4];
                m.on("dragstart", () => {
                    anchor = draftPointsRef.current[(i + 2) % 4];
                });
                m.on("drag", () => {
                    const pts = boxFrom(anchor, pointFromLatLng(m.getLatLng()));
                    syncCorners(pts, i);
                    center.setLatLng(toLatLng(centroid(pts)));
                });
                m.addTo(layer);
            });

            // Orta tutamağı sürükle → tüm köşeleri öteler (taşı)
            let start: L.LatLng = center.getLatLng();
            let startCorners: ZonePoint[] = points.map((p) => ({ ...p }));
            center.on("dragstart", () => {
                start = center.getLatLng();
                startCorners = draftPointsRef.current.map((p) => ({ ...p }));
            });
            center.on("drag", () => {
                const now = center.getLatLng();
                const dx = now.lng - start.lng;
                const dy = now.lat - start.lat;
                syncCorners(
                    startCorners.map((p) => ({
                        x: Math.round(p.x + dx),
                        y: Math.round(p.y + dy),
                    }))
                );
            });
            center.addTo(layer);
            return;
        }

        const curves = draftCurvesRef.current;

        // Kavisleri düzleştirilmiş halkayı çiz (kavis yoksa düz segment)
        if (n >= 3) {
            const ring = buildRing(points, curves).map(toLatLng);
            const poly = L.polygon(ring, {
                color: getAccent(),
                weight: 3,
                lineJoin: "round",
                fillColor: getAccent(),
                fillOpacity: 0.08,
            });
            poly.addTo(layer);
            draftPolyRef.current = poly;
        } else if (n === 2) {
            L.polyline(points.map(toLatLng), { color: getAccent(), weight: 3 }).addTo(layer);
        }

        // Köşe tutamaçları — Shape modunda sürüklenip taşınabilir (yeniden konumla),
        // diğer modlarda sabit gösterge. Sürükleme sırasında poligon canlı yenilenir;
        // bırakınca redraw ile kenar kavis tutamaçları yeni konuma göre dizilir.
        points.forEach((p, i) => {
            if (shapingRef.current && n >= 3) {
                const m = L.marker(toLatLng(p), {
                    icon: vertexHandleIcon,
                    draggable: true,
                    keyboard: false,
                });
                m.on("drag", () => {
                    points[i] = pointFromLatLng(m.getLatLng());
                    draftPolyRef.current?.setLatLngs(buildRing(points, curves).map(toLatLng));
                });
                m.on("dragend", () => redrawDraft());
                m.addTo(layer);
            } else {
                L.marker(toLatLng(p), {
                    icon: draftVertexIcon,
                    interactive: false,
                    keyboard: false,
                }).addTo(layer);
            }
        });

        // Shape modu: her kenara sürüklenebilir kavis kontrol tutamağı (elmas)
        if (shapingRef.current && n >= 3) {
            for (let i = 0; i < n; i++) {
                const a = points[i];
                const b = points[(i + 1) % n];
                const ctrl = curves.get(i) ?? midpoint(a, b);
                // Tutamaktan kenar ortasına ince bağlayıcı çizgi
                const link = L.polyline([toLatLng(midpoint(a, b)), toLatLng(ctrl)], {
                    color: getAccent(),
                    weight: 1,
                    opacity: 0.7,
                    interactive: false,
                });
                link.addTo(layer);

                const handle = L.marker(toLatLng(ctrl), {
                    icon: controlHandleIcon,
                    draggable: true,
                    keyboard: false,
                });
                handle.on("drag", () => {
                    curves.set(i, pointFromLatLng(handle.getLatLng()));
                    draftPolyRef.current?.setLatLngs(
                        buildRing(points, curves).map(toLatLng)
                    );
                    link.setLatLngs([toLatLng(midpoint(a, b)), handle.getLatLng()]);
                });
                handle.addTo(layer);
            }
        }
    }

    useImperativeHandle(ref, () => ({
        undoPoint() {
            const popped = draftPointsRef.current.pop();
            if (popped) redoPointsRef.current.push(popped);
            draftCurvesRef.current.clear(); // kenarlar değişti
            redrawDraft();
            return draftPointsRef.current.length;
        },
        redoPoint() {
            const restored = redoPointsRef.current.pop();
            if (restored) draftPointsRef.current.push(restored);
            draftCurvesRef.current.clear();
            redrawDraft();
            return draftPointsRef.current.length;
        },
        confirmDraft() {
            const points = draftPointsRef.current;
            if (points.length < 3) return null;
            // Kavisleri düzleştirip yoğun poligon döndür (backend basit poligon)
            const result = buildRing(points, draftCurvesRef.current);
            draftPointsRef.current = [];
            redoPointsRef.current = [];
            draftCurvesRef.current.clear();
            draftPolyRef.current = null;
            draftLayerRef.current?.clearLayers();
            notifyDraft();
            return result;
        },
        peekDraft() {
            const points = draftPointsRef.current;
            if (points.length < 3) return null;
            return buildRing(points, draftCurvesRef.current);
        },
        clearDraft() {
            draftPointsRef.current = [];
            redoPointsRef.current = [];
            draftCurvesRef.current.clear();
            draftPolyRef.current = null;
            draftLayerRef.current?.clearLayers();
            notifyDraft();
        },
    }));

    return <div ref={containerRef} className="zone-map absolute inset-0" />;
});

export default ZoneMap;
