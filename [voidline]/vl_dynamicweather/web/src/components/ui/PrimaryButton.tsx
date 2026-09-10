import type { ReactNode } from "react";

interface PrimaryButtonProps {
    children: ReactNode;
    onClick?: () => void;
    className?: string;
    disabled?: boolean;
}

// Figma 1:1 — kırmızı CTA: bg #dc143c, border #4d000f, h-48, rounded-16,
// iç üst parlama + katmanlı gölge. (Change Static Weather "Add Weather" butonu.)
export default function PrimaryButton({
    children,
    onClick,
    className = "",
    disabled = false,
}: PrimaryButtonProps) {
    return (
        <button
            onClick={onClick}
            disabled={disabled}
            className={
                "relative h-[48px] w-full overflow-clip rounded-[16px] border-2 border-[var(--cdw-accent-dark)] bg-[var(--cdw-accent)] " +
                "text-[16px] font-medium tracking-[-0.64px] text-[var(--cdw-on-accent)] transition-[filter] hover:brightness-110 " +
                "shadow-[0px_42px_25px_0px_rgba(0,0,0,0.11),0px_19px_19px_0px_rgba(0,0,0,0.19),0px_5px_10px_0px_rgba(0,0,0,0.22)] " +
                "disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:brightness-100 " +
                className
            }
        >
            {children}
            <span className="pointer-events-none absolute inset-0 rounded-[inherit] shadow-[inset_0px_4px_2px_0px_rgba(255,255,255,0.25)]" />
        </button>
    );
}
