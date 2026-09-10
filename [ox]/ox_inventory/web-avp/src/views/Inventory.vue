<template>
    <div ref="inventoryRef" @mouseleave.prevent="inventoryStore.store.hoveredInventoryUniqueId = null"
        @mouseenter.prevent="inventoryStore.store.hoveredInventoryUniqueId = inventory.inventoryUniqueId" class="inventory"
        :style="{
            left: inventory.coordX + 'px',
            top: inventory.coordY + 'px',
            position: 'absolute',
            filter: (contextMenuStore.opened || inputStore.isOpened || nearbyStore.isOpened) ? 'blur(2px)' : ''
        }">

        <Transition
            :enter-active-class="settingsStore.Settings.animations ? 'animate__animated animate__fadeInUp animate__faster' : undefined"
            :leave-active-class="settingsStore.Settings.animations ? 'animate__animated animate__fadeOutDown animate__faster' : undefined">
            <input v-if="inventory.searchOpened" ref="searchRef" v-model="inventory.searchInput" type="text"
                placeholder="Search" class="inventory-search">
        </Transition>

        <div @mousedown.prevent.left="handleMouseDown" class="inventory-header">
            <div class="header-name">
                {{ inventory.inventoryName }}
            </div>

            <MacCloseButton v-if="!inventory.isLocal" v-on:click="closeInventory" />
        </div>

        <div class="inventory-items-content">
            <div v-for="(_, x) in inventory.x" :key="x">
                <div v-for="(__, y) in inventory.y" :key="y" :style="cellStyle" :class="(
            inventoryStore.store.hoveredInventoryUniqueId == inventory.inventoryUniqueId
            &&
            inventoryStore.store.over != null
            &&
            x >= inventoryStore.store.over.minX && x <= inventoryStore.store.over.maxX
            &&
            y >= inventoryStore.store.over.minY && y <= inventoryStore.store.over.maxY
        ) ? 'empty-slot highlight' : 'empty-slot'" :data-x="x" :data-y="y" :data-empty="true" :id="`empty-${x}-${y}`">

                    <InventoryItem v-if="itemAtSlot(x, y)" :search-input="inventory.searchInput"
                        :inventory-unique-id="inventory.inventoryUniqueId" :item="itemAtSlot(x, y)!" />
                </div>
            </div>
        </div>

        <div class="inventory-footer">
            <div @click.prevent.left="inventory.searchOpened = !inventory.searchOpened" class="search-input-button">
                <i class="fa-solid fa-search"></i>
                <div v-if="inventory.searchOpened" class="search-found-amount">{{ searchedItemsAmount }}</div>
            </div>
            <div class="weight-content">
                <div class="weight-bar">
                    <div class="weight-text">{{ currentWeight.toFixed(2) }} / {{ inventory.maxWeight.toFixed(2) }}</div>
                    <div :style="{
                        width: (currentWeight / inventory.maxWeight) * 100 + '%'
                    }" class="bar-inside"></div>
                </div>
            </div>
            <input placeholder="Quantity" v-if="inventory.isLocal" v-model="inventoryStore.store.quantityInput"
                type="number" class="quantity-input" />
        </div>
    </div>
</template>

<script setup lang="ts">
import InventoryItem from "../components/InventoryItem.vue";
import { useInventory } from '../store/inventory.store';
import { AxiosInstance } from "../plugins/axios.plugin";
import { computed, nextTick, ref, watch } from "vue";
import { useSettingsStore } from "../store/settings.store";
import MacCloseButton from "../components/MacCloseButton.vue";
import { useItemsStore } from "../store/items.store";
import { I_Inventory } from "../types/inventory";
import { I_Item } from "../types/item";
import { useContextMenuStore } from "../store/contextmenu.store";
import { useInputStore } from "../store/input.store";
import { useNearbyStore } from "../store/nearby.store";

const inventoryStore = useInventory();
const settingsStore = useSettingsStore();
const itemsStore = useItemsStore();
const contextMenuStore = useContextMenuStore();
const inputStore = useInputStore();
const nearbyStore = useNearbyStore();

const inventoryRef = ref<HTMLElement | null>(null);
const searchRef = ref<HTMLElement | null>(null);

