import type { ZonePoint } from "@/types";

// Nokta poligon içinde mi? (ray casting) — GTA dünya koordinatları.
export function pointInPolygon(pt: ZonePoint, poly: ZonePoint[]): boolean {
    let inside = false;
    const n = poly.length;
    for (let i = 0, j = n - 1; i < n; j = i++) {
        const xi = poly[i].x;
        const yi = poly[i].y;
        const xj = poly[j].x;
        const yj = poly[j].y;
        if (
            yi > pt.y !== yj > pt.y &&
            pt.x < ((xj - xi) * (pt.y - yi)) / (yj - yi) + xi
        ) {
            inside = !inside;
        }
    }
    return inside;
}

// İki doğru parçası kesişiyor mu? (yönelim/CCW testi — uygun kesişim)
function ccw(a: ZonePoint, b: ZonePoint, c: ZonePoint): boolean {
    return (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x);
}

export function segmentsIntersect(
    p1: ZonePoint,
    p2: ZonePoint,
    p3: ZonePoint,
    p4: ZonePoint
): boolean {
    return ccw(p1, p3, p4) !== ccw(p2, p3, p4) && ccw(p1, p2, p3) !== ccw(p1, p2, p4);
}

// İki poligon üst üste geliyor mu? Bir köşe diğerinin içinde ya da kenarlar
// kesişiyorsa çakışma vardır (iç içe / çapraz durumlarını da yakalar).
export function polygonsOverlap(a: ZonePoint[], b: ZonePoint[]): boolean {
    if (a.length < 3 || b.length < 3) return false;
    for (const p of a) if (pointInPolygon(p, b)) return true;
    for (const p of b) if (pointInPolygon(p, a)) return true;
    for (let i = 0; i < a.length; i++) {
        const a1 = a[i];
        const a2 = a[(i + 1) % a.length];
        for (let j = 0; j < b.length; j++) {
            const b1 = b[j];
            const b2 = b[(j + 1) % b.length];
            if (segmentsIntersect(a1, a2, b1, b2)) return true;
        }
    }
    return false;
}
