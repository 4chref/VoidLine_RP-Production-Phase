import { I_ItemMetaData } from "./item_meta";

export interface I_Item {
    item: string;
    quantity: number;
    x: number;
    y: number;
    isRotated: boolean;
    itemHash: string;
    meta: I_ItemMetaData;
    slotGUID?: string;
}
