import { useState } from "react";
import type { ForecastEntry, WeatherType } from "@/types";
import { defaultTemp, formatCastTime } from "@/utils/weather";
import { t, tWeather } from "@/utils/locale";
import Modal from "@/components/ui/Modal";
import WeatherSelect from "@/components/ui/WeatherSelect";
import TempInput from "@/components/ui/TempInput";
import TimeInput from "@/components/ui/TimeInput";
import InfoBanner from "@/components/ui/InfoBanner";
import PrimaryButton from "@/components/ui/PrimaryButton";
import FieldLabel from "@/components/ui/FieldLabel";

interface EditWeatherModalProps {
    entry: ForecastEntry;
    onClose: () => void;
    onSave: (entry: ForecastEntry) => void;
}

// Figma: node 1-588 (Edit Weather).
export default function EditWeatherModal({ entry, onClose, onSave }: EditWeatherModalProps) {
    const [weather, setWeather] = useState<WeatherType>(entry.weather);
    const [temp, setTemp] = useState<number | "">(entry.temperature);
    const [hour, setHour] = useState(entry.atHour);
    const [minute, setMinute] = useState(entry.atMinute);

    const save = () => {
        onSave({
            weather,
            temperature: temp === "" ? defaultTemp(weather) : temp,
            atHour: hour,
            atMinute: minute,
        });
    };

    return (
        <Modal
            title={t("modals.editTitle")}
            onClose={onClose}
            footer={<PrimaryButton onClick={save}>{t("modals.editCta")}</PrimaryButton>}
        >
            <FieldLabel>{t("modals.selectType")}</FieldLabel>
            <WeatherSelect value={weather} onChange={setWeather} />

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

            <InfoBanner>
                {t("modals.currentlyAt", {
                    weather: tWeather(entry.weather),
                    time: formatCastTime(entry.atHour, entry.atMinute),
                })}
            </InfoBanner>
        </Modal>
    );
}
