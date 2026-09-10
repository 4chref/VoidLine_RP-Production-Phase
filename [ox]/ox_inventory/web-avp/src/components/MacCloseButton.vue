<template>
    <div ref="componentRef" @click.left.prevent="onClick" @mouseenter="mouseEnter" class="mac-button">
        <i>X</i>
    </div>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { hoverSound } from '../plugins/audio.plugin';
import { useSettingsStore } from '../store/settings.store';

const settingsStore = useSettingsStore();
const componentRef = ref<HTMLElement | null>(null);

const emit = defineEmits(["click"])

const mouseEnter = () => {
    if (settingsStore.Settings.sfx) {
        hoverSound();
    }
}

const onClick = () => {
    // VoidLine: the decline sound on close is gone. Hover still has its cue.
    emit("click");
}

</script>


<style lang="scss" scoped>
.mac-button {
    position: absolute;
    right: .5vw;
    background: red;
    width: .8vw;
    height: .8vw;
    border-radius: 50%;
    display: flex;
    justify-content: center;
    align-items: center;

    &:hover {
        i {
            opacity: 1;
        }
    }

    i {
        color: white;
        opacity: 0;
        font-size: .5vw;
    }
}
</style>