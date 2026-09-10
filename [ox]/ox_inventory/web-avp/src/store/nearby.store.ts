import { defineStore } from "pinia";
import { ref, watch } from "vue";
import { AxiosInstance } from "../plugins/axios.plugin";
import { useInventory } from "./inventory.store";

export const useNearbyStore = defineStore("NearbyStore", () => {

    const inventoryStore = useInventory();

    const isOpened = ref(false);
    const nearPlayers = ref<{ serverId: number; name: string; }[]>([]);

    const itemHash = ref<string | null>(null);

    function open(iHash: string) {
        itemHash.value = iHash;

        AxiosInstance.post("NEARBY_GET_PLAYERS").then(response => {
            const players = response.data;
            if (Array.isArray(players) && players.length > 0) {
                nearPlayers.value = players;
                isOpened.value = true;
            }
            else {
                isOpened.value = false;
            }
        });
    }

    function give(serverId: number) {
        AxiosInstance.post("GIVE_ITEM_TO_TARGET", {
            itemHash: itemHash.value,
            serverId: serverId,
            quantity: inventoryStore.store.quantityInput
        });

        isOpened.value = false;
        itemHash.value = null;
    }

    watch(() => inventoryStore.interfaceOpened, (newState) => {
        if (!newState) isOpened.value = false;
    });

    return {
        isOpened,
        nearPlayers,
        open,
        give
    }
});