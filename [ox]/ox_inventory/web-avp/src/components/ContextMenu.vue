<template>
    <div ref="menuRef" :key="contextMenuStore.coordX" class="newtooltip-parent" :style="{
            left: contextMenuStore.coordX + 'px',
            top: contextMenuStore.coordY + 'px'
        }" v-if="contextMenuStore.opened && contextMenuStore.selectedItem">

        <div class="newtooltip-header">
            <div style="display:flex">
                <div class="newtooltip-header-image-content">
                    <div class="newtooltip-header-image" :style="{
                            backgroundImage: `url(../images/${contextMenuStore.selectedItem?.item}.png)`
                        }"></div>
                </div>
                <div class="newtooltip-header-info-content">
                    <div class="newtooltip-header-info-item-category">
                        {{ cachedItemData?.rarity }}
                    </div>
                    <div class="newtooltip-header-info-item-name">
                        {{ contextMenuStore.selectedItem?.meta.customName ?? cachedItemData?.formatName }}
                    </div>
                </div>
            </div>
            <div class="newtooltip-durability-content"
                v-if="typeof contextMenuStore.selectedItem?.meta.durability == 'number'">
                <div class="fill" :style="{
                        width: (contextMenuStore.selectedItem.meta.durability / 100) * 100 + '%',
                        backgroundColor: `rgba(144, 238, 144, 1)`
                    }"></div>
            </div>
            <div class="newtooltip-header-description-content" v-if="cachedItemData?.description">
                {{ cachedItemData.description }}
            </div>
        </div>

        <div class="newtooltip-infos-content">
            <div class="info-entry">
                <div class="question">
                    <i class="fa-solid fa-weight-hanging"></i>
                    Weight
                </div>
                <div class="answer">{{ cachedItemData?.weight }} kg.</div>
            </div>

            <div class="info-entry" v-if="typeof contextMenuStore.selectedItem?.meta.drawable == 'number'">
                <div class="question">
                    <i class="fa-solid fa-palette"></i>
                    Drawable
                </div>
                <div class="answer">{{ contextMenuStore.selectedItem?.meta.drawable }}</div>
            </div>

            <div class="info-entry" v-if="typeof contextMenuStore.selectedItem?.meta.texture == 'number'">
                <div class="question">
                    <i class="fa-solid fa-palette"></i>
                    Texture
                </div>
                <div class="answer">{{ contextMenuStore.selectedItem?.meta.texture }}</div>
            </div>
            <div class="info-entry" v-if="typeof contextMenuStore.selectedItem?.meta.serial == 'string'">
                <div class="question">
                    <i class="fa-solid fa-hashtag"></i>
                    Serial Number
                </div>
                <div class="answer">{{ contextMenuStore.selectedItem.meta.serial }}</div>
            </div>
            <div class="info-entry" v-if="typeof contextMenuStore.selectedItem?.meta.note == 'string'">
                <div class="question">
                    <i class="fa-solid fa-note-sticky"></i>
                    Note
                </div>
                <div class="answer">{{ contextMenuStore.selectedItem?.meta.note }}</div>
            </div>
        </div>

        <div class="newtooltip-attachments-content" v-if="cachedItemData?.weaponHash">
            <template v-for="index in 5">
                <template v-if="contextMenuStore.selectedItem?.meta.attachments?.at(index - 1)">
                    <AttachmentSlot :attachment-index="index" :item-hash="contextMenuStore.selectedItem.itemHash"
                        :inventory-unique-id="contextMenuStore.selectedFromInventoryId!"
                        :attachment-name="contextMenuStore.selectedItem.meta.attachments[index - 1]" />
                </template>
                <template v-else>
                    <EmptyAttachmentSlot :inventory-unique-id="contextMenuStore.selectedFromInventoryId!"
                        :item-hash="contextMenuStore.selectedItem.itemHash" />
                </template>
            </template>
        </div>

        <div class="newtooltip-buttons-content">
            <!-- A garment currently on the ped gets one action: take it off.
                 Use/Give/Drop are all wrong while it is being worn -- Use would
                 read as "wear the thing you are wearing", and giving or dropping
                 it off your body is what left a shirt on the floor and still on
                 your back. Take it off first, then it is an ordinary item again
                 with the ordinary menu. -->
            <button v-if="isWorn" @click.prevent.left="Use">Remove</button>

            <template v-if="!isWorn">
                <button v-if="isCarried && (cachedItemData?.isUsable || cachedItemData?.weaponHash)"
                    @click.prevent.left="Use">Use</button>
                <button v-if="isCarried && isWearable" @click.prevent.left="WearFast">Wear</button>
                <button v-if="cachedItemData?.bagSize" @click.prevent.left="OpenBag">Open</button>
                <button v-if="isCarried" @click.prevent.left="Give">Give</button>
                <button v-if="isCarried" @click.prevent.left="Drop">Drop</button>
            </template>
        </div>

    </div>
