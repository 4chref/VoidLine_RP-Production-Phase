import { formatClock } from "@/utils/weather";
import { t } from "@/utils/locale";
import iconClose from "@/assets/icon-close.svg";

interface HeaderProps {
    clock?: { hour: number; minute: number };
    onClose: () => void;
}

export default function Header({ clock, onClose }: HeaderProps) {
    return (
        <div className="relative h-[56px] w-full shrink-0">
            <p className="absolute left-[34px] top-1/2 -translate-y-1/2 whitespace-nowrap text-[16px] tracking-[-0.64px] text-white">
                <span className="font-black">BLVCK</span>
                <span>{"  "}</span>
                <span className="font-normal text-white/50">{t("header.subtitle")}</span>
            </p>

            {clock && (
                <span className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 whitespace-nowrap text-[16px] font-medium text-white opacity-50">
                    {formatClock(clock.hour, clock.minute)}
                </span>
            )}

            <button
                onClick={onClose}
                className="absolute right-[16px] top-1/2 flex size-[40px] -translate-y-1/2 items-center justify-center rounded-[14px] border-2 border-white/10 transition-colors hover:border-white/20"
            >
                <span className="flex size-[32px] items-center justify-center rounded-[9px] bg-white/20">
                    <img src={iconClose} alt={t("header.close")} className="size-[16px]" />
                </span>
            </button>
        </div>
    );
}
