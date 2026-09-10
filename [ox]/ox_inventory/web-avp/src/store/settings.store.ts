import { defineStore } from "pinia";
import { ref, watch } from "vue";
import { AxiosInstance } from "../plugins/axios.plugin";

interface SettingsState {
    sfx: boolean;
    animations: boolean;
    slotsize: number;
    slotborder: number;
    dragspeed: number;
    show_weight: boolean;
    show_brokenicon: boolean;
    raritycolors: boolean;
    show_itemnames: boolean;
    customnames: boolean;
    blur: boolean;
    screenfx: boolean;
    displayradar: boolean;
    shortkey_size: number;
}

export const useSettingsStore = defineStore("SettingsStore", () => {

    const isOpened = ref(false);

    const DEFAULTS: SettingsState = {
        sfx: true,
        animations: true,
        slotsize: 2.0,
        slotborder: 0.1,
        dragspeed: 100,
        show_weight: true,
        show_brokenicon: true,
        raritycolors: true,
        show_itemnames: true,
        customnames: true,
        blur: true,
        screenfx: true,
        displayradar: false,
        shortkey_size: 2.5
    }

    const Settings = ref<SettingsState>({
        sfx: DEFAULTS.sfx,
        animations: DEFAULTS.animations,
        slotsize: DEFAULTS.slotsize,
        slotborder: DEFAULTS.slotborder,
        dragspeed: DEFAULTS.dragspeed,
        show_weight: DEFAULTS.show_weight,
        show_brokenicon: DEFAULTS.show_brokenicon,
        raritycolors: DEFAULTS.raritycolors,
        show_itemnames: DEFAULTS.show_itemnames,
        customnames: DEFAULTS.customnames,
        blur: DEFAULTS.blur,
        screenfx: DEFAULTS.screenfx,
        displayradar: DEFAULTS.displayradar,
        shortkey_size: DEFAULTS.shortkey_size
    });

    function applyBooleanSetting(storageName: string, storeName: string, defaultValue: boolean) {
        const local = localStorage.getItem(storageName);
        // @ts-ignore
        if (local == 'true') Settings.value[storeName] = true;
        // @ts-ignore
        else if (local == 'false') Settings.value[storeName] = false;
        // @ts-ignore
        else Settings.value[storeName] = defaultValue;
    }

    function applyNumberSetting(storageName: string, storeName: String, defaultValue: number) {
        const local = localStorage.getItem(storageName);
        // @ts-ignore
        if (local != null) Settings.value[storeName] = Number(local);
        // @ts-ignore
        else Settings.value[storeName] = defaultValue;
    }

    watch(() => Settings.value.displayradar, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_displayradar", "displayradar", DEFAULTS.displayradar);
        }
        else {
            localStorage.setItem("settings_displayradar", newValue.toString());
        }

        AxiosInstance.post("SETTINGS_RADAR_ENABLED", newValue);
    }, { immediate: true });

    watch(() => Settings.value.screenfx, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_screenfx", "screenfx", DEFAULTS.screenfx);
        }
        else {
            localStorage.setItem("settings_screenfx", newValue.toString());
        }

        AxiosInstance.post("SETTINGS_SCREENFX_ENABLED", newValue);
    }, { immediate: true });

    watch(() => Settings.value.blur, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_blur", "blur", DEFAULTS.blur);
        }
        else {
            localStorage.setItem("settings_blur", newValue.toString());
        }

        AxiosInstance.post("SETTINGS_BLUR_ENABLED", newValue);
    }, { immediate: true });

    watch(() => Settings.value.sfx, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_sfx", "sfx", DEFAULTS.sfx);
        }
        else {
            localStorage.setItem("settings_sfx", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.animations, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_animation", "animations", DEFAULTS.animations);
        }
        else {
            localStorage.setItem("settings_animation", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.raritycolors, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_raritycolors", "raritycolors", DEFAULTS.raritycolors);
        }
        else {
            localStorage.setItem("settings_raritycolors", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.customnames, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_customnames", "customnames", DEFAULTS.customnames);
        }
        else {
            localStorage.setItem("settings_customnames", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.show_itemnames, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_itemnames", "itemnames", DEFAULTS.show_itemnames);
        }
        else {
            localStorage.setItem("settings_itemnames", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.slotsize, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyNumberSetting("settings_slotsize", "slotsize", DEFAULTS.slotsize);
        }
        else {
            localStorage.setItem("settings_slotsize", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.shortkey_size, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyNumberSetting("settings_shortkey_size", "shortkey_size", DEFAULTS.shortkey_size);
        }
        else {
            localStorage.setItem("settings_shortkey_size", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.slotborder, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyNumberSetting("settings_slotborder", "slotborder", DEFAULTS.slotborder)
        }
        else {
            localStorage.setItem("settings_slotborder", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.dragspeed, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyNumberSetting("settings_dragspeed", "dragspeed", DEFAULTS.dragspeed);
        }
        else {
            localStorage.setItem("settings_dragspeed", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.show_weight, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_show_weight", "show_weight", DEFAULTS.show_weight);
        }
        else {
            localStorage.setItem("settings_show_weight", newValue.toString());
        }
    }, { immediate: true });

    watch(() => Settings.value.show_brokenicon, (newValue, oldValue) => {
        if (oldValue == undefined) {
            applyBooleanSetting("settings_show_brokenicon", "show_brokenicon", DEFAULTS.show_brokenicon);
        }
        else {
            localStorage.setItem("settings_show_brokenicon", newValue.toString());
        }
    }, { immediate: true });

    function Reset() {
        localStorage.clear();

        for (const key in Settings.value) {
            // @ts-ignore
            if (DEFAULTS[key] != undefined) {
                //@ts-ignore
                Settings.value[key] = DEFAULTS[key];
            }
        }
    }

    function ResetStorage() {
        localStorage.clear();
    }

    return {
        isOpened,
        Settings,
        Reset,
        ResetStorage
    }
});