</template>

<script lang="ts" setup>
import { computed, nextTick, ref, watch } from 'vue';
import { AxiosInstance } from '../plugins/axios.plugin';
import { useContextMenuStore } from '../store/contextmenu.store';
import { useInventory } from '../store/inventory.store';
import { useItemsStore } from '../store/items.store';
import { useNearbyStore } from '../store/nearby.store';
import { useSettingsStore } from '../store/settings.store';
import EmptyAttachmentSlot from './EmptyAttachmentSlot.vue';
import AttachmentSlot from './AttachmentSlot.vue';

const contextMenuStore = useContextMenuStore();
const inventoryStore = useInventory();
const itemsStore = useItemsStore();
const settingsStore = useSettingsStore();
const nearbyStore = useNearbyStore();

const menuRef = ref<HTMLElement | null>(null);

const cachedItemData = computed(() => {
    if (contextMenuStore.selectedItem) {
        return itemsStore.getItemData(contextMenuStore.selectedItem.item);
    }
});

/**
 * Whether the right-clicked item is one the player is actually carrying.
 *
 * Use / Wear / Give / Drop are all things you do with something on your person.
 * On an item sitting in a drop, a wreck or any other container they are
 * meaningless -- you cannot use or give away something you are not holding, and
 * "drop" on an item already on the ground is nonsense. Take it out first.
 */
const isCarried = computed(() => {
    return contextMenuStore.selectedFromInventoryId === inventoryStore.playerInventory?.inventoryUniqueId;
});

/**
 * Is this garment currently on the ped?
 *
 * Read from the item's own metadata, which vl_clothing sets when it goes on --
 * not from which panel it happens to be drawn in. That way a worn item gets the
 * same menu wherever it is clicked, and an ordinary clothing item sitting in the
 * grid keeps the normal menu like every other item.
 */
const isWorn = computed(() => !!contextMenuStore.selectedItem?.meta?.worn);

const isWearable = computed(() => {
    if (typeof contextMenuStore.selectedItem?.slotGUID === 'string') return false;

    if (cachedItemData.value?.isAmmo)
        return true;

    if (typeof cachedItemData.value?.clothingId === 'number')
        return true;

    if (typeof cachedItemData.value?.propId === 'number')
        return true;

    return false;
});

watch(() => contextMenuStore.opened, (isOpened) => {
    if (isOpened) {
        centerElement();
    }
});
watch(() => contextMenuStore.coordX, () => {
    centerElement();
});

const centerElement = () => {
    nextTick(() => {
        const element = menuRef.value;
        if (element) {
            const elementRect = element.getBoundingClientRect();
            const bottomOffset = window.innerHeight - elementRect.bottom;
            const rightOffset = window.innerWidth - elementRect.right;

            if (bottomOffset < 0) {
                element.style.top = parseInt(element.style.top) + bottomOffset + 'px';
            }

            if (rightOffset < 0) {
                element.style.left = parseInt(element.style.left) + rightOffset + 'px';
            }
        }
    });
}

const Use = () => {
    if (contextMenuStore.selectedItem) {
        AxiosInstance.post("USE_ITEM", {
            grabbedFromInventoryUniqueID: contextMenuStore.selectedFromInventoryId,
            grabbedItemHash: contextMenuStore.selectedItem.itemHash
        });
    }
}

const Give = () => {
    if (contextMenuStore.selectedItem) {
        nearbyStore.open(contextMenuStore.selectedItem.itemHash);
    }
}

const Drop = () => {
    if (contextMenuStore.selectedItem) {
        AxiosInstance.post("DROP_ITEM_ON_GROUND", {
            grabbedFromInventoryUniqueID: contextMenuStore.selectedFromInventoryId,
            grabbedItemHash: contextMenuStore.selectedItem.itemHash,
            quantity: inventoryStore.store.quantityInput
        });
    }
}

