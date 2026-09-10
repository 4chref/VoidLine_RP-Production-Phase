import Modal from "@/components/ui/Modal";
import PrimaryButton from "@/components/ui/PrimaryButton";
import { t } from "@/utils/locale";

interface ConfirmDialogProps {
    title: string;
    message: string;
    confirmLabel?: string;
    cancelLabel?: string;
    onCancel: () => void;
    onConfirm: () => void;
}

// Ekran ortasında onay penceresi (Modal tabanlı). Yanlış-tık koruması için
// yıkıcı işlemlerde (zone silme vb.) kullanılır.
export default function ConfirmDialog({
    title,
    message,
    confirmLabel,
    cancelLabel,
    onCancel,
    onConfirm,
}: ConfirmDialogProps) {
    return (
        <Modal
            title={title}
            onClose={onCancel}
            width={440}
            footer={
                <div className="flex gap-[12px]">
                    <button
                        onClick={onCancel}
                        className="h-[48px] flex-1 rounded-[16px] border-2 border-white/10 bg-white/5 text-[16px] font-medium tracking-[-0.64px] text-white transition-colors hover:bg-white/10"
                    >
                        {cancelLabel ?? t("modals.cancel")}
                    </button>
                    <div className="flex-1">
                        <PrimaryButton onClick={onConfirm}>
                            {confirmLabel ?? t("modals.confirm")}
                        </PrimaryButton>
                    </div>
                </div>
            }
        >
            <p className="text-[15px] leading-[1.5] tracking-[-0.3px] text-white/60">
                {message}
            </p>
        </Modal>
    );
}
