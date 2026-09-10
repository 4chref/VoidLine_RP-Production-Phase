import { defineStore } from "pinia";
import { ref } from "vue";
import { I_ItemData } from "../types/item_data";

export const useItemsStore = defineStore("ItemsStore", () => {

    const Items = ref<{ [item: string]: I_ItemData }>({});

    if (import.meta.env.DEV) {
        Items.value["WEAPON_ASSAULTRIFLE"] = {
            height: 3,
            width: 5,
            item: 'WEAPON_ASSAULTRIFLE',
            weight: 2.0,
            formatName: 'Assault Rifle',
            rarity: 'Legendary',
            rarityColor: [255, 215, 0, 0.15],
            weaponHash: 231321312831287
        }
    }

    const getItemData = (item: string) => {
        return Items.value[item];
    }

    return {
        Items,
        getItemData
    }
});

window.addEventListener("message", (ev) => {
    const itemsStore = useItemsStore();

    if (ev.data.event == "SET_CEF_ITEMS") {
        itemsStore.Items = ev.data.items;
    }
});