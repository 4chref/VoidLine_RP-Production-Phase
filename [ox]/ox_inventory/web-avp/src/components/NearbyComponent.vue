<template>
    <Transition
        :enter-active-class="settingsStore.Settings.animations ? 'animate__animated animate__faster animate__bounceIn' : undefined"
        :leave-active-class="settingsStore.Settings.animations ? 'animate__animated animate__faster animate__bounceOut' : undefined">
        <div v-if="nearbyStore.isOpened" ref="nearbyRef" class="nearby-component-parent" :style="{
            left: typeof componentX === 'number' ? (componentX + 'px') : '',
            top: typeof componentY === 'number' ? (componentY + 'px') : ''
        }">
            <div @mousedown.prevent.left="handleMouseDown" class="nearby-component-header">
                <MacCloseButton v-on:click="nearbyStore.isOpened = false" />
                Nearby Players
                <i style="position:absolute; left: .5vw;" class="fa-solid fa-users"></i>
            </div>

            <div class="nearby-content-wrapper">
                <div @click.prevent.left="nearbyStore.give(a.serverId)" class="nearby-entry"
                    v-for="a in nearbyStore.nearPlayers">
                    <i class="fa-solid fa-chevron-right"></i>
                    [{{ a.serverId }}] {{ a.name }}
                </div>
            </div>

        </div>
    </Transition>
</template>

<script lang="ts" setup>
import { onMounted, ref } from 'vue';
import { useNearbyStore } from '../store/nearby.store';
import { useSettingsStore } from '../store/settings.store';
import MacCloseButton from './MacCloseButton.vue';

const settingsStore = useSettingsStore();
const nearbyStore = useNearbyStore();

const nearbyRef = ref<HTMLElement | null>(null);

let isMoving = false;
let offsetX = 0;
let offsetY = 0;

const componentX = ref<number | null>(null);
const componentY = ref<number | null>(null);

onMounted(() => {
    const savedX = localStorage.getItem("nearby_savedX");
    const savedY = localStorage.getItem("nearby_savedY");

    if (savedX != null && savedY != null) {
        componentX.value = Number(savedX);
        componentY.value = Number(savedY);
    }
});

const handleMouseDown = (ev: MouseEvent) => {
    if (isMoving) return;

    isMoving = true;

    window.addEventListener("mouseup", handleMouseUp);
    window.addEventListener("mousemove", handleMouseMove);

    const element = nearbyRef.value;
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
        localStorage.setItem("nearby_savedX", componentX.value.toString());
        localStorage.setItem("nearby_savedY", componentY.value.toString());
    }
}

const handleMouseMove = (ev: MouseEvent) => {
    if (!isMoving) return;

    const element = nearbyRef.value;
    if (element) {
        componentX.value = ev.clientX + offsetX - element.offsetWidth;
        componentY.value = ev.clientY + offsetY - element.offsetHeight;
    }
}

</script>

<style lang="scss" scoped>
$textstroke: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000;
$BACKGROUND: rgba(25, 25, 25, .85);

.nearby-component-parent {
    position: absolute;
    z-index: 99999;
    width: 15vw;
    background-color: $BACKGROUND;
    border-radius: .5vw;
    border: .1vw solid black;
    box-shadow: 0 0 .5vw rgba(0, 0, 0, .55);

    .nearby-content-wrapper {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: .5vw 0;
        max-height: 20vw;
        overflow: auto;

        .nearby-entry {
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

            &:hover {
                background-color: lighten(rgba(25, 25, 25, .5), 10%);
            }

            i {
                font-size: .5vw;
                color: grey;
                margin-right: .35vw;
            }
        }
    }

    .nearby-component-header {
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
}
</style>