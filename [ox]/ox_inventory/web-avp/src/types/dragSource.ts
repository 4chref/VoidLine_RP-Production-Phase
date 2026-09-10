import { I_Item } from "./item";

export interface I_DragSource {
    image?: string;

    inventoryItem?: {
        uniqueID: string;
        item: I_Item;
    }

    attachmentItem?: {
        attachmentIndex: number;
        attachmentName: string;
        fromUniqueID: string;
        fromItemHash: string;
    }
}

export enum DRAG_SOURCE_TYPES {
    WEAPON_ATTACHMENT = "WEAPON_ATTACHMENT",
    INVENTORY_ITEM = "INVENTORY_ITEM"
}