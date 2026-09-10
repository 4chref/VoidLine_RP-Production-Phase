import { useEffect, useState } from "react";
import { subscribeToast } from "@/utils/toast";

interface ToastItem {
    id: number;
    msg: string;
}

// Üst-orta geçici bildirim yığını (fade in/out ~1.6s, prefers-reduced-motion aware).
export default function Toast() {
    const [items, setItems] = useState<ToastItem[]>([]);

    useEffect(() => {
        return subscribeToast((msg, id) => {
            setItems((prev) => [...prev, { id, msg }]);
            window.setTimeout(() => {
                setItems((prev) => prev.filter((i) => i.id !== id));
            }, 1700);
        });
    }, []);

    if (items.length === 0) return null;

    return (
        <div className="pointer-events-none absolute left-1/2 top-[74px] z-[2500] flex -translate-x-1/2 flex-col items-center gap-[8px]">
            {items.map((i) => (
                <div
                    key={i.id}
                    className="cdw-toast rounded-[12px] border border-white/10 bg-black/85 px-[16px] py-[10px] text-[14px] font-medium text-white shadow-[0px_10px_25px_0px_rgba(0,0,0,0.35)]"
                >
                    {i.msg}
                </div>
            ))}
        </div>
    );
}
