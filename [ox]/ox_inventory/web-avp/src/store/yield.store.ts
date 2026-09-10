import { defineStore } from "pinia";
import { ref } from "vue";
import { useItemsStore } from "./items.store";
import { I_ItemData } from "../types/item_data";

/** 'ui_added' | 'ui_removed' | 'ui_equipped' | 'ui_holstered' -- ox's own keys. */
export type YieldKind = string;

interface YieldState {
    item: string;
    uniqueId: number;
    quantity: number;
    iData: I_ItemData;
    kind: YieldKind;
}

export const useYieldStore = defineStore("YieldStore", () => {

    const itemsStore = useItemsStore();
    const YIELD_EXIST_TIME = 7500;
    let uniqueCounter = 1;

    const yields = ref<YieldState[]>([]);

    function addYield(addedItemName: string, addedQuantity: number, kind: YieldKind = 'ui_added') {
        const iData = itemsStore.getItemData(addedItemName);
        if (!iData) return;

        const newUnique = uniqueCounter + 1;

        uniqueCounter++;

        yields.value.push({
            item: addedItemName,
            quantity: addedQuantity,
            iData,
            kind,
            uniqueId: newUnique
        });

        setTimeout(() => {
            const idx = yields.value.findIndex(a => a.uniqueId == newUnique);
            if (idx >= 0) {
                yields.value.splice(idx, 1);
            }
        }, YIELD_EXIST_TIME);
    }

    return {
        yields,
        addYield
    }
});

window.addEventListener("message", (ev: MessageEvent) => {
    const yieldStore = useYieldStore();

    if (ev.data.event == "ADD_YIELD") {
        yieldStore.addYield(ev.data.addedItemName, ev.data.addedQuantity, ev.data.yieldKind);
    }
});