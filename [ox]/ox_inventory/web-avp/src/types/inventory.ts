import { I_Item } from "./item";

export interface I_Inventory {
    inventoryUniqueId: string;
    x: number;
    y: number;
    items: I_Item[];
    maxWeight: number;
    inventoryName: string;
    coordX?: number;
    coordY?: number;

    isLocal?: boolean;
    isFrisk?: boolean;
    searchInput: string;
    searchOpened: boolean;
}