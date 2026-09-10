import { defineStore } from "pinia";
import { computed, nextTick, ref, watch } from "vue";
import { useInventory } from "./inventory.store";
import { useItemsStore } from "./items.store";
import { useSettingsStore } from "./settings.store";
import { selectSound } from "../plugins/audio.plugin";
import { I_Item } from "../types/item";
import { I_ItemData } from "../types/item_data";

export const useDraggedStore = defineStore("DraggedStore", () => {

    const inventoryStore = useInventory();
    const itemsStore = useItemsStore();
    const settingsStore = useSettingsStore();

    const DraggedItem = ref<{
        item: I_Item;
        iData: I_ItemData;
        isRotated: boolean;
        iUniqueId: string;
    } | null>(null);

    const isDragging = ref(false);

    const grabInterval = ref<null | NodeJS.Timer>(null);

    const startDragging = (item: I_Item, iUniqueId: string, iData: I_ItemData) => {
        DraggedItem.value = {
            item: item,
            isRotated: item.isRotated,
            iUniqueId: iUniqueId,
            iData: iData
        }

        isDragging.value = true;

        if (settingsStore.Settings.sfx) {
            selectSound();
        }
    }

    const resetDragging = () => {
        DraggedItem.value = null;
        isDragging.value = false;
        inventoryStore.store.placingAtXY = null;
        inventoryStore.store.over = null;
    }

    function startDragInterval() {
        if (grabInterval.value !== null) return;

        grabInterval.value = setInterval(() => {
            const $draggedHtml = document.querySelector(".inventory-item.dragged");
            const offset = $draggedHtml?.getBoundingClientRect();
            if (!offset) return;

            if (!DraggedItem.value) {
                resetDragging();
                return;
            }

            const left = offset.left + 10;
            const top = offset.top + 10;

            // VoidLine: resolve the slot by walking up to the nearest element
            // that actually carries coordinates.
            //
            // This used to test `className.includes('item')`, which also matches
            // an item's own children -- item-image, item-name, item-weight,
            // item-quantity -- and none of those carry data-x/data-y.
            // Number(null) is 0, so dropping anywhere over an existing item's
            // artwork or label silently resolved to slot 0,0 and the item jumped
            // to the top-left corner.
            const element = document.elementFromPoint(left, top);
            const slot = element?.closest("[data-x][data-y]") as HTMLElement | null;

            if (slot) {
                const x = Number(slot.getAttribute("data-x"));
                const y = Number(slot.getAttribute("data-y"));

                // Guard the parse too: a malformed attribute must not fall
                // through as 0 the way it did before.
                if (Number.isFinite(x) && Number.isFinite(y) && isSlotAvailableInInventory(x, y)) {
                    const width = DraggedItem.value.isRotated ? DraggedItem.value.iData.height : DraggedItem.value.iData.width;
                    const height = DraggedItem.value.isRotated ? DraggedItem.value.iData.width : DraggedItem.value.iData.height;

                    // VoidLine: only write when the target actually changed.
                    // Both of these are read by every grid cell's class binding,
                    // so reassigning them on each tick re-rendered all 150 cells
                    // continuously for the whole drag -- the source of the lag.
                    const at = inventoryStore.store.placingAtXY;
                    if (!at || at.x !== x || at.y !== y) {
                        inventoryStore.store.placingAtXY = { x, y };
                        inventoryStore.store.over = {
                            minX: x,
                            maxX: x + width - 1,
                            minY: y,
                            maxY: y + height - 1
                        };
                    }

                    // return importatnt here.
                    return;
                }
            }

            if (inventoryStore.store.over !== null || inventoryStore.store.placingAtXY !== null) {
                inventoryStore.store.over = null;
                inventoryStore.store.placingAtXY = null;
            }
        }, settingsStore.Settings.dragspeed);
    }

    function stopDragInterval() {
        if (grabInterval.value !== null) {
            clearInterval(grabInterval.value);
            grabInterval.value = null;
        }

        inventoryStore.store.over = null;
    }

    const isSlotAvailableInInventory = (x: number, y: number) => {
        if (!DraggedItem.value) return;
        if (!inventoryStore.store.hoveredInventoryUniqueId) return;

        const grabbedItemWidth = DraggedItem.value.isRotated ? DraggedItem.value.iData.height : DraggedItem.value.iData.width;
        const grabbedItemHeight = DraggedItem.value.isRotated ? DraggedItem.value.iData.width : DraggedItem.value.iData.height;
        const hoveredInventoryID = inventoryStore.store.hoveredInventoryUniqueId;
        const hoveredInventory = inventoryStore.getInventoryWithUniqueID(hoveredInventoryID);

        if (!hoveredInventory) return;

        const occupiedSlots = new Set();

        const hovered_inventory_items = hoveredInventory.items.filter(a => typeof a.slotGUID !== 'string');

        for (let i = 0; i < hovered_inventory_items.length; i++) {
            const item = hovered_inventory_items[i];

            /** Skip if its the same. */
            if (!DraggedItem.value.iData.isStackable &&
                DraggedItem.value.item.itemHash == item?.itemHash
            ) continue;

            /** Skip if grabbed all. */
            if (typeof movedQuantity.value == 'number' && DraggedItem.value.item.itemHash == item.itemHash &&
                movedQuantity.value >= item.quantity
            )
                continue;

            /** Skip if it can stack */
            if (
                DraggedItem.value.item.itemHash != item.itemHash &&
                DraggedItem.value.iData.isStackable &&
                DraggedItem.value.item.item == item?.item &&
                item?.x == x &&
                item?.y == y
            ) continue;

            const $definedItem = itemsStore.getItemData(item.item);
            if (!$definedItem) continue;

            const $itemWidth = item.isRotated ? $definedItem.height : $definedItem.width;
            const $itemHeight = item.isRotated ? $definedItem.width : $definedItem.height;

            for (let x = item.x; x < item.x + $itemWidth; x++) {
                for (let y = item.y; y < item.y + $itemHeight; y++) {
                    occupiedSlots.add(`${x},${y}`);
                }
            }
        }

        let xOverflow = x + grabbedItemWidth > hoveredInventory.x;
        let yOverflow = y + grabbedItemHeight > hoveredInventory.y;
        if (!xOverflow && !yOverflow) {
            let isEmpty = true;
            for (let widthCounter = 0; widthCounter < grabbedItemWidth; widthCounter++) {
                for (let heightCounter = 0; heightCounter < grabbedItemHeight; heightCounter++) {
                    if (occupiedSlots.has(`${x + widthCounter},${y + heightCounter}`)) {
                        isEmpty = false;
                        break;
                    }
                }
            }

            if (isEmpty) {
                return true;
            }
        }
    }

    watch(() => inventoryStore.interfaceOpened, (isOpened) => {
        if (!isOpened) resetDragging();
    });

    watch(isDragging, (newValue) => {
        if (newValue) {
            startDragInterval();
        }
        else {
            stopDragInterval();
        }
    });

    const movedQuantity = computed(() => {
        if (DraggedItem.value) {
            let amount = DraggedItem.value.item.quantity;

            const quantInput = inventoryStore.store.quantityInput;

            if (typeof quantInput == 'string' || quantInput > amount || (typeof quantInput == 'number' && quantInput < 1))
                amount = DraggedItem.value.item.quantity;
            else
                amount = quantInput;

            return amount;
        }
    });

    return {
        isDragging,
        DraggedItem,
        startDragging,
        resetDragging,
        movedQuantity
    }
});