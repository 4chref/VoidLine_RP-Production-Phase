import { defineStore } from "pinia";
import { computed, onMounted, ref, watch } from "vue";
import { AxiosInstance } from "../plugins/axios.plugin";
import { useSettingsStore } from "./settings.store";
import { I_Inventory } from "../types/inventory";

interface DataState {
    placingAtXY: { x: number; y: number; } | null;
    over: {
        minX: number;
        maxX: number;
        minY: number;
        maxY: number;
    } | null;

    hoveredInventoryUniqueId: string | null;

    quantityInput: number;
    cursorX: number;
    cursorY: number;

    shortkeysOpened: boolean;
}

export const useInventory = defineStore("InventoryStore", () => {

    const settingsStore = useSettingsStore();

    const interfaceOpened = ref(false);

    const inventories = ref<{ [uniqueId: string]: I_Inventory }>({});

    const store = ref<DataState>(
        {
            placingAtXY: null,
            over: null,
            hoveredInventoryUniqueId: null,
            quantityInput: 0,
            cursorX: 0,
            cursorY: 0,
            shortkeysOpened: false
        }
    );

    if (import.meta.env.DEV) {
        onMounted(() => {
            interfaceOpened.value = true;

            store.value.shortkeysOpened = true;

            inventories.value["player-dev-inventory"] = {
                inventoryName: "Development",
                inventoryUniqueId: "player-dev-inventory",
                items: [
                    {
                        item: "WEAPON_ASSAULTRIFLE",
                        isRotated: false,
                        itemHash: "",
                        meta: {
                            durability: 20,
                            attachments: ['at_suppressor_light']
                        },
                        quantity: 1,
                        x: 1,
                        y: 1
                    }
                ],
                maxWeight: 100,
                x: 10,
                y: 15,
                isLocal: true,
                searchInput: "",
                searchOpened: false,
            }
        });
    }

    const getItemWidthVW = (itemHeight: number, itemWidth: number, isRotated: boolean) => {
        let $width = isRotated ? (itemHeight * settingsStore.Settings.slotsize) : (itemWidth * settingsStore.Settings.slotsize);

        if (isRotated) {
            for (let i = 0; i < itemHeight - 1; i++) {
                $width += settingsStore.Settings.slotborder * 2;
            }
        }
        else {
            for (let i = 0; i < itemWidth - 1; i++) {
                $width += settingsStore.Settings.slotborder * 2;
            }
        }

        return $width + 'vw';
    }

    const getItemHeightVW = (itemHeight: number, itemWidth: number, isRotated: boolean) => {
        let $height = isRotated ? (itemWidth * settingsStore.Settings.slotsize) : (itemHeight * settingsStore.Settings.slotsize);

        if (isRotated) {
            for (let i = 0; i < itemWidth - 1; i++) {
                $height += settingsStore.Settings.slotborder * 2;
            }
        }
        else {
            for (let i = 0; i < itemHeight - 1; i++) {
                $height += settingsStore.Settings.slotborder * 2;
            }
        }

        return $height + 'vw';
    }

    const getInventoryWithUniqueID = (inventoryUniqueId: string) => {
        return inventories.value[inventoryUniqueId];
    }

    const event_mousemove = (ev: MouseEvent) => {
        store.value.cursorX = ev.clientX;
        store.value.cursorY = ev.clientY;
    }

    watch(() => interfaceOpened.value, (newValue) => {
        AxiosInstance.post("CLIENT_SET_INTERFACE_STATE", newValue)

        if (newValue) {
            addEventListener("mousemove", event_mousemove);
        }
        else {
            removeEventListener("mousemove", event_mousemove);

            let closeInventories: string[] = Object.values(inventories.value).filter(a => !a.isLocal).map(b => b.inventoryUniqueId);

            AxiosInstance.post("CLOSE_INVENTORIES", closeInventories);
        }
    });

    const playerInventory = computed(() => {
        return Object.values(inventories.value).find(a => a.isLocal);
    });

    return {
        store,
        getInventoryWithUniqueID,
        getItemWidthVW,
        getItemHeightVW,
        interfaceOpened,
        inventories,
        playerInventory
    }
});

// VoidLine: an empty Lua table serialises to JSON as `{}`, an object, not `[]`.
// Any inventory that reaches us with no items therefore arrives with `items` as
// an object, and the first `items.findIndex` in ADD_INVENTORY_ITEM throws --
// which kills the whole listener below, not just that one message. Normalise on
// the way in so the rest of this file can assume an array.
const asItemArray = (items: any) => {
    if (Array.isArray(items)) return items;
    return items ? Object.values(items) : [];
}

