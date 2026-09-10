<template>
    <div v-if="item && cachedItemData" @mouseenter.prevent="MouseEnter" @contextmenu.prevent="rightClick"
        @mouseup.prevent.left="MouseUp" @mousedown.prevent.left="startDragItem" :style="{
                width: inventoryStore.getItemWidthVW(cachedItemData.height, cachedItemData.width, item.isRotated),
                height: inventoryStore.getItemHeightVW(cachedItemData.height, cachedItemData.width, item.isRotated),
                visibility: isVisible ? 'visible' : 'hidden',
                backgroundColor: (cachedItemData.rarityColor && settingsStore.Settings.raritycolors) ? `rgba(${cachedItemData.rarityColor[0]}, ${cachedItemData.rarityColor[1]}, ${cachedItemData.rarityColor[2]}, ${cachedItemData.rarityColor[3]})` : '',
                opacity: itemOpacity
            }" v-isbag :data-x="item.x" :data-y="item.y" :data-item="true" class="inventory-item" ref="itemRef">

        <div :style="{
                // VoidLine: was `items/...` (AVP shipped its own icon folder). ox already
                // serves 366 icons from web/images and uses the same <item name>.png
                // convention, so this points there instead of duplicating 12MB.
                backgroundImage: `url(../images/${item.meta?.imageName ?? item.item}.png)`
            }" :class="item.isRotated ? 'item-image rotated' : 'item-image'"></div>

        <i v-if="settingsStore.Settings.show_brokenicon && isBroken" class="fa-solid fa-gear broken-icon"></i>

        <div v-if="settingsStore.Settings.show_weight" class="item-weight">{{ itemWeight }} kg</div>

        <div v-if="settingsStore.Settings.show_itemnames" :class="item.isRotated ? 'item-name rotated' : 'item-name'">
            {{
                settingsStore.Settings.customnames ? item.meta.customName || cachedItemData.formatName :
                cachedItemData.formatName
            }}
        </div>

        <div v-if="cachedItemData.isStackable" class="item-quantity">x{{ item.quantity }}</div>
    </div>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { AxiosInstance } from '../plugins/axios.plugin';
import { useContextMenuStore } from '../store/contextmenu.store';
import { useDraggedStore } from '../store/dragged.store';
import { useInventory } from '../store/inventory.store';
import { useItemsStore } from '../store/items.store';
import { useSettingsStore } from '../store/settings.store';

import { hoverSound } from '../plugins/audio.plugin';
import { I_Item } from '../types/item';

const itemsStore = useItemsStore();
const contextMenuStore = useContextMenuStore();
const inventoryStore = useInventory();
const draggedStore = useDraggedStore();
const settingsStore = useSettingsStore();

const isVisible = computed(() => {
    if (props.item && draggedStore.DraggedItem) {
        if (props.item.itemHash == draggedStore.DraggedItem.item.itemHash) {
            const draggedAmount = draggedStore.movedQuantity;

            if (typeof draggedAmount == 'number' && props.item.quantity > draggedAmount && draggedStore.DraggedItem.iData.isStackable)
                return true;

            return false;
        }
    }

    return true;
});

const isBroken = computed(() => {
    if (props.item && typeof props.item.meta.durability == 'number') {
        return props.item.meta.durability < 1;
    }
});

const cachedItemData = computed(() => {
    if (props.item) {
        return itemsStore.getItemData(props.item.item);
    }
});

const itemWeight = computed(() => {
    if (props.item) {
        if (cachedItemData.value?.isStackable) {
            return (cachedItemData.value?.weight * props.item.quantity).toFixed(1);
        }
        else {
            return cachedItemData.value?.weight;
        }
    }
});

const vIsbag = {
    mounted(el: HTMLElement) {
        const savedColor = el.style.backgroundColor;

        el.addEventListener("mouseenter", () => {
            if (!draggedStore.DraggedItem) return;

            if (cachedItemData.value?.bagSize) {
                el.style.backgroundColor = `rgba(125,125,125,.4)`;
            }
            else if (cachedItemData.value?.weaponHash) {
                el.style.backgroundColor = `rgba(125,125,125,.4)`;
            }
        });
        el.addEventListener("mouseleave", () => {
            el.style.backgroundColor = savedColor;
        });
    }
}

const itemOpacity = computed(() => {
    if (props.searchInput.length < 1)
        return 1.0;

    if (settingsStore.Settings.customnames &&
        typeof props.item?.meta.customName == 'string' &&
        props.item.meta.customName.toLowerCase().includes(props.searchInput.toLowerCase())
    )
        return 1.0;

    if (cachedItemData.value?.formatName.toLowerCase().includes(props.searchInput.toLowerCase()))
        return 1.0;

    return 0.15;
});

