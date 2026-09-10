import { useState } from "react";
import { useNuiEvent } from "@/hooks/useNuiEvent";

// Sıcaklık ekran efektleri katmanı. Admin panelinden BAĞIMSIZ, HER ZAMAN render edilir
// (client SendNUIMessage ile sürer; NUI odakta olmasa da mesaj gelir ve çizim yapılır).
// Isı dalgalanması MOTOR tarafında (heathaze timecycle) — NUI 3B sahneyi bükemez; burada
// yalnız SOĞUK frost overlay çizilir. pointer-events yok → oyunu/tıklamayı engellemez.
// Panel açıkken gizlenir (admin panelinin üstünde frost görünmesin).
type ColdFx = { on: boolean; intensity?: number };

export default function TempOverlay({ panelOpen }: { panelOpen: boolean }) {
    const [cold, setCold] = useState<ColdFx>({ on: false });
    useNuiEvent<ColdFx>("coldFx", (d) =>
        setCold({ on: !!d?.on, intensity: d?.intensity })
    );

    if (panelOpen || !cold.on) return null;
    const intensity = Math.max(0, Math.min(1, cold.intensity ?? 0.6));
    // Dış katman yoğunluğu (opacity) tutar; iç katman gradient + HAFİF opacity nabzı.
    // Nabız opacity'de (GPU-composited) — eski filter/brightness animasyonu her frame
    // TÜM EKRANI repaint ediyordu; opacity repaint gerektirmez.
    return (
        <div
            className="pointer-events-none fixed inset-0 z-[9999]"
            style={{ opacity: intensity }}
        >
            <div className="cdw-cold-frost absolute inset-0" />
        </div>
    );
}
