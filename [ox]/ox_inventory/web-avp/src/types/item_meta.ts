export interface I_ItemMetaData {
    durability?: number;
    drawable?: number;
    texture?: number;
    customName?: string;
    note?: string;
    imageName?: string;
    attachments?: string[];
    serial?: string;
    /**
     * Set by vl_clothing when a garment goes on, cleared when it comes off.
     * ContextMenu reads it to swap Use/Drop for Remove.
     */
    worn?: boolean;
}