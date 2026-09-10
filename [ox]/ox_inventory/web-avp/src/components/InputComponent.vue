<template>
    <Transition
        :enter-active-class="settingsStore.Settings.animations ? 'animate__animated animate__faster animate__bounceIn' : undefined"
        :leave-active-class="settingsStore.Settings.animations ? 'animate__animated animate__faster animate__bounceOut' : undefined">
        <div v-if="inputStore.isOpened" ref="componentRef" class="input-component-parent" :style="{
            left: typeof componentX === 'number' ? (componentX + 'px') : '',
            top: typeof componentY === 'number' ? (componentY + 'px') : ''
        }">
            <div @mousedown.prevent.left="handleMouseDown" class="input-component-header">
                <MacCloseButton v-on:click="inputStore.isOpened = false" />
                {{ inputStore.store.headerLabel }}
                <i style="position:absolute; left: .5vw;" class="fa-solid fa-keyboard"></i>
            </div>

            <div class="input-component-wrapper">
                <div v-if="inputStore.store.description && inputStore.store.descriptionHtml"
                    v-html="inputStore.store.description" class="input-component-description">
                </div>
                <div v-if="inputStore.store.description && !inputStore.store.descriptionHtml"
                    class="input-component-description">
                    {{ inputStore.store.description }}
                </div>

                <input @keyup.enter.prevent="inputStore.accept" ref="inputRef" type="text"
                    v-model="inputStore.store.nameInput">

                <div class="buttons-wrapper">
                    <button v-if="inputStore.store.hasCancel" @click.prevent.left="inputStore.cancel">{{
                        inputStore.store.cancelLabel
                    }}</button>
                    <button v-if="inputStore.store.hasAccept" @click.prevent.left="inputStore.accept">{{
                        inputStore.store.acceptLabel
                    }}</button>
                </div>
            </div>
        </div>
    </Transition>
</template>

<script lang="ts" setup>
import { nextTick, onMounted, ref, watch } from 'vue';
import { useInputStore } from "../store/input.store";
import { useSettingsStore } from '../store/settings.store';
import MacCloseButton from './MacCloseButton.vue';

const inputStore = useInputStore();
const settingsStore = useSettingsStore();

const componentRef = ref<HTMLElement | null>(null);

let isMoving = false;
let offsetX = 0;
let offsetY = 0;

const componentX = ref<number | null>(null);
const componentY = ref<number | null>(null);

const inputRef = ref<HTMLElement | null>(null);

onMounted(() => {
    const savedX = localStorage.getItem("input_savedX");
    const savedY = localStorage.getItem("input_savedY");

    if (savedX != null && savedY != null) {
        componentX.value = Number(savedX);
        componentY.value = Number(savedY);
    }
});

watch(() => inputStore.isOpened, (newState) => {
    if (newState) {
        nextTick(() => {
            if (inputRef.value) {
                inputRef.value.focus();
            }
        });
    }
});

const handleMouseDown = (ev: MouseEvent) => {
    if (isMoving) return;

    isMoving = true;

    window.addEventListener("mouseup", handleMouseUp);
    window.addEventListener("mousemove", handleMouseMove);

    const element = componentRef.value;
    if (element) {
        offsetX = element.offsetLeft + element.offsetWidth - ev.clientX;
        offsetY = element.offsetTop + element.offsetHeight - ev.clientY;
    }
}

const handleMouseUp = () => {
    isMoving = false;
    window.removeEventListener("mouseup", handleMouseUp);
    window.removeEventListener("mousemove", handleMouseMove);

    if (typeof componentX.value === 'number' && typeof componentY.value === 'number') {
        localStorage.setItem("input_savedX", componentX.value.toString());
        localStorage.setItem("input_savedY", componentY.value.toString());
    }
}

const handleMouseMove = (ev: MouseEvent) => {
    if (!isMoving) return;

    const element = componentRef.value;
    if (element) {
        componentX.value = ev.clientX + offsetX - element.offsetWidth;
        componentY.value = ev.clientY + offsetY - element.offsetHeight;
    }
}

</script>


<style lang="scss" scoped>
$textstroke: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000;
$BACKGROUND: rgba(25, 25, 25, .85);

.input-component-parent {
    position: absolute;
    z-index: 99999;
    width: 15vw;
    background-color: $BACKGROUND;
    border-radius: .5vw;
    border: .1vw solid black;
    box-shadow: 0 0 .5vw rgba(0, 0, 0, .55);

    .input-component-header {
        position: relative;
        flex: 1;
        text-align: center;
        color: white;
        padding: .35vw 0;
        border-top-left-radius: inherit;
        border-top-right-radius: inherit;
        font-size: .8vw;
        border-bottom: .1vw solid grey;
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .input-component-wrapper {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: .5vw 0;

        .input-component-description {
            position: relative;
            font-size: .7vw;
            color: rgb(220, 220, 220);
            margin: .35vw 0;
            white-space: pre-wrap;
            text-align: center;
        }

        input {
            position: relative;
            width: 85%;
            background: transparent;
            border: .1vw solid rgba(128, 128, 128, .7);
            outline: 0;
            font-size: .75vw;
            border-radius: 0.15vw;
            color: white;
            text-align: center;
            background: rgba(20, 20, 20, 0.85);
            padding: 0.25vw 0;
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

        .buttons-wrapper {
            width: 75%;
            display: flex;
            margin-top: .5vw;

            button {
                flex: 1;
                outline: 0;
                border: 0;
                margin: 0 .25vw;
                background: rgba(20, 20, 20, 0.85);
                color: rgb(220, 220, 220);
                font-size: .75vw;
                padding: .25vw .5vw;
                border-radius: .25vw;

                &:hover {
                    background-color: lighten(rgba(20, 20, 20, 0.85), 20%);
                }
            }
        }
    }
}
</style>