const WearFast = () => {
    if (contextMenuStore.selectedItem) {
        AxiosInstance.post("WEAR_ITEM", {
            itemHash: contextMenuStore.selectedItem.itemHash,
            inventoryUniqueId: contextMenuStore.selectedFromInventoryId
        });
    }
}

const OpenBag = () => {
    if (contextMenuStore.selectedItem) {
        AxiosInstance.post("OPEN_BAG", {
            inventoryUniqueId: contextMenuStore.selectedFromInventoryId,
            itemHash: contextMenuStore.selectedItem.itemHash
        });
    }
}

</script>


<style lang="scss">
$textstroke: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000;

.newtooltip-parent {
    position: absolute;
    z-index: 99999;
    overflow: hidden;
    background: radial-gradient(circle, rgba(25, 25, 25, .5) 0%, rgba(15, 15, 15, .65) 100%) !important;
    border-radius: .25vw;
    padding: .75vw;
    display: flex;
    flex-direction: column;
    align-items: center;
    max-width: 12vw;

    .newtooltip-attachments-content {
        width: 100%;
        display: flex;
        margin-top: .75vw;

        .newtooltip-attachment-entry {
            position: relative;
            height: 2vw;
            width: 2vw;
            margin: 0 .15vw;
            background: radial-gradient(circle, rgba(25, 25, 25, .5) 0%, rgba(15, 15, 15, .65) 100%) !important;
            border-radius: .25vw;
            display: flex;
            justify-content: center;
            align-items: center;

            &.highlight {
                background: radial-gradient(circle, rgba(76, 116, 72, 0.4) 0%, rgba(80, 134, 75, 0.45) 100%) !important;
            }

            .newtooltip-attachment-entry-image {
                height: 80%;
                width: 80%;
                background-position: center;
                background-size: contain;
                background-repeat: no-repeat;
            }
        }
    }

    .newtooltip-crafting-ingredients-content {
        display: flex;
        flex-direction: column;
        width: 100%;

        .ingredients-header {
            color: white;
            margin-top: .75vw;
            margin-bottom: .35vw;
            font-size: .8vw;
            text-align: center;
        }

        .ingredient-entry {
            display: flex;
            align-items: center;
            padding: .25vw .25vw;
            border-radius: .15vw;
            margin: .1vw 0;
            background: radial-gradient(circle, rgba(35, 45, 35, .5) 0%, rgba(25, 25, 25, .65) 100%) !important;

            &.disabled {
                background: radial-gradient(circle, rgba(25, 25, 25, .5) 0%, rgba(15, 15, 15, .65) 100%) !important;

                .ingredient-name {
                    color: grey;
                }

                .ingredient-image {
                    filter: grayscale(100);
                }
            }

            .ingredient-image {
                height: 1.75vw;
                width: 1.75vw;
                background-position: center;
                background-size: contain;
                background-repeat: no-repeat;
                background-color: rgba(85, 85, 85, .25);
                border-radius: .25vw;
            }

            .ingredient-name {
                width: 80%;
                text-overflow: ellipsis;
                overflow: hidden;
                white-space: nowrap;
                color: white;
                font-size: .7vw;
                margin-left: .4vw;
            }
        }
    }

    .newtooltip-buttons-content {
        width: 100%;
        display: flex;
        flex-direction: row;
        flex-wrap: wrap;
        margin-top: .75vw;

        button {
            color: white;
            font-size: .65vw;
            border: .1vw solid grey;
            padding: .25vw .5vw;
            border-radius: .15vw;
            margin: .15vw .75vw;
            flex: 1;
            text-align: center;
            background: radial-gradient(circle, rgba(25, 25, 25, .35) 0%, rgba(15, 15, 15, .45) 100%) !important;

            &.active {
                border: .1vw solid lightgreen;
            }

            &:not(&:disabled) {
                &:hover {
                    border: .1vw solid lightblue;
                }
            }

            &:disabled {
                opacity: 0.5;
            }
        }
    }

    .newtooltip-infos-content {
        width: 100%;
        margin-top: 1vw;

        .info-entry {
            margin-bottom: .5vw;

            &:last-child {
                margin-bottom: 0;
            }

            .question {
                display: flex;
                font-size: .65vw;
                color: rgb(220, 220, 220);
                margin-bottom: .25vw;

                i {
                    margin-right: .2vw;
                }
            }

            .answer {
                color: white;
                font-size: .7vw;
            }
        }
    }

    .newtooltip-header {
        width: 100%;

        .newtooltip-durability-content {
            position: relative;
            width: 100%;
            height: .3vw;
            background-color: rgb(15, 15, 15);
            border-radius: .15vw;
            margin: .55vw 0;

            .fill {
                position: relative;
                height: 100%;
                width: 50%;
                border-radius: inherit;
            }
        }

        .newtooltip-header-description-content {
            position: relative;
            color: white;
            font-size: .6vw;
            margin-top: .5vw;
        }

        .newtooltip-header-info-content {
            position: relative;
            display: flex;
            flex-direction: column;
            margin: .55vw;
            justify-content: center;

            .newtooltip-header-info-item-category {
                color: white;
                font-size: .65vw;
            }

            .newtooltip-header-info-item-name {
                color: white;
                font-size: .8vw;
                font-weight: bold;
            }
        }

        .newtooltip-header-image-content {
            position: relative;
            display: flex;
            justify-content: center;
            align-items: center;
            width: 4vw;
            height: 4vw;
            background: radial-gradient(circle, rgba(25, 25, 25, .55) 0%, rgba(15, 15, 15, .65) 100%) !important;
            border-radius: .25vw;
            // border: .1vw solid grey;

            .newtooltip-header-image {
                height: 80%;
                width: 80%;
                background-position: center;
                background-size: contain;
                background-repeat: no-repeat;
            }
        }

    }
}

