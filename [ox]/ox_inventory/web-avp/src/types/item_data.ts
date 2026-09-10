export interface I_ItemData {
    item: string;
    width: number;
    height: number;
    isStackable?: boolean;
    tradable?: boolean;
    deletable?: boolean;
    weight: number;
    formatName: string;
    bagSize?: { x: number; y: number; };
    propId?: number;
    clothingId?: number;
    droppedModel?: string;
    rarity?: string;
    rarityColor?: [number, number, number, number];
    description?: string;
    generateSerial?: boolean;
    isAmmo?: boolean;
    isBodyArmour?: boolean;
    weaponHash?: number;
    isUsable?: boolean;
    canPutOnSlotGUID?: string[];
}