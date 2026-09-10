<template>
    <Transition
        :enter-active-class="settingsStore.Settings.animations ? 'animate__animated animate__fadeInUp animate__faster' : undefined"
        :leave-active-class="settingsStore.Settings.animations ? 'animate__animated animate__fadeOutDown animate__faster' : undefined">
        <div v-if="inventoryStore.store.shortkeysOpened" class="shortkeys-parent">
            <div class="shortkey-entry" v-for="idx in 5" :style="{
                    width: settingsStore.Settings.shortkey_size + 'vw',
                    height: settingsStore.Settings.shortkey_size + 'vw'
                }">
                <div class="shortkey-key">{{ idx }}</div>

                <template v-if="slots[idx]">
                    <div class="shortkey-img" :style="{
                            backgroundImage: `url(../images/${slots[idx]?.meta.imageName ?? slots[idx]?.item}.png)`
                        }"></div>

                    <div class="shortkey-quantity">x{{ slots[idx]?.quantity }}</div>
                </template>
            </div>
        </div>
    </Transition>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { useInventory } from '../store/inventory.store';
import { useSettingsStore } from '../store/settings.store';
import { I_Item } from '../types/item';

const settingsStore = useSettingsStore();
const inventoryStore = useInventory();

const WearedItems = computed(() => {
    return inventoryStore.playerInventory?.items.filter(a => typeof a.slotGUID === 'string');
});

const slots = computed<Record<number, I_Item | undefined>>(() => {
    // VoidLine: AVP kept hotbar entries as "worn" items carrying a slotGUID.
    // ox has no such concept -- client.lua binds hotkey<i> straight to
    // useSlot(i), so pressing 1 uses inventory slot 1. The overlay therefore
    // mirrors inventory slots 1-5 and nothing else needs to change for the
    // keys to work.
    const inv = inventoryStore.playerInventory;
    const at = (n: number) => inv?.items.find(a => a.itemHash === `ox-player:${n}`);

    return { 1: at(1), 2: at(2), 3: at(3), 4: at(4), 5: at(5) };
});

</script>

<style lang="scss" scoped>
// $SHORTKEY_SIZE: 3.5vw;

.shortkeys-parent {
    position: absolute;
    bottom: 3%;
    display: flex;
    flex-direction: row;

    .shortkey-entry {
        position: relative;
        background-color: rgba(20, 20, 20, .55);
        border: .1vw solid rgba(135, 135, 135, .55);
        // height: $SHORTKEY_SIZE;
        // width: $SHORTKEY_SIZE;
        margin: 0 .2vw;
        display: flex;
        justify-content: center;
        align-items: center;

        .shortkey-key {
            position: absolute;
            color: rgb(220, 220, 220);
            font-size: .6vw;
            top: -.65vw;
            padding: .15vw .25vw;
            background-color: rgba(0, 0, 0, .35);
        }

        .shortkey-img {
            position: relative;
            width: 80%;
            height: 80%;
            background-position: center;
            background-size: contain;
            background-repeat: no-repeat;
        }

        .shortkey-quantity {
            position: absolute;
            font-size: .55vw;
            color: rgb(220, 220, 220);
            bottom: 0;
            left: 0;
            padding: .15vw .25vw;
        }
    }
}
</style>