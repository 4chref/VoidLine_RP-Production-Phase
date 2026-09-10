import { useState } from "react";
import type { WeatherType } from "@/types";
import { defaultTemp } from "@/utils/weather";
import { t } from "@/utils/locale";
import Modal from "@/components/ui/Modal";
import WeatherSelect from "@/components/ui/WeatherSelect";
import TempInput from "@/components/ui/TempInput";
import PrimaryButton from "@/components/ui/PrimaryButton";
import FieldLabel from "@/components/ui/FieldLabel";

interface ChangeStaticWeatherModalProps {
    // Düzenlenen alanın mevcut değerleri (varsa ön-dolgu)
    initialWeather?: WeatherType;
    initialTemperature?: number;
    onClose: () => void;
    onConfirm: (weather: WeatherType, temperature: number) => void;
}

// Figma: node 1-1252 (Change Static Weather).
export default function ChangeStaticWeatherModal({
    initialWeather,
    initialTemperature,
    onClose,
    onConfirm,
}: ChangeStaticWeatherModalProps) {
    const [weather, setWeather] = useState<WeatherType | undefined>(initialWeather);
    const [temp, setTemp] = useState<number | "">(initialTemperature ?? "");

    const confirm = () => {
        if (!weather) return;
        const temperature = temp === "" ? defaultTemp(weather) : temp;
        onConfirm(weather, temperature);
    };

    return (
        <Modal
            title={t("modals.changeStaticTitle")}
            onClose={onClose}
            footer={
                <PrimaryButton onClick={confirm} disabled={!weather}>
                    {t("modals.addWeatherCta")}
                </PrimaryButton>
            }
        >
            <FieldLabel>{t("modals.selectType")}</FieldLabel>
            <WeatherSelect
                value={weather}
                onChange={(w) => {
                    setWeather(w);
                    // Sıcaklık henüz elle girilmediyse öneriyle doldur
                    if (temp === "") setTemp(defaultTemp(w));
                }}
            />

            <FieldLabel>{t("modals.temperature")}</FieldLabel>
            <TempInput value={temp} onChange={setTemp} />
        </Modal>
    );
}
