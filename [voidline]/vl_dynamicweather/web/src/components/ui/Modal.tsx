import { useCallback, useEffect, useState, type ReactNode } from "react";
import { t } from "@/utils/locale";
import iconClose from "@/assets/icon-close.svg";

interface ModalProps {
    title: string;
    onClose: () => void;
    children: ReactNode;
    // Alt sabit aksiyon (CTA butonu). Verilmezse alt boşluk kalmaz.
    footer?: ReactNode;
    // Kart genişliği — Figma varsayılanı 560px (Change Static Weather modalı).
    width?: number;
}

// Figma 1:1 — overlay + koyu kart + başlık/kapat + ayraç.
// Panelin içine (konumlu bir parent'ın içine) yerleştirilir; inset-0 ile kaplar.
// Kapatma (X / backdrop / Escape) çıkış animasyonu oynatıp sonra unmount eder.
export default function Modal({ title, onClose, children, footer, width = 560 }: ModalProps) {
    const [closing, setClosing] = useState(false);

    const requestClose = useCallback(() => {
        if (closing) return;
        setClosing(true);
        window.setTimeout(onClose, 160); // çıkış animasyon süresiyle uyumlu
    }, [closing, onClose]);

    useEffect(() => {
        const onKey = (e: KeyboardEvent) => {
            if (e.key === "Escape") requestClose();
        };
        window.addEventListener("keydown", onKey);
        return () => window.removeEventListener("keydown", onKey);
    }, [requestClose]);

    return (
        <div
            className={`${
                closing ? "cdw-backdrop-out" : "cdw-backdrop"
            } absolute inset-0 z-[2000] flex items-center justify-center rounded-[inherit] bg-black/90`}
            onClick={requestClose}
        >
            <div
                className={`${
                    closing ? "cdw-modal-out" : "cdw-modal"
                } overflow-visible rounded-[20px] border-[1.5px] border-white/5 bg-[#1a1a1a]`}
                style={{ width }}
                onClick={(e) => e.stopPropagation()}
            >
                {/* Başlık satırı */}
                <div className="flex items-center justify-between px-[30px] py-[18px]">
                    <h2 className="text-[20px] font-semibold tracking-[-0.8px] text-white">
                        {title}
                    </h2>
                    <button
                        onClick={requestClose}
                        className="flex size-[40px] items-center justify-center rounded-[12px] border border-white/5 bg-white/5 transition-colors hover:bg-white/10"
                    >
                        <img src={iconClose} alt={t("header.close")} className="size-[20px]" />
                    </button>
                </div>

                <div className="h-px w-full bg-white/10" />

                {/* İçerik */}
                <div className="flex flex-col gap-[16px] px-[30px] py-[24px]">{children}</div>

                {footer && <div className="px-[30px] pb-[24px]">{footer}</div>}
            </div>
        </div>
    );
}
