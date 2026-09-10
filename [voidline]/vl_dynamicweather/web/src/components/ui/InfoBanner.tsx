import type { ReactNode } from "react";

// Figma 1-1018 bilgi şeridi: bg #dc143c/10, h-64, rounded-17, ikon + kırmızı metin.
export default function InfoBanner({ children }: { children: ReactNode }) {
    return (
        <div className="flex h-[64px] w-full items-center gap-[12px] rounded-[17px] bg-[rgb(var(--cdw-accent-rgb)_/_0.1)] px-[16px]">
            <svg viewBox="0 0 24 24" className="size-[24px] shrink-0 text-[var(--cdw-accent)]" fill="none">
                <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
                <path
                    d="M12 11v5"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                />
                <circle cx="12" cy="7.5" r="1.25" fill="currentColor" />
            </svg>
            <p className="text-[16px] font-semibold tracking-[-0.64px] text-[var(--cdw-accent)]">
                {children}
            </p>
        </div>
    );
}
