import { defineStore } from "pinia";
import { ref, watch } from "vue";
import { useInventory } from "./inventory.store";

interface InputState {
    headerLabel?: string;
    description?: string;
    descriptionHtml?: boolean;
    hasAccept?: boolean;
    acceptLabel?: string;
    acceptCallback?: (newName: string | undefined) => void;
    hasCancel?: boolean;
    cancelLabel?: string;
    cancelCallback?: () => void;
    nameInput?: string | undefined;
}

export const useInputStore = defineStore("InputStore", () => {

    const inventoryStore = useInventory();

    const isOpened = ref(false);
    const store = ref<InputState>({});

    function cancel() {
        isOpened.value = false;

        if (typeof store.value.cancelCallback === 'function') {
            store.value.cancelCallback();
        }
    }

    function accept() {
        isOpened.value = false;

        if (typeof store.value.acceptCallback === 'function') {
            store.value.acceptCallback(store.value.nameInput);
        }
    }

    function open(d: InputState) {
        store.value = d;
        isOpened.value = true;
    }

    /** Reset on interface close. */
    watch(() => inventoryStore.interfaceOpened, (newState) => {
        if (!newState) isOpened.value = false;
    });

    return {
        store,
        isOpened,
        cancel,
        accept,
        open
    }
});