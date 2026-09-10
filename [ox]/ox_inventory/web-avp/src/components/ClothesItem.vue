<template>
    <div @contextmenu.prevent="rightClick" @mousedown.prevent.left="startDragDress" @mouseup.prevent.left="wear"
        class="clothes-parent">
        <div class="clothes-header">
            {{ name }}
        </div>

        <div style="margin-bottom:.1vw"></div>

        <template v-if="item">
            <div :style="{
                    width: width + 'vw',
                    height: height + 'vw'
                }" class="clothes-item">
                <div :style="{
                        backgroundImage: `url(../images/${item.meta?.imageName ?? item.item}.png)`
                    }" class="item-image">
                </div>

                <div v-if="showQuantity" class="item-quantity">x{{ item.quantity }}</div>
            </div>
        </template>

        <template v-else>
            <div :style="{
                width: width + 'vw',
                height: height + 'vw'
            }" class="clothes-item">
                <div :style="{
                        backgroundImage: `url(clothes_empty_items/${empty_image})`,
                        opacity: 0.7
                    }" class="item-image">
                </div>
            </div>
        </template>
    </div>
</template>

<script lang="ts" setup>
import { AxiosInstance } from "../plugins/axios.plugin";
import { useContextMenuStore } from "../store/contextmenu.store";
import { useDraggedStore } from "../store/dragged.store";
import { useInventory } from "../store/inventory.store";
import { useItemsStore } from "../store/items.store";
import { I_Item } from "../types/item";

const inventoryStore = useInventory();
const contextMenuStore = useContextMenuStore();
const itemsStore = useItemsStore();
const draggedStore = useDraggedStore();

const props = defineProps({
    item: {
        type: Object as () => I_Item | undefined,
        required: false
    },
    empty_image: {
        type: String,
        required: false
    },
    inv_unique_id: {
        type: String,
        required: false
    },
    width: {
        type: Number,
        required: true
    },
    height: {
        type: Number,
        required: true
    },
    name: {
        type: String,
        required: true
    },
    slotGuid: {
        type: String,
        required: true
    },
    showQuantity: {
        type: Boolean,
        default: false
    }
});

const startDragDress = (ev: MouseEvent) => {
    if (!props.item) return;
    if (!props.inv_unique_id) return;

    const definedItem = itemsStore.getItemData(props.item.item);
    if (!definedItem) return;

    const startX = ev.clientX;
    const startY = ev.clientY;

    const handleMouseMove = (moveEvent: MouseEvent) => {
        const deltaX = Math.abs(moveEvent.clientX - startX);
        const deltaY = Math.abs(moveEvent.clientY - startY);

        if (deltaX > 5 || deltaY > 5) {
            if (props.item && props.inv_unique_id) {
                draggedStore.startDragging(props.item, props.inv_unique_id, definedItem);
            }
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

const rightClick = (ev: MouseEvent) => {
    if (!props.item) return;
    if (!props.inv_unique_id) return;

    contextMenuStore.OPEN(props.item, props.inv_unique_id);
}

const wear = () => {
    if (!draggedStore.DraggedItem) return;
    if (props.inv_unique_id !== inventoryStore.playerInventory?.inventoryUniqueId) return;

    // VoidLine: dropping onto one of the ten hotkey cards assigns the item to
    // the matching ox slot. AVP gated this on canPutOnSlotGUID, which is a
    // clothing concept ox items never carry -- so without this branch the cards
    // silently refused every drop.
    //
    // The alternation is ordered 10 first on purpose: `[1-9]|10` would match the
    // "1" of "HOTKEY_SLOT_10" and then fail on the trailing "0", so slot 10
    // would never accept a drop.
    const hotkey = /^HOTKEY_SLOT_(10|[1-9])$/.exec(props.slotGuid);

    if (hotkey) {
        AxiosInstance.post("HOTKEY_ASSIGN", {
            grabbedItemHash: draggedStore.DraggedItem.item.itemHash,
            slot: Number(hotkey[1])
        });

        draggedStore.resetDragging();
        return;
    }

    if (draggedStore.DraggedItem.iData.canPutOnSlotGUID?.includes(props.slotGuid)) {
        AxiosInstance.post("WEAR_ITEM_ON_SLOTGUID", {
            itemHash: draggedStore.DraggedItem.item.itemHash,
            inventoryUniqueId: draggedStore.DraggedItem.iUniqueId,
            slotGuid: props.slotGuid
        })

        // VoidLine: release the drag. Dropping on a clothing slot leaves
        // placingAtXY/hoveredInventoryUniqueId unset, so Dragged.vue's mouseUp
        // never fires its own reset and the item stayed glued to the cursor.
        draggedStore.resetDragging();
    }
}
</script>


<style lang="scss" scoped>
$HEADER_COLOR: linear-gradient(180deg, rgba(75, 75, 75, 1), rgba(35, 35, 35, 1));

.clothes-parent {
    position: absolute;
    display: block !important;

    .clothes-header {
        font-size: .5vw;
        color: white;
        width: 100%;
        background: $HEADER_COLOR;
        clip-path: polygon(0 100%, 0 0, 80% 0, 100% 100%);
        text-indent: .25vw;
        padding: .05vw 0;
    }

    .clothes-item {
        position: relative;
        display: flex;
        justify-content: center;
        align-items: center;

        background: repeating-linear-gradient(-45deg,
                rgba(100, 100, 100, .45),
                rgba(0, 0, 0, .25) .35vw);
        background-color: rgba(49, 49, 49, .65);

        &:hover {
            filter: brightness(120%);
        }

        .item-image {
            position: relative;
            width: 90%;
            height: 90%;
            background-position: center;
            background-size: contain;
            background-repeat: no-repeat;
            pointer-events: none;
        }

        .item-quantity {
            position: absolute;
            font-size: .55vw;
            color: rgb(220, 220, 220);
            bottom: 0;
            left: .1vw;
            pointer-events: none;
        }
    }
}
</style>