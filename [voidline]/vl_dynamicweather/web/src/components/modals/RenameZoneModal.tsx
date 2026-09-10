import { useState } from "react";
import { t } from "@/utils/locale";
import Modal from "@/components/ui/Modal";
import PrimaryButton from "@/components/ui/PrimaryButton";
import FieldLabel from "@/components/ui/FieldLabel";

interface RenameZoneModalProps {
    currentName: string;
    onClose: () => void;
    onSave: (name: string) => void;
}

// Seçili zone'un adını değiştirir (T aracı). Create Zone modalıyla aynı stil.
export default function RenameZoneModal({ currentName, onClose, onSave }: RenameZoneModalProps) {
    const [name, setName] = useState(currentName);

    const save = () => {
        const trimmed = name.trim();
        if (trimmed) onSave(trimmed);
    };

    return (
        <Modal
            title={t("modals.renameTitle")}
            onClose={onClose}
            footer={<PrimaryButton onClick={save}>{t("modals.renameCta")}</PrimaryButton>}
        >
            <FieldLabel>{t("modals.zoneName")}</FieldLabel>
            <input
                autoFocus
                value={name}
                onChange={(e) => setName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && save()}
                placeholder={t("modals.myZone")}
                className="h-[56px] w-full rounded-[16px] bg-black/25 px-[20px] text-[16px] font-semibold tracking-[-0.64px] text-white transition-shadow placeholder:text-white/20 focus:outline-none focus:ring-2 focus:ring-[rgb(var(--cdw-accent-rgb)_/_0.4)]"
            />
        </Modal>
    );
}
