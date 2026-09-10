<template>
    <Transition
        :enter-active-class="settingsStore.Settings.animations ? 'animate__animated animate__faster animate__bounceIn' : undefined"
        :leave-active-class="settingsStore.Settings.animations ? 'animate__animated animate__faster animate__bounceOut' : undefined">
        <div v-if="settingsStore.isOpened" ref="settingsRef" :style="{
            left: typeof settingsX === 'number' ? (settingsX + 'px') : '',
            top: typeof settingsY === 'number' ? (settingsY + 'px') : ''
        }" class="settings-parent">
            <div @mousedown.prevent.left="handleMouseDown" class="settings-header">
                <MacCloseButton v-on:click="settingsStore.isOpened = false" />

                Settings
                <i style="position:absolute; left: .5vw;" class="fa-solid fa-gears"></i>
            </div>

            <div class="settings-wrapper">
                <div class="setting-entry">
                    <i class="fa-solid fa-volume-up"></i>
                    <div class="setting-text">Sound effects</div>
                    <Toggle class="setting-checkbox" on-label="On" off-label="Off" v-model="settingsStore.Settings.sfx" />
                </div>
                <div class="setting-entry">
                    <i class="fa-solid fa-signature"></i>
                    <div class="setting-text">Show item names</div>
                    <Toggle class="setting-checkbox" on-label="On" off-label="Off"
                        v-model="settingsStore.Settings.show_itemnames" />
                </div>
                <div class="setting-entry">
                    <i class="fa-solid fa-weight-hanging"></i>
                    <div class="setting-text">Show item weight</div>
                    <Toggle class="setting-checkbox" on-label="On" off-label="Off"
                        v-model="settingsStore.Settings.show_weight" />
                </div>
                <div class="setting-entry" style="flex-wrap: wrap;">
                    <i class="fa-solid fa-maximize"></i>
                    <div class="setting-text">Slot size</div>

                    <div class="slider-wrapper">
                        <VueSlider width="100%" height="0.4vw" tooltip="none" v-model="settingsStore.Settings.slotsize"
                            :adsorb="true" :interval="0.1" :max="3.0" :min="1.5" class="slider" />

                        <input type="number" v-model="settingsStore.Settings.slotsize">
                    </div>
                </div>
                <div class="setting-entry" style="flex-wrap: wrap;">
                    <i class="fa-solid fa-border-top-left"></i>
                    <div class="setting-text">Slot border</div>

                    <div class="slider-wrapper">
                        <VueSlider width="100%" height="0.4vw" tooltip="none" :adsorb="true"
                            v-model="settingsStore.Settings.slotborder" :interval="0.1" :max="0.3" :min="0.1"
                            class="slider" />

                        <input type="number" v-model="settingsStore.Settings.slotborder">
                    </div>
                </div>
                <div class="setting-entry" style="flex-wrap: wrap;">
                    <i class="fa-solid fa-border-top-left"></i>
                    <div class="setting-text">Shortkey size</div>

                    <div class="slider-wrapper">
                        <VueSlider width="100%" height="0.4vw" tooltip="none" :adsorb="true"
                            v-model="settingsStore.Settings.shortkey_size" :interval="0.1" :max="5" :min="1.5"
                            class="slider" />

                        <input type="number" v-model="settingsStore.Settings.shortkey_size">
                    </div>
                </div>
                <div class="setting-entry" style="flex-wrap: wrap;">
                    <i class="fa-solid fa-gauge-simple-high"></i>
                    <div class="setting-text">Drag speed (performance)</div>
                    <div class="setting-description">During dragging, checking the slots.</div>

                    <div class="slider-wrapper">
                        <VueSlider width="100%" height="0.4vw" tooltip="none" :adsorb="true"
                            v-model="settingsStore.Settings.dragspeed" :interval="10" :max="500" :min="50" class="slider" />

                        <input type="number" v-model="settingsStore.Settings.dragspeed">
                    </div>
                </div>
                <div class="setting-entry" style="flex-wrap: wrap;">
                    <i class="fa-solid fa-rotate-left"></i>
                    <div class="setting-text">Reset</div>
                    <div class="setting-description">Fully reset everything to default.</div>

                    <button class="setting-button" @click.prevent.left="settingsStore.Reset">Full Reset</button>
                </div>
            </div>
        </div>
        <div v-else @click.prevent.left="settingsStore.isOpened = true" class="settings-opener-parent">
            <i class="fa-solid fa-gear"></i> Settings
        </div>
    </Transition>
</template>

<script lang="ts" setup>
import { onMounted, ref, watch } from 'vue';
import Toggle from "@vueform/toggle";
import "@vueform/toggle/themes/default.scss"
import { useSettingsStore } from '../store/settings.store';
import VueSlider from 'vue-3-slider-component'
import MacCloseButton from './MacCloseButton.vue';
import { selectSound } from '../plugins/audio.plugin';

const settingsStore = useSettingsStore();
const settingsRef = ref<HTMLElement | null>(null);

let isMoving = false;
let offsetX = 0;
let offsetY = 0;

