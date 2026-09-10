import { useState } from "react";
import { t } from "@/utils/locale";
import Modal from "@/components/ui/Modal";
import PrimaryButton from "@/components/ui/PrimaryButton";
import FieldLabel from "@/components/ui/FieldLabel";

type WindApply = { auto: true } | { direction: number; speed: number };

interface WindModalProps {
    direction: number;
    speed: number;
    auto: boolean;
    onClose: () => void;
    onApply: (data: WindApply) => void;
}

// Rüzgar kontrolü — yön (0-359° pusula + slider) + hız (0-12) veya "Automatic".
export default function WindModal({ direction, speed, auto, onClose, onApply }: WindModalProps) {
    const [dir, setDir] = useState(((Math.round(direction) % 360) + 360) % 360);
    const [spd, setSpd] = useState(Math.max(0, Math.min(12, Math.round(speed))));
    const [isAuto, setIsAuto] = useState(auto);

    const apply = () => onApply(isAuto ? { auto: true } : { direction: dir, speed: spd });

    return (
        <Modal
            title={t("modals.windTitle")}
            onClose={onClose}
            width={420}
            footer={<PrimaryButton onClick={apply}>{t("modals.renameCta")}</PrimaryButton>}
        >
            {/* Automatic toggle */}
            <button
                type="button"
                onClick={() => setIsAuto((a) => !a)}
                className="flex items-center justify-between rounded-[16px] bg-black/25 px-[20px] py-[14px] text-left"
            >
                <span className="text-[16px] font-semibold tracking-[-0.64px] text-white">
                    {t("modals.windAuto")}
                </span>
                <span
                    className={`relative h-[26px] w-[46px] rounded-full transition-colors ${
                        isAuto ? "bg-[var(--cdw-accent)]" : "bg-white/15"
                    }`}
                >
                    <span
                        className={`absolute top-[3px] size-[20px] rounded-full transition-all ${
                            isAuto ? "left-[23px] bg-[var(--cdw-on-accent)]" : "left-[3px] bg-white"
                        }`}
                    />
                </span>
            </button>

            {!isAuto && (
                <>
                    <FieldLabel>{t("modals.windDirection")}</FieldLabel>
                    <div className="flex items-center gap-[16px]">
                        {/* Pusula: kuzey üstte; ok yöne döner */}
                        <div className="relative size-[72px] shrink-0 rounded-full border border-white/10 bg-black/25">
                            <span className="absolute left-1/2 top-[4px] -translate-x-1/2 text-[10px] font-semibold text-white/40">
                                N
                            </span>
                            <svg
                                viewBox="0 0 100 100"
                                className="absolute inset-0 text-[var(--cdw-accent)]"
                                style={{ transform: `rotate(${dir}deg)` }}
                            >
                                <path
                                    d="M50 16 L59 54 L50 47 L41 54 Z"
                                    fill="currentColor"
                                />
                                <circle cx="50" cy="50" r="4" fill="currentColor" />
                            </svg>
                        </div>
                        <div className="flex-1">
                            <input
                                type="range"
                                min={0}
                                max={359}
                                value={dir}
                                onChange={(e) => setDir(Number(e.target.value))}
                                className="w-full accent-[var(--cdw-accent)]"
                            />
                            <div className="mt-[4px] text-[14px] font-medium text-white/60">
                                {dir}°
                            </div>
                        </div>
                    </div>

                    <FieldLabel>{t("modals.windSpeed")}</FieldLabel>
                    <div className="flex items-center gap-[16px]">
                        <input
                            type="range"
                            min={0}
                            max={12}
                            value={spd}
                            onChange={(e) => setSpd(Number(e.target.value))}
                            className="flex-1 accent-[var(--cdw-accent)]"
                        />
                        <div className="w-[36px] text-right text-[14px] font-medium text-white/60">
                            {spd}
                        </div>
                    </div>
                </>
            )}
        </Modal>
    );
}