const props = defineProps({
    item: {
        type: Object as () => I_Item,
        required: true
    },
    inventoryUniqueId: {
        type: String,
        required: true
    },
    searchInput: {
        type: String,
        required: true
    }
});

const itemRef = ref<HTMLElement | null>(null);

const rightClick = (ev: MouseEvent) => {
    if (props.item) {
        contextMenuStore.OPEN(props.item, props.inventoryUniqueId);
    }
}

const MouseEnter = () => {
    if (settingsStore.Settings.sfx) hoverSound();
}

const MouseUp = () => {
    if (props.item && draggedStore.DraggedItem) {

        // Bag fast action
        if (cachedItemData.value?.bagSize) {
            AxiosInstance.post("DRAGGED_ITEM_TO_BAG_FAST", {
                bagUniqueId: props.item.itemHash,
                fromUniqueId: draggedStore.DraggedItem.iUniqueId,
                itemHash: draggedStore.DraggedItem.item.itemHash,
                quantity: draggedStore.movedQuantity
            });
        }
        // Weapon attachment wear
        else if (cachedItemData.value?.weaponHash) {
            AxiosInstance.post("ITEM_ADD_ATTACHMENT_WEAPON", {
                fromUniqueId: draggedStore.DraggedItem.iUniqueId,
                toUniqueId: props.inventoryUniqueId,
                draggedItemHash: draggedStore.DraggedItem.item.itemHash,
                itemHash: props.item.itemHash
            });
        }

    }
}

const startDragItem = (ev: MouseEvent) => {
    if (!props.item) return;
    if (!props.inventoryUniqueId) return;

    // VoidLine: ctrl + left click quick-moves the item to the other open
    // inventory -- player -> container, or container -> player. Handled here on
    // mousedown, before the drag threshold is armed, so a ctrl-click can never
    // turn into a half-started drag.
    if (ev.ctrlKey) {
        AxiosInstance.post("QUICK_MOVE", {
            grabbedItemHash: props.item.itemHash,
            grabbedFromInventoryUniqueID: props.inventoryUniqueId
        });

        return;
    }

    const definedItem = itemsStore.getItemData(props.item.item);
    if (!definedItem) return;

    let startX = ev.clientX;
    let startY = ev.clientY;

    const handleMouseMove = (moveEvent: MouseEvent) => {
        const deltaX = Math.abs(moveEvent.clientX - startX);
        const deltaY = Math.abs(moveEvent.clientY - startY);

        if (deltaX > 5 || deltaY > 5) {
            draggedStore.startDragging(props.item, props.inventoryUniqueId, definedItem);
            document.removeEventListener('mousemove', handleMouseMove);
            document.removeEventListener('mouseup', handleMouseUp);
        }
    };

    const handleMouseUp = () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
    };

    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
};

</script>

<style lang="scss">
$ITEM_BACKGROUND: linear-gradient(180deg, rgba(162, 179, 196, 0.2), rgba(59, 101, 141, 0.2));

.inventory-item {
    position: relative;
    display: flex;
    justify-content: center;
    align-items: center;
    overflow: hidden;
    background: $ITEM_BACKGROUND;

    &:hover {
        filter: brightness(120%);
    }

    .item-name {
        position: absolute;
        font-size: .6vw;
        color: rgb(220, 220, 220);
        bottom: 2%;
        pointer-events: none;
        font-weight: bold;
        width: 100%;
        text-align: center;
        text-overflow: ellipsis;
        white-space: nowrap;
        overflow: hidden;

        &.rotated {
            transform-origin: left right;
            bottom: auto;
            right: 43%;
            transform: rotate(90deg);
        }
    }

    .item-quantity {
        position: absolute;
        font-size: .55vw;
        color: rgb(220, 220, 220);
        top: 0;
        left: .1vw;
        pointer-events: none;
    }

    .broken-icon {
        position: absolute;
        top: .1vw;
        left: .1vw;
        color: rgb(180, 139, 26);
        font-size: .75vw;
    }

    .item-weight {
        position: absolute;
        font-size: .55vw;
        color: rgb(155, 155, 155);
        top: 0;
        right: .1vw;
    }

    .item-image {
        position: relative;
        width: 80%;
        height: 80%;
        background-position: center;
        background-size: contain;
        background-repeat: no-repeat;
        pointer-events: none;

        &.rotated {
            rotate: 90deg;
        }
    }
}
</style>