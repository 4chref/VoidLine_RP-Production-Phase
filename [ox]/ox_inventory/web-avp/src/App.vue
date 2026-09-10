<template>
    <ItemYield />

    <div class="center-div">
        <ShortKeys />
    </div>

    <Transition
        :enter-active-class="settingsStore.Settings.animations ? 'animate__animated animate__fadeIn animate__faster' : undefined"
        :leave-active-class="settingsStore.Settings.animations ? 'animate__animated animate__fadeOut animate__faster' : undefined">
        <div @click="contextMenuStore.CLOSE" v-if="inventoryStore.interfaceOpened" class="center-div">

            <Dragged />
            <Clothes />
            <Settings />
            <ContextMenu />
            <InputComponent />
            <NearbyComponent />

            <!-- RENDERING OPENED INVENTORIES -->
            <Inventory v-for="inventory in inventoryStore.inventories" :inventory="inventory" />
        </div>
    </Transition>
</template>

<script lang="ts" setup>
import { onMounted } from "vue";
import { AxiosInstance } from "./plugins/axios.plugin";
import { useInventory } from './store/inventory.store';
import Clothes from "./views/Clothes.vue";
import Dragged from "./components/Dragged.vue";
import ContextMenu from "./components/ContextMenu.vue";
import { useContextMenuStore } from "./store/contextmenu.store";
import Inventory from "./views/Inventory.vue";
import Settings from "./components/Settings.vue";
import { useSettingsStore } from "./store/settings.store";
import InputComponent from "./components/InputComponent.vue";
import NearbyComponent from "./components/NearbyComponent.vue";
import ItemYield from "./components/ItemYield.vue";
import ShortKeys from "./components/ShortKeys.vue";

const inventoryStore = useInventory();
const contextMenuStore = useContextMenuStore();
const settingsStore = useSettingsStore();

onMounted(() => {
    AxiosInstance.post("CEF_LOADED");
});

</script>