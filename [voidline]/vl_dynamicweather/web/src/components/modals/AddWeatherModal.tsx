import { useState } from "react";
import type { ForecastEntry, WeatherType } from "@/types";
import { defaultTemp, formatCastTime } from "@/utils/weather";
import { t } from "@/utils/locale";
import Modal from "@/components/ui/Modal";
import WeatherSelect from "@/components/ui/WeatherSelect";
import TempInput from "@/components/ui/TempInput";
import TimeInput from "@/components/ui/TimeInput";
import InfoBanner from "@/components/ui/InfoBanner";
import PrimaryButton from "@/components/ui/PrimaryButton";
import FieldLabel from "@/components/ui/FieldLabel";

interface AddWeatherModalProps {
    // Bir önceki çizelge girişinin saati (bilgi şeridi için)
    previousTime?: { hour: number; minute: number };
    onClose: () => void;
    onAdd: (entry: ForecastEntry) => void;
}

// Figma: node 1-1018 (Add New Weather).
export default function AddWeatherModal({ previousTime, onClose, onAdd }: AddWeatherModalProps) {
    const [weather, setWeather] = useState<WeatherType>();
    const [temp, setTemp] = useState<number | "">("");
    const [hour, setHour] = useState(previousTime ? (previousTime.hour + 1) % 24 : 12);
    const [minute, setMinute] = useState(previousTime?.minute ?? 0);

    const add = () => {
        if (!weather) return;
        onAdd({
            weather,
            temperature: temp === "" ? defaultTemp(weather) : temp,
            atHour: hour,
            atMinute: minute,
        });
    };

    return (
        <Modal
            title={t("modals.addTitle")}
            onClose={onClose}
            footer={
                <PrimaryButton onClick={add} disabled={!weather}>
                    {t("modals.addWeatherCta")}
                </PrimaryButton>
            }
        >
            <FieldLabel>{t("modals.selectType")}</FieldLabel>
            <WeatherSelect
                value={weather}
                onChange={(w) => {
                    setWeather(w);
                    if (temp === "") setTemp(defaultTemp(w));
                }}
            />

            <FieldLabel>{t("modals.temperature")}</FieldLabel>
            <TempInput value={temp} onChange={setTemp} />

            <FieldLabel>{t("modals.time")}</FieldLabel>
            <TimeInput
                hour={hour}
                minute={minute}
                onChange={(h, m) => {
                    setHour(h);
                    setMinute(m);
                }}
            />

            {previousTime && (
                <InfoBanner>
                    {t("modals.prevCastTime", {
                        time: formatCastTime(previousTime.hour, previousTime.minute),
                    })}
                </InfoBanner>
            )}
        </Modal>
    );
}