let isMoving = false;
let offsetX = 0;
let offsetY = 0;

const searchedItemsAmount = computed(() => {
    let amount = 0;

    if (props.inventory.searchInput.length > 0) {
        amount = props.inventory.items.filter(a => {
            if (typeof a.slotGUID === 'string') return;

            const iData = itemsStore.getItemData(a.item);

            if (iData.formatName.toLowerCase().includes(props.inventory.searchInput.toLowerCase()))
                return true;

            if (settingsStore.Settings.customnames && typeof a.meta.customName == 'string' &&
                a.meta.customName.toLowerCase().includes(props.inventory.searchInput.toLowerCase())
            )
                return true;

        }).length;
    }

    return amount;
});

/** Gets the inventory current weight. */
const currentWeight = computed(() => {
    let weight = 0.0;

    for (let i = 0; i < props.inventory.items.length; i++) {
        const item = props.inventory.items[i];
        const iData = itemsStore.getItemData(item.item);
        if (!iData) continue;

        if (iData.isStackable) {
            weight += iData.weight * item.quantity;
        }
        else {
            weight += iData.weight;
        }
    }

    return weight;
});

// VoidLine: the saved-position restore is gone on purpose.
//
// AVP let you drag a panel and remembered where you left it. That fought the
// ox adapter, which works out where both panels belong every time the
// inventory opens -- and a stale saved position was exactly why a container
// could open on top of the player grid the first time. Layout is now
// deterministic: the adapter decides, every open, so it always looks the same.
//
// Dragging still works for the duration of an open; it simply is not persisted
// (see handleMouseUp).

watch(() => props.inventory.searchOpened, (newValue) => {
    props.inventory.searchInput = "";

    if (newValue) {
        nextTick(() => {
            searchRef.value?.focus();
        });
    }
});

const props = defineProps({
    inventory: {
        type: Object as () => I_Inventory,
        required: true
    }
});

/**
 * Grid cell -> item, built once per items change.
 *
 * itemAtSlot used to do `.filter(...).find(...)`: a fresh array allocation plus
 * a linear scan, every call. The template calls it twice per cell, so a 10x20
 * grid meant 400 allocations and 400 scans per render -- and the whole grid
 * re-renders on every hover change while dragging, so that ran continuously for
 * the length of a drag.
 *
 * As a computed it is rebuilt only when the item list actually changes; hover
 * re-renders now hit a cached Map.
 */
/**
 * Every empty cell shared the same three style values but allocated its own
 * object each render -- 200 throwaway objects per pass. Hoisted to one computed
 * that only changes when the slot-size settings do.
 */
const cellStyle = computed(() => ({
    width: settingsStore.Settings.slotsize + 'vw',
    height: settingsStore.Settings.slotsize + 'vw',
    border: settingsStore.Settings.slotborder + 'vw solid rgba(200,200,200, .25)',
}));

const itemsByCell = computed(() => {
    const map = new Map<string, I_Item>();

    for (let i = 0; i < props.inventory.items.length; i++) {
        const item = props.inventory.items[i];
        if (typeof item.slotGUID === 'string') continue;

        map.set(`${item.x},${item.y}`, item);
    }

    return map;
});

const itemAtSlot = (x: number, y: number) => itemsByCell.value.get(`${x},${y}`);

const closeInventory = () => {
    AxiosInstance.post(
        "CLOSE_INVENTORY", {
        inventoryUniqueId: props.inventory.inventoryUniqueId
    });
}

const handleMouseDown = (ev: MouseEvent) => {
    if (isMoving) return;

    isMoving = true;

    window.addEventListener("mouseup", handleMouseUp);
    window.addEventListener("mousemove", handleMouseMove);

    const element = inventoryRef.value;
    if (element) {
        offsetX = element.offsetLeft + element.offsetWidth - ev.clientX;
        offsetY = element.offsetTop + element.offsetHeight - ev.clientY;
    }
}

const handleMouseUp = () => {
    isMoving = false;
    window.removeEventListener("mouseup", handleMouseUp);
    window.removeEventListener("mousemove", handleMouseMove);

    // VoidLine: not persisted -- see the layout note above. Saving here is
    // what made the next open land somewhere unpredictable.
}