.tooltip-parent {
    position: absolute;
    z-index: 999999;
    width: 15vw;
    overflow: hidden;

    .tooltip-header {
        position: relative;
        width: 100%;
        background-color: rgba(45, 45, 45, .8);
        padding: .35vw 0;
        display: flex;
        align-items: center;
        overflow: hidden;
        white-space: nowrap;
        text-overflow: ellipsis;
        word-break: keep-all;

        .tooltip-header-text {
            flex: 1;
            color: white;
            font-weight: bold;
            font-size: .7vw;
            text-indent: .5vw;
        }

        .tooltip-weight {
            flex: 1;
            color: rgb(200, 200, 200);
            font-size: .65vw;
            text-align: right;
            margin-right: .5vw;
        }
    }

    .tooltip-content {
        position: relative;
        background-color: rgba(35, 35, 35, .8);
        color: rgb(220, 220, 220);
        padding: .35vw .55vw;

        .tooltip-name {
            display: flex;
            color: white;
            font-weight: bold;
            font-size: .7vw;
            margin: .25vw 0;

            .rarity {
                font-size: .5vw;
                margin-left: .35vw;
                color: white;
                vertical-align: super;
            }
        }

        .tooltip-description {
            color: rgb(175, 175, 175);
            font-size: .65vw;
            margin-top: .5vw;
            margin-bottom: .25vw;
        }

        .tooltip-bar {
            position: relative;
            display: block;
            margin-top: .5vw;
            margin-bottom: .25vw;

            .tooltip-bar-header {
                color: rgb(175, 175, 175);
                font-size: .65vw;
                margin: .25vw 0;
            }

            .bar-content {
                position: relative;
                height: .65vw;
                width: 100%;
                background-color: rgba(10, 10, 10, .75);
                display: flex;
                align-items: center;

                .bar-content-text {
                    position: absolute;
                    width: 100%;
                    text-align: center;
                    font-size: .55vw;
                    color: rgb(175, 175, 175);
                    z-index: 1;
                }

                .bar-content-inside {
                    position: relative;
                    height: 100%;
                    width: 50%;
                    background-color: rgba(102, 137, 189, 0.75);
                }
            }
        }
    }

    .tooltip-buttons {
        position: relative;
        display: flex;
        background-color: rgba(35, 35, 35, .8);
        flex-wrap: wrap;

        .button {
            color: white;
            font-size: .65vw;
            border: .1vw solid rgb(175, 175, 175);
            padding: .25vw .5vw;
            border-radius: .15vw;
            margin: .25vw;
            flex: 1;
            text-align: center;
            background: linear-gradient(180deg, rgba(100, 100, 100, 0.2), rgba(65, 65, 65, 0.2));

            &:hover {
                border: .1vw solid lightgreen;
            }
        }
    }
}
</style>