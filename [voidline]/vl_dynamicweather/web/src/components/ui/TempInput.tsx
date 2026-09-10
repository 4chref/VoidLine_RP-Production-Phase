import { t } from "@/utils/locale";

interface TempInputProps {
    value: number | "";
    onChange: (value: number | "") => void;
    placeholder?: string;
}

// Figma 1:1 — bg black/25, h-56, rounded-16, placeholder "Centigrade" opacity-20.
export default function TempInput({ value, onChange, placeholder }: TempInputProps) {
    const ph = placeholder ?? t("modals.centigrade");
    return (
        <input
            type="number"
            inputMode="numeric"
            value={value}
            onChange={(e) => {
                const v = e.target.value;
                onChange(v === "" ? "" : Number(v));
            }}
            placeholder={ph}
            // [appearance:textfield] + webkit spin-button gizleme → number stepper okları kalkar
            className="h-[56px] w-full rounded-[16px] bg-black/25 px-[20px] text-[16px] font-semibold tracking-[-0.64px] text-white transition-shadow placeholder:text-white/20 focus:outline-none focus:ring-2 focus:ring-[rgb(var(--cdw-accent-rgb)_/_0.4)] [appearance:textfield] [&::-webkit-outer-spin-button]:m-0 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:m-0 [&::-webkit-inner-spin-button]:appearance-none"
        />
    );
}