// VoidLine: the NUI had no keyboard handling whatsoever, so while the inventory
// held focus, Tab fell through to the browser's default behaviour -- walking the
// focus ring through every button and input. That is the "Tab selects things"
// problem; nothing was closing the panel because nothing was listening.
//
// Tab and Escape both close now. preventDefault runs even while typing, because
// the focus traversal is unwanted in the rename/note dialogs too -- only the
// close is suppressed there so text entry still behaves normally.
window.addEventListener("keydown", (ev: KeyboardEvent) => {
    const inventoryStore = useInventory();
    if (!inventoryStore.interfaceOpened) return;

    const target = ev.target as HTMLElement | null;
    const typing = !!target && (
        target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.isContentEditable
    );

    if (ev.key === "Tab") {
        ev.preventDefault();
        if (typing) return;
        inventoryStore.interfaceOpened = false;
        return;
    }

    if (ev.key === "Escape" && !typing) {
        ev.preventDefault();
        inventoryStore.interfaceOpened = false;
    }
});

window.addEventListener("message", (ev: MessageEvent) => {
    const inventoryStore = useInventory();

    if (ev.data.event == "ADD_OPENED_INVENTORY") {
        const inventory = inventoryStore.getInventoryWithUniqueID(ev.data.inventoryUniqueId);

        // VoidLine: upstream bailed out here (`if (inventory) return;`), so an
        // inventory could only ever be populated once. The ox bridge re-sends
        // the player inventory whenever ox changes underneath it, and every one
        // of those refreshes was being dropped on the floor -- the grid kept
        // showing whatever it had at first open.
        //
        // Refresh in place rather than delete-then-re-add: the store is never
        // left without the local inventory (components read it every frame),
        // and the user's search box state survives.
        if (inventory) {
            inventory.x = ev.data.x;
            inventory.y = ev.data.y;
            inventory.items = asItemArray(ev.data.items);
            inventory.maxWeight = ev.data.maxWeight;
            inventory.inventoryName = ev.data.inventoryName;
            inventory.isLocal = ev.data.isLocal;
            inventory.isFrisk = ev.data.isFrisk;

            // VoidLine: coordX/coordY were not carried through here at all, so
            // a panel could never be repositioned after it first appeared.
            // Applied only when the sender actually supplies them -- the ox
            // adapter sends them when the layout changes (a container opening
            // or closing) and omits them on ordinary item refreshes, so a panel
            // the player has dragged is not yanked back on every update.
            if (typeof ev.data.coordX === 'number') inventory.coordX = ev.data.coordX;
            if (typeof ev.data.coordY === 'number') inventory.coordY = ev.data.coordY;
            return;
        }

        inventoryStore.inventories[ev.data.inventoryUniqueId] = {
            inventoryUniqueId: ev.data.inventoryUniqueId,
            x: ev.data.x,
            y: ev.data.y,
            items: asItemArray(ev.data.items),
            maxWeight: ev.data.maxWeight,
            inventoryName: ev.data.inventoryName,
            isLocal: ev.data.isLocal,
            isFrisk: ev.data.isFrisk,
            coordX: ev.data.coordX,
            coordY: ev.data.coordY,
            searchInput: "",
            searchOpened: false
        }
    }
    else if (ev.data.event == "SET_INTERFACE_OPEN") {
        inventoryStore.interfaceOpened = ev.data.state;
    }
    else if (ev.data.event == "ADD_INVENTORY_ITEM") {
        const inventory = inventoryStore.getInventoryWithUniqueID(ev.data.inventoryUniqueId);
        if (!inventory) return;

        inventory.items = asItemArray(inventory.items);

        const itemIdx = inventory.items.findIndex(a => a.itemHash == ev.data.item.itemHash);
        if (itemIdx >= 0) {
            inventory.items[itemIdx] = ev.data.item;
        }
        else {
            inventory.items.push(ev.data.item);
        }
    }
    else if (ev.data.event == "REMOVE_INVENTORY_ITEM_WITH_HASH") {
        const inventory = inventoryStore.getInventoryWithUniqueID(ev.data.inventoryUniqueId);
        if (!inventory) return;

        inventory.items = asItemArray(inventory.items);

        const idx = inventory.items.findIndex(a => a.itemHash == ev.data.itemHash);
        if (idx >= 0) {
            inventory.items.splice(idx, 1);
        }
    }
    else if (ev.data.event == "REMOVE_OPENED_INVENTORY") {
        if (inventoryStore.inventories[ev.data.inventoryUniqueId]) {
            delete inventoryStore.inventories[ev.data.inventoryUniqueId];
        }
    }
    else if (ev.data.event == "SHORTKEYS_STATE") {
        inventoryStore.store.shortkeysOpened = ev.data.state;
    }
});