const handleMouseMove = (ev: MouseEvent) => {
    if (!isMoving) return;

    const element = inventoryRef.value;
    if (element) {
        props.inventory.coordX = ev.clientX + offsetX - element.offsetWidth;
        props.inventory.coordY = ev.clientY + offsetY - element.offsetHeight;
    }
}
</script>


<style lang="scss" scoped>
// $HEADER_BACKGROUND: rgba(50, 50, 50, 1); OLD HEADER
$HEADER_BACKGROUND: rgba(40, 40, 40, .8);
$EMPTY_SLOT_BACKGROUND: rgba(50, 50, 50, .8);

.empty-slot {
    z-index: 99999;
    background-color: $EMPTY_SLOT_BACKGROUND;

    &.highlight {
        background-color: lighten($EMPTY_SLOT_BACKGROUND, 20%);
    }
}

.inventory {
    position: absolute;
    padding: .1vw;
    margin: .25vw;
    width: min-content;
    max-width: max-content;

    .inventory-items-content {
        position: relative;
        display: flex;
        max-height: 35vw;
        overflow: auto;
    }

    .search-input-button {
        color: rgb(178, 193, 216);
        font-size: .75vw;
        padding: .25vw;

        &:hover {
            color: cyan;
        }

        .search-found-amount {
            position: absolute;
            color: lightgreen;
            font-size: .5vw;
            left: 1%;
            bottom: 5%;
        }
    }

    .inventory-search {
        position: absolute;
        top: 100%;
        left: .15vw;
        color: white;
        font-size: .7vw;
        border: 0;
        outline: 0;
        background: rgba(20, 20, 20, 0.85);
        padding: .25vw;

        &::placeholder {
            color: rgb(120, 120, 120);
            font-size: 0.7vw;
        }

        &::-webkit-inner-spin-button,
        &::-webkit-outer-spin-button {
            -webkit-appearance: none;
        }

    }

    .inventory-footer {
        position: relative;
        background: $HEADER_BACKGROUND;
        display: flex;
        justify-content: center;
        align-items: center;
        overflow: hidden;
        padding: .25vw .5vw;

        .weight-content {
            position: relative;
            width: 80%;
            margin: 0 .5vw;

            .weight-bar {
                position: relative;
                width: 100%;
                background-color: rgba(0, 0, 0, .8);
                height: .75vw;
                border-radius: .15vw;
                display: flex;
                align-items: center;

                .bar-inside {
                    position: relative;
                    height: 100%;
                    width: 35%;
                    background-color: rgba(135, 206, 235, .50);
                    border-radius: inherit;
                }

                .weight-text {
                    position: absolute;
                    width: 100%;
                    text-align: center;
                    color: rgb(200, 200, 200);
                    font-size: .55vw;
                    white-space: nowrap;
                    text-overflow: ellipsis;
                    overflow: hidden;
                }
            }
        }

        .quantity-input {
            position: relative;
            width: 20%;
            border: 0;
            background: transparent;
            outline: 0;
            font-size: .9vw;
            border-radius: 0.15vw;
            color: white;
            text-align: center;
            background: rgba(20, 20, 20, 0.85);
            padding: 0.15vw 0;

            &::placeholder {
                color: rgb(120, 120, 120);
                font-size: 0.7vw;
            }

            &::-webkit-inner-spin-button,
            &::-webkit-outer-spin-button {
                -webkit-appearance: none;
            }
        }
    }

    .inventory-header {
        position: relative;
        display: flex;
        padding: .25vw 0;
        align-items: center;
        overflow: hidden;
        background-color: $HEADER_BACKGROUND;

        .fa-times {
            position: relative;
            flex: 0.2;
            font-size: 1vw;
            right: .2vw;
            color: white;

            &:hover {
                color: red;
            }
        }

        .header-name {
            position: relative;
            flex: 3;
            color: white;
            font-size: 1vw;
            text-indent: .5vw;
            font-weight: bold;

            i {
                font-size: .9vw;
                margin-right: .25vw;
            }
        }
    }
}
</style>