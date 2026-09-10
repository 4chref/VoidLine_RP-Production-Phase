import type { ZonePoint } from "@/types";

// Figma "Zones" (node 1-527) rüzgar vektörleri (Vector 19/18/23/26) — bezier örneklenip
// export-space -> GTA dünya koordinatına çevrildi. Bölge sınırlarını çaprazlayan akış eğrileri.
export const WIND_RIBBONS: ZonePoint[][] = [
    [{ x: 536, y: 5330 }, { x: 526, y: 5269 }, { x: 501, y: 5159 }, { x: 472, y: 5007 }, { x: 447, y: 4818 }, { x: 435, y: 4599 }, { x: 445, y: 4354 }, { x: 487, y: 4089 }, { x: 570, y: 3811 }],
    [{ x: 536, y: 5330 }, { x: 526, y: 5269 }, { x: 501, y: 5159 }, { x: 472, y: 5007 }, { x: 447, y: 4818 }, { x: 435, y: 4599 }, { x: 445, y: 4354 }, { x: 487, y: 4089 }, { x: 570, y: 3811 }],
    [{ x: 561, y: 3221 }, { x: 522, y: 3105 }, { x: 419, y: 3002 }, { x: 273, y: 2903 }, { x: 106, y: 2798 }, { x: -61, y: 2675 }, { x: -207, y: 2525 }, { x: -310, y: 2337 }, { x: -349, y: 2101 }],
    [{ x: -340, y: 1520 }, { x: -316, y: 1393 }, { x: -252, y: 1238 }, { x: -161, y: 1048 }, { x: -57, y: 818 }, { x: 47, y: 541 }, { x: 138, y: 212 }, { x: 202, y: -176 }, { x: 227, y: -629 }],
];
