import { defineStore } from "pinia";
import { ref, watch } from "vue";
import { useInventory } from "./inventory.store";
import { I_Item } from "../types/item";

export const useContextMenuStore = defineStore("ContextMenu", () => {
    const inventoryStore = useInventory();

    const opened = ref(false);
    const coordX = ref(0);
    const coordY = ref(0);
    const selectedItem = ref<I_Item | null>(null);
    const selectedFromInventoryId = ref<string | null>(null);

    function OPEN(item: I_Item, inventoryId: string) {
        if (item?.itemHash == selectedItem.value?.itemHash) return;

        opened.value = true;
        selectedItem.value = item;
        selectedFromInventoryId.value = inventoryId;
        coordX.value = inventoryStore.store.cursorX;
        coordY.value = inventoryStore.store.cursorY;
    }

    function CLOSE() {
        opened.value = false;
        selectedItem.value = null;
        selectedFromInventoryId.value = null;
    }

    /** Reset on interface close. */
    watch(() => inventoryStore.interfaceOpened, (isOpened) => {
        if (!isOpened) CLOSE();
    });

    return {
        opened,
        coordX,
        coordY,
        selectedItem,
        selectedFromInventoryId,
        OPEN,
        CLOSE
    }
});