const settingsX = ref<number | null>(null);
const settingsY = ref<number | null>(null);

onMounted(() => {
    const savedX = localStorage.getItem("settings_savedX");
    const savedY = localStorage.getItem("settings_savedY");

    if (savedX != null && savedY != null) {
        settingsX.value = Number(savedX);
        settingsY.value = Number(savedY);
    }
});

watch(() => settingsStore.isOpened, (newValue) => {
    if (newValue && settingsStore.Settings.sfx)
        selectSound();
});

const handleMouseDown = (ev: MouseEvent) => {
    if (isMoving) return;

    isMoving = true;

    window.addEventListener("mouseup", handleMouseUp);
    window.addEventListener("mousemove", handleMouseMove);

    const element = settingsRef.value;
    if (element) {
        offsetX = element.offsetLeft + element.offsetWidth - ev.clientX;
        offsetY = element.offsetTop + element.offsetHeight - ev.clientY;
    }
}

const handleMouseUp = () => {
    isMoving = false;
    window.removeEventListener("mouseup", handleMouseUp);
    window.removeEventListener("mousemove", handleMouseMove);

    if (typeof settingsX.value === 'number' && typeof settingsY.value === 'number') {
        localStorage.setItem("settings_savedX", settingsX.value.toString());
        localStorage.setItem("settings_savedY", settingsY.value.toString());
    }
}

const handleMouseMove = (ev: MouseEvent) => {
    if (!isMoving) return;

    const element = settingsRef.value;
    if (element) {
        settingsX.value = ev.clientX + offsetX - element.offsetWidth;
        settingsY.value = ev.clientY + offsetY - element.offsetHeight;
    }
}
</script>

<style lang="scss" scoped>
$SETTINGS_BACKGROUND: rgba(25, 25, 25, .85);

.settings-opener-parent {
    position: absolute;
    top: 1.5%;
    right: 1%;
    color: white;
    font-size: .8vw;
    background-color: rgba(0, 0, 0, .55);
    padding: .35vw .6vw;

    &:hover {
        background-color: lighten(rgba(0, 0, 0, .55), 10%);
    }
}

.settings-parent {
    position: absolute;
    width: 15vw;
    background-color: $SETTINGS_BACKGROUND;
    border-radius: .5vw;
    border: .1vw solid black;
    box-shadow: 0 0 .5vw rgba(0, 0, 0, .55);
    right: 3%;
    top: 5%;
    z-index: 99999;

    .settings-header {
        position: relative;
        flex: 1;
        text-align: center;
        color: white;
        padding: .5vw 0;
        border-top-left-radius: inherit;
        border-top-right-radius: inherit;
        font-size: .8vw;
        border-bottom: .1vw solid grey;
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .settings-wrapper {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: .5vw 0;
        max-height: 30vw;
        overflow: auto;

        .setting-entry {
            width: 80%;
            position: relative;
            color: rgb(220, 220, 220);
            font-size: .75vw;
            margin: .25vw 0;
            display: flex;
            align-items: center;
            background-color: rgba(25, 25, 25, .5);
            border-radius: .25vw;
            padding: .35vw .5vw;
            border-top: .2vw groove transparent;
            border-bottom: .1vw solid transparent;
            justify-content: space-between;

            &:hover {
                background-color: lighten(rgba(25, 25, 25, .5), 10%);
            }

            .setting-button {
                color: white;
                font-size: .65vw;
                border: .1vw solid rgb(175, 175, 175);
                padding: .25vw .5vw;
                border-radius: .15vw;
                margin: .25vw;
                flex: 1;
                text-align: center;
                background: linear-gradient(180deg, rgba(100, 100, 100, 0.2), rgba(65, 65, 65, 0.2));

                &:hover {
                    border: .1vw solid lightgreen;
                }
            }

            .inputs-wrapper {
                position: relative;
                display: flex;
                align-items: center;
                justify-content: center;
                width: 100%;
                margin-top: .25vw;
            }

            input {
                position: relative;
                width: 40%;
                border: 0;
                background: transparent;
                outline: 0;
                font-size: .75vw;
                border-radius: 0.15vw;
                color: white;
                text-align: center;
                background: rgba(20, 20, 20, 0.85);
                padding: 0.15vw 0;
                margin-top: .25vw;
                margin-left: .15vw;
                margin-right: .15vw;

                &::placeholder {
                    color: rgb(120, 120, 120);
                    font-size: 0.7vw;
                }

                &::-webkit-inner-spin-button,
                &::-webkit-outer-spin-button {
                    -webkit-appearance: none;
                }
            }

            .slider-wrapper {
                position: relative;
                width: 100%;
                display: flex;
                flex-direction: column;
                padding: 0 .5vw;
                margin-top: .25vw;
                align-items: center;
            }

            i {
                height: 1vw;
                width: 1vw;
                display: flex;
                justify-content: center;
                align-items: center;
            }

            .setting-text {
                flex: 1;
                margin-left: .65vw;
                font-size: .7vw;
            }

            .setting-description {
                font-size: .55vw;
                color: grey;
                margin-top: .4vw;
            }
        }
    }
}
</style>