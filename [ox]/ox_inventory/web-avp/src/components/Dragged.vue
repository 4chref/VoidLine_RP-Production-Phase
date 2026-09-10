<template>
    <div ref="draggedRef" v-if="draggedStore.DraggedItem" :style="{
            width: inventoryStore.getItemWidthVW(
                draggedStore.DraggedItem.iData.height,
                draggedStore.DraggedItem.iData.width,
                draggedStore.DraggedItem.isRotated
            ),
            height: inventoryStore.getItemHeightVW(
                draggedStore.DraggedItem.iData.height,
                draggedStore.DraggedItem.iData.width,
                draggedStore.DraggedItem.isRotated
            ),
            backgroundColor: (draggedStore.DraggedItem.iData.rarityColor && settingsStore.Settings.raritycolors) ? `rgba(${draggedStore.DraggedItem.iData.rarityColor[0]}, ${draggedStore.DraggedItem.iData.rarityColor[1]}, ${draggedStore.DraggedItem.iData.rarityColor[2]}, ${draggedStore.DraggedItem.iData.rarityColor[3]})` : ''
        }" class="inventory-item dragged">
        <div :style="{
                backgroundImage: `url(../images/${draggedStore.DraggedItem.item.meta?.imageName ?? draggedStore.DraggedItem.item.item}.png)`
            }" :class="draggedStore.DraggedItem.isRotated ? 'item-image rotated' : 'item-image'"></div>

        <div v-if="settingsStore.Settings.show_itemnames"
            :class="draggedStore.DraggedItem.isRotated ? 'item-name rotated' : 'item-name'">
            {{ draggedStore.DraggedItem.iData.formatName }}
        </div>
        <div v-if="draggedStore.DraggedItem.iData.isStackable" class="item-quantity">
            {{ draggedStore.movedQuantity }}
        </div>
    </div>
</template>

<script lang="ts" setup>
import { nextTick, onUnmounted, ref, watch } from 'vue';
import { useInventory } from '../store/inventory.store';
import { useDraggedStore } from '../store/dragged.store';
import { AxiosInstance } from '../plugins/axios.plugin';
import { useSettingsStore } from '../store/settings.store';

const inventoryStore = useInventory();
const draggedStore = useDraggedStore();
const settingsStore = useSettingsStore();

const draggedRef = ref<HTMLElement | null>(null);

const mouseMove = (ev: MouseEvent) => {
    const el = draggedRef.value;
    if (el) {
        const width = el.offsetWidth;
        const height = el.offsetHeight;

        el.style.left = ev.clientX - (width / 2) + 'px';
        el.style.top = ev.clientY - (height / 2) + 'px';
    }
}

const keyPress = (ev: KeyboardEvent) => {
    if (ev.key.toLowerCase() == "r" && draggedStore.DraggedItem) {
        draggedStore.DraggedItem.isRotated = !draggedStore.DraggedItem.isRotated;

        nextTick(() => {
            let event = new MouseEvent("mousemove", {
                clientX: inventoryStore.store.cursorX,
                clientY: inventoryStore.store.cursorY
            });
            document.dispatchEvent(event);
        });
    }
}

const mouseUp = (ev: MouseEvent) => {
    if (draggedStore.DraggedItem && inventoryStore.store.placingAtXY && inventoryStore.store.hoveredInventoryUniqueId) {
        AxiosInstance.post("DRAGGED_ITEM_MOVE", {
            grabbedFromInventoryUniqueID: draggedStore.DraggedItem.iUniqueId,
            grabbedItemHash: draggedStore.DraggedItem.item.itemHash,
            dropToX: inventoryStore.store.placingAtXY.x,
            dropToY: inventoryStore.store.placingAtXY.y,
            toInventoryUniqueID: inventoryStore.store.hoveredInventoryUniqueId,
            quantity: inventoryStore.store.quantityInput,
            isRotated: draggedStore.DraggedItem.isRotated
        });

        setTimeout(() => {
            draggedStore.resetDragging();
        }, 100);
    }
    else {
        draggedStore.resetDragging();
    }
}

watch(() => draggedStore.isDragging, (isDragging) => {
    if (isDragging) {
        document.addEventListener("mousemove", mouseMove);
        document.addEventListener("keypress", keyPress);
        document.addEventListener("mouseup", mouseUp);

        nextTick(() => {
            let event = new MouseEvent("mousemove", {
                clientX: inventoryStore.store.cursorX,
                clientY: inventoryStore.store.cursorY
            });
            document.dispatchEvent(event);
        });
    }
    else {
        document.removeEventListener("mousemove", mouseMove);
        document.removeEventListener("keypress", keyPress);
        document.removeEventListener("mouseup", mouseUp);
    }
});

onUnmounted(() => {
    document.removeEventListener("mousemove", mouseMove);
    document.removeEventListener("keypress", keyPress);
    document.removeEventListener("mouseup", mouseUp);
});

</script>

<style lang="scss" scoped>
.dragged {
    position: absolute;
    z-index: 9999;
    pointer-events: none;
}
</style>