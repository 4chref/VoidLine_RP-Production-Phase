/* =============================================================================
   ox_inventory  <->  AVP Grid UI  translation layer

   The AVP Vue app is reused as-is: components, stores and stylesheets are
   AVP's own, which is what keeps the UI identical to the real thing. Only what
   feeds it changes, and that is all in this file.

     INBOUND   ox does SendNUIMessage({action = ...}). We keep a local model of
               each inventory, apply ox's updates to it, lay the items out on a
               grid, and hand the result to the AVP stores as the window
               messages they already understand.

     OUTBOUND  AVP components call AxiosInstance.post("ACTION", payload);
               axios.plugin.ts routes that here and we call the matching
               ox_inventory NUI callback with ox's payload shape.

   GRID vs SLOTS -- the one thing worth understanding
   ox is a slot inventory: 50 numbered slots, one item each, no geometry. AVP is
   a grid: items have a width and height and sit at an x/y. ox stores no x/y and
   no size, so both are produced here:

     * size  comes from SIZE/heuristics below, keyed on the item name.
     * x/y   comes from packing the items into the grid, lowest slot first.

   Consequence, stated plainly: exact placement is not preserved between
   openings, because there is nowhere in ox to persist it. Items settle into
   packed positions. Swapping, moving between inventories, splitting and
   dropping all still work, because those are expressed as slots, which ox does
   understand.
   ========================================================================== */

/** Player inventory grid. 15 wide as of 2026-08-19 (was 10). */
export const OX_COLS = 15;
export const OX_ROWS = 20;

/** Every other container -- stashes, trunks, gloveboxes, ground drops. */
export const OTHER_COLS = 10;
export const OTHER_ROWS = 7;

/**
 * Panel geometry, in vw, mirroring settings.store defaults (slotsize 2.0 +
 * slotborder 0.1 either side). Used only to work out where to put the windows;
 * the panels still size themselves from those settings.
 */
const CELL_VW = 2.2;
const PANEL_CHROME_VW = 1.2;   // header + footer + padding allowance
const PANEL_GAP_VW = 2.5;      // space between two open panels

/**
 * Left edge of the player grid, in vw. The clothing panel is `left: 5%` with a
 * 25vw character image behind it (views/Clothes.vue), so this clears it and
 * parks the grid immediately right of the Glasses / Earrings column.
 */
const CLOTHES_RIGHT_VW = 27;

/**
 * Top margin for the grid panels, as a fraction of viewport height. Matches
 * `.clothes-parent { top: 3% }` in views/Clothes.vue so the grid and the
 * clothing column start on the same line.
 */
const PANEL_TOP_FRACTION = 0.03;

type Side = 'player' | 'other';

const LEFT_UID = 'ox-player';
const RIGHT_UID = 'ox-other';

interface OxSlot {
    slot: number;
    name: string;
    count: number;
    weight?: number;
    metadata?: Record<string, any>;
}

/** Local mirror of what ox says each inventory holds, keyed by slot. */
interface Model {
    uid: string;
    side: Side;
    id: string | number;
    label: string;
    maxWeight: number;
    slots: number;
    cols: number;
    rows: number;
    coordX?: number;
    coordY?: number;
    items: Record<number, OxSlot>;
    /** grid cell -> slot, rebuilt on every pack; used to resolve a drop. */
    occupancy: Record<string, number>;
}

const models: Record<string, Model> = {};
let itemDefs: Record<string, any> = {};

/* -------------------------------------------------------------------------- */
/* item sizing                                                                 */
/* -------------------------------------------------------------------------- */

/**
 * Explicit sizes, in grid cells. Add to this freely -- it is the intended place
 * to tune how the inventory reads. Anything absent falls back to the heuristic
 * below.
 */
const SIZE: Record<string, [number, number]> = {
    // sidearms
    WEAPON_PISTOL: [3, 2],
    WEAPON_PISTOL_MK2: [3, 2],
    WEAPON_COMBATPISTOL: [3, 2],
    WEAPON_APPISTOL: [3, 2],
    WEAPON_HEAVYPISTOL: [3, 2],
    WEAPON_VINTAGEPISTOL: [3, 2],
    WEAPON_SNSPISTOL: [2, 1],
    WEAPON_PISTOL50: [3, 2],
    WEAPON_REVOLVER: [3, 2],
    WEAPON_STUNGUN: [3, 2],
    WEAPON_FLAREGUN: [3, 2],

    // long guns
    WEAPON_ASSAULTRIFLE: [5, 2],
    WEAPON_CARBINERIFLE: [5, 2],
    WEAPON_SPECIALCARBINE: [5, 2],
    WEAPON_BULLPUPRIFLE: [5, 2],
    WEAPON_PUMPSHOTGUN: [5, 2],
    WEAPON_SAWNOFFSHOTGUN: [3, 2],
    WEAPON_SNIPERRIFLE: [6, 2],
    WEAPON_MICROSMG: [3, 1],
    WEAPON_SMG: [4, 1],

    // melee / tools
    WEAPON_KNIFE: [1, 1],
    WEAPON_MACHETE: [3, 1],
    WEAPON_BAT: [4, 1],
    WEAPON_CROWBAR: [3, 1],
    WEAPON_FLASHLIGHT: [1, 1],
    WEAPON_PETROLCAN: [2, 2],
    WEAPON_FIREEXTINGUISHER: [2, 2],
    WEAPON_PARACHUTE: [2, 2],

    // common consumables / kit
    water: [1, 2],
    sandwich: [2, 1],
    phone: [1, 2],
    radio: [1, 2],
    identification: [2, 1],
    id_card: [2, 1],
    armour: [3, 3],
    bandage: [2, 1],
    money: [1, 1],
    black_money: [1, 1],
};

/**
 * Fallback when an item is not in SIZE. ox names weapons WEAPON_*, ammo ammo-*
 * and attachments at_*, which is enough to bucket them; everything else is
 * sized off its weight so heavy things read as bulky.
 */
const sizeFor = (name: string, weightGrams: number): [number, number] => {
    const explicit = SIZE[name];
    if (explicit) return explicit;

    const w = Number(weightGrams) || 0;

    if (name.startsWith('WEAPON_')) {
        if (w >= 3000) return [5, 2];
        if (w >= 1200) return [4, 1];
        if (w >= 700) return [3, 2];
        return [2, 1];
    }

    if (name.startsWith('ammo-')) return [2, 1];
    if (name.startsWith('at_')) return [2, 1];

    if (w >= 5000) return [3, 3];
    if (w >= 2000) return [2, 3];
    if (w >= 500) return [2, 2];
    if (w >= 150) return [1, 2];
    return [1, 1];
};

const sizeOfItem = (name: string): [number, number] => {
    const def = itemDefs[name];
    return sizeFor(name, def ? Number(def.weight) || 0 : 0);
};

/* -------------------------------------------------------------------------- */
/* remembered positions                                                        */
/* -------------------------------------------------------------------------- */

/**
 * Where the player put each slot, per inventory: { invKey: { slot: {x, y} } }.
 *
 * ox has nowhere to store a grid position -- it has no x/y on an item and no NUI
 * callback that could write one. So placement is remembered here instead and
 * mirrored into localStorage, which survives closing the inventory, relogging
 * and a resource restart on the same client.
 *
 * Slot is a stable identity in ox, so keying on it is sound: whatever ends up in
 * slot 7 draws where the player last put slot 7.
 */
type Cell = { x: number; y: number };

const positions: Record<string, Record<number, Cell>> = {};
const STORE_KEY = 'ox-avp-positions';

const posKey = (m: Model) => String(m.id ?? m.uid);

const loadPositions = () => {
    try {
        Object.assign(positions, JSON.parse(localStorage.getItem(STORE_KEY) || '{}'));
    } catch {
        /* corrupt or unavailable -- fall back to packing from scratch */
    }
};

/**
 * localStorage.setItem is synchronous and blocks the render thread, and
 * JSON.stringify walks every remembered cell of every inventory. packModel
 * called this on EVERY pack -- so every item change, every container refresh,
 * paid a full serialise-and-write on the main thread.
 *
 * Now it only writes when the serialised form actually differs, and coalesces
 * bursts (a cross-inventory move packs both grids back to back) into one write
 * on the next idle turn.
 */
let lastSaved = '';
let saveQueued = false;

const savePositions = () => {
    if (saveQueued) return;

    saveQueued = true;

    setTimeout(() => {
        saveQueued = false;

        try {
            const next = JSON.stringify(positions);
            if (next === lastSaved) return;

            localStorage.setItem(STORE_KEY, next);
            lastSaved = next;
        } catch {
            /* not fatal: positions just stop surviving a reload */
        }
    }, 0);
};

loadPositions();

try {
    lastSaved = JSON.stringify(positions);
} catch {
    /* leave empty -- worst case is one redundant write */
}

/**
 * Slots 1-10 of the player inventory are the hotkey slots -- ox binds hotkey<i>
 * straight to useSlot(i), and they are what the ten slot cards show.
 *
 * Raised from 5 on 2026-08-19. Three other places must agree with this number
 * or the extra slots half-work:
 *   - Clothes.vue           renders one card per slot (two rows of five)
 *   - ClothesItem.vue       the HOTKEY_SLOT_n regex that accepts a drop
 *   - ox_inventory/client.lua  the `for i = 1, N` keybind loop
 *   - modules/inventory/server.lua  keeps auto-placed items off the bar
 */
const HOTKEY_SLOTS = 10;

/* -------------------------------------------------------------------------- */
/* packing                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * First-fit: walk the grid row by row and drop each item into the first
 * rectangle that fits. Items are visited in slot order, so the layout is stable
 * for a stable inventory -- reopening does not shuffle things around.
 *
 * Also rebuilds the occupancy map, which is what turns a drop at (x, y) back
 * into the ox slot underneath it.
 */
const packModel = (m: Model) => {
    // A flat Int32Array indexed y * cols + x, rather than a Set of "x,y" strings.
    // fits() is called for every candidate cell of every item, so the string
    // version allocated a template literal per cell inspected -- tens of
    // thousands of throwaway strings per pack on a full 10x20 grid. This does
    // the same work with no allocation at all.
    //
    // 0 means free; any other value is the slot occupying that cell, which also
    // gives occupancy for free.
    const cells = new Int32Array(m.cols * m.rows);
    const placed: any[] = [];
    m.occupancy = {};

    const remembered = positions[posKey(m)] ?? {};

    const fits = (x: number, y: number, w: number, h: number) => {
        if (x + w > m.cols || y + h > m.rows) return false;

        for (let dy = 0; dy < h; dy++) {
            const row = (y + dy) * m.cols;
            for (let dx = 0; dx < w; dx++) {
                if (cells[row + x + dx] !== 0) return false;
            }
        }

        return true;
    };

    const occupy = (x: number, y: number, w: number, h: number, slot: number, s: OxSlot) => {
        for (let dy = 0; dy < h; dy++) {
            const gy = y + dy;
            const row = gy * m.cols;

            for (let dx = 0; dx < w; dx++) {
                const gx = x + dx;
                cells[row + gx] = slot;
                // Kept as a string map: it is read once per drop by cell key,
                // and building it here costs w*h writes rather than a scan.
                m.occupancy[`${gx},${gy}`] = slot;
            }
        }

        placed.push({
            item: s.name,
            quantity: s.count ?? 1,
            itemHash: `${m.uid}:${slot}`,
            meta: s.metadata ?? {},
            isRotated: false,
            x,
            y,
        });
    };

    const slotNums = Object.keys(m.items).map(Number).sort((a, b) => a - b);
    const unplaced: number[] = [];

    /**
     * A worn garment leaves the grid entirely and is drawn in its clothing slot.
     *
     * AVP already works this way: items carrying a `slotGUID` are filtered out
     * of the grid (views/Inventory.vue itemAtSlot) and picked up by the panel
     * (views/Clothes.vue atSlotGUID). So marking the item is the whole job --
     * no separate "worn" store, and the item never leaves ox, so it cannot be
     * lost by any of this.
     *
     * Which slot it belongs to is decided HERE from the item definition, not
     * from anything the wearing client said, so a garment can only ever land in
     * its own slot.
     */
    const wornGuid = (s: OxSlot): string | undefined => {
        if (!s.metadata?.worn) return undefined;
        return slotGuidFor(itemDefs[s.name]);
    };

    /**
     * Anything in a hotkey slot is drawn ONLY on its slot card, never in the
     * grid.
     *
     * Previously it appeared in both, and the grid copy could be dragged
     * elsewhere -- which changes its ox slot, and since the hotkey IS the ox
     * slot, that silently unbound it from the key. Now the only way to take it
     * off the bar is to drag it off the card, which is what "stays in the slot
     * until I remove it" means.
     */
    const hotkeyGuid = (slot: number): string | undefined =>
        slot >= 1 && slot <= HOTKEY_SLOTS ? `HOTKEY_SLOT_${slot}` : undefined;

    // Pass 1 -- honour where the player put things. A remembered cell wins over
    // packing order, which is what makes a move stick.
    for (const slot of slotNums) {
        const s = m.items[slot];
        if (!s || !s.name) continue;

        const guid = m.side === 'player' ? (wornGuid(s) ?? hotkeyGuid(slot)) : undefined;

        if (guid) {
            // Not placed on the grid at all -- it occupies no cells, so the
            // space it used to take is genuinely freed while it is worn.
            placed.push({
                item: s.name,
                quantity: s.count ?? 1,
                itemHash: `${m.uid}:${slot}`,
                meta: s.metadata ?? {},
                isRotated: false,
                x: 0,
                y: 0,
                slotGUID: guid,
            });

            continue;
        }

        const [w, h] = sizeOfItem(s.name);
        const at = remembered[slot];

        if (at && fits(at.x, at.y, w, h)) occupy(at.x, at.y, w, h, slot, s);
        else unplaced.push(slot);
    }

    // Pass 2 -- anything with no usable memory (new item, or its old cell is now
    // taken or too small) gets first-fit, and that becomes its remembered spot.
    for (const slot of unplaced) {
        const s = m.items[slot];
        const [w, h] = sizeOfItem(s.name);
        let done = false;

        for (let y = 0; y < m.rows && !done; y++) {
            for (let x = 0; x < m.cols && !done; x++) {
                if (!fits(x, y, w, h)) continue;

                occupy(x, y, w, h, slot, s);
                remembered[slot] = { x, y };
                done = true;
            }
        }
        // Grid full: the item stays in ox untouched, it just has nowhere to be
        // drawn. Leaving it out beats drawing it on top of something else.
    }

    positions[posKey(m)] = remembered;
    savePositions();

    return placed;
};

/**
 * Trade the remembered cells of two slots in the same inventory.
 *
 * Used when a swap is not driven by the player pointing at a cell -- assigning
 * to a hotkey card, for instance. ox moves the item to slot N, and because
 * placement is remembered per slot, the item would otherwise inherit whatever
 * cell slot N happened to have and appear to jump across the grid. Swapping the
 * cells alongside the slots keeps both items visually still.
 */
const swapRememberedCells = (uid: string, a: number, b: number) => {
    const m = models[uid];
    if (!m) return;

    const map = (positions[posKey(m)] ??= {});
    const pa = map[a];
    const pb = map[b];

    if (pb) map[a] = pb; else delete map[a];
    if (pa) map[b] = pa; else delete map[b];

    savePositions();
};

/**
 * Where an item goes when it is dropped on empty grid space rather than onto
 * another item.
 *
 * The hotkey slots are skipped on the first pass. Taking the lowest free slot
 * meant anything dropped on an empty cell landed in slot 1-5 and silently bound
 * itself to a number key -- move a coin around the grid and it would appear on a
 * slot card without ever being put there.
 *
 * They are still used as a last resort: refusing the move outright when the rest
 * of the inventory is full would be worse than filling a hotkey slot.
 */
const firstFreeSlot = (m: Model) => {
    const reserved = m.side === 'player' ? Math.min(HOTKEY_SLOTS, m.slots) : 0;

    for (let i = reserved + 1; i <= m.slots; i++) if (!m.items[i]) return i;
    for (let i = 1; i <= reserved; i++) if (!m.items[i]) return i;

    return null;
};

/* -------------------------------------------------------------------------- */
/* inbound: ox -> AVP                                                          */
/* -------------------------------------------------------------------------- */

const post = (event: string, payload: Record<string, any> = {}) =>
    window.postMessage({ event, ...payload }, '*');

export const parseHash = (hash: string): { uid: string; slot: number } | null => {
    if (typeof hash !== 'string') return null;
    const i = hash.lastIndexOf(':');
    if (i < 0) return null;
    const slot = parseInt(hash.slice(i + 1), 10);
    return isNaN(slot) ? null : { uid: hash.slice(0, i), slot };
};

/**
 * Which clothing-panel slot a garment belongs in.
 *
 * Keyed 'c<componentId>' / 'p<propId>' to match vl_clothing's wearComponent /
 * wearProp. Feeding this into AVP's own `canPutOnSlotGUID` means its existing
 * drop logic does the validation for us -- a hat simply will not drop onto the
 * shoes slot, with no extra checking here.
 */
const SLOT_GUID: Record<string, string> = {
    c1: 'MASK_SLOT',
    c4: 'PANTS_SLOT',
    c5: 'BACKPACK_SLOT',
    c6: 'SHOES_SLOT',
    c7: 'ACCESSORIES_SLOT',
    c8: 'SHIRT_SLOT',        // labelled "Undershirt" in the panel
    c9: 'BODY_ARMOUR_SLOT',
    c11: 'HOODIE_SLOT',
    p0: 'HAT_SLOT',
    p1: 'SUNGLASSES_SLOT',
    p2: 'EARRINGS_SLOT',
    p6: 'WATCH_SLOT',
    p7: 'BRACELET_SLOT',
};

/**
 * The clothing slot this item may be dropped on, if it is a garment at all.
 *
 * Read from the top level, not `client`: ox builds the NUI's item list as a
 * hand-picked subset (client.lua, ItemData) and `client` is not part of it.
 * wearComponent/wearProp are lifted into that subset there for exactly this.
 */
const slotGuidFor = (oxItem: any): string | undefined => {
    if (!oxItem) return undefined;

    if (typeof oxItem.wearProp === 'number') return SLOT_GUID['p' + oxItem.wearProp];
    if (typeof oxItem.wearComponent === 'number') return SLOT_GUID['c' + oxItem.wearComponent];

    return undefined;
};

const toAvpItemDefs = (oxItems: Record<string, any>) => {
    const out: Record<string, any> = {};

    for (const name in oxItems) {
        const it = oxItems[name] ?? {};
        const [width, height] = sizeFor(name, Number(it.weight) || 0);

        out[name] = {
            item: name,
            width,
            height,
            weight: (Number(it.weight) || 0) / 1000,
            formatName: it.label || name,
            description: it.description,
            isStackable: it.stack !== false,
            isUsable: true,
            tradable: true,
            deletable: true,
            // Drives AVP's clothing-slot drop check (components/ClothesItem.vue).
            canPutOnSlotGUID: (() => {
                const guid = slotGuidFor(it);
                return guid ? [guid] : undefined;
            })(),
        };
    }

    return out;
};

/** Push a model to the UI. ADD_OPENED_INVENTORY refreshes an open panel in place. */
const pushModel = (m: Model, withCoords = false) => {
    post('ADD_OPENED_INVENTORY', {
        inventoryUniqueId: m.uid,
        inventoryName: m.label,
        items: packModel(m),
        maxWeight: m.maxWeight,
        x: m.cols,
        y: m.rows,
        // Omitted on ordinary refreshes so a dragged panel stays where it was put.
        coordX: withCoords ? m.coordX : undefined,
        coordY: withCoords ? m.coordY : undefined,
        isLocal: m.side === 'player',
        isFrisk: false,
        searchInput: '',
        searchOpened: false,
    });
};

const buildModel = (uid: string, inv: any, side: Side): Model | null => {
    if (!inv) return null;

    /* A searched player's body is not a container -- it IS a 50-slot / 450kg
       player inventory, opened through ox's `otherplayer` type (see
       vl_corpseloot). Drawing it on the 10x7 container grid meant a body could
       show fewer cells than it can actually hold, so looted clothing and a full
       loadout had nowhere to sit. Give it the player geometry instead. */
    const isCorpse = side === 'other' && inv.type === 'otherplayer';

    const cols = side === 'player' || isCorpse ? OX_COLS : OTHER_COLS;
    const rows = side === 'player' || isCorpse ? OX_ROWS : OTHER_ROWS;

    const items: Record<number, OxSlot> = {};
    const src = inv.items ?? {};

    for (const k in src) {
        const s = src[k];
        if (s && s.name) {
            const slot = Number(s.slot ?? k);
            items[slot] = { slot, name: s.name, count: s.count ?? 1, metadata: s.metadata ?? {} };
        }
    }

    return {
        uid,
        side,
        id: inv.id,
        /* ox deliberately sends an EMPTY label for `otherplayer`
           (ox_inventory/server.lua:304), so the fallback is what actually
           shows. Without the isCorpse branch a searched body read 'Container'. */
        label: inv.label || (side === 'player' ? 'Inventory' : isCorpse ? 'Dead Body' : 'Container'),
        maxWeight: (Number(inv.maxWeight) || 0) / 1000,
        slots: Number(inv.slots) || 50,
        cols,
        rows,
        items,
        occupancy: {},
    };
};

/* -------------------------------------------------------------------------- */
/* window placement                                                            */
/* -------------------------------------------------------------------------- */

const panelWidthVw = (m: Model) => m.cols * CELL_VW + PANEL_CHROME_VW;
const panelHeightVw = (m: Model) => m.rows * CELL_VW + PANEL_CHROME_VW;

/**
 * Position the open panels. Without this every panel renders at the same
 * absolute origin and they sit on top of each other -- Inventory.vue reads
 * coordX/coordY straight into `left`/`top`.
 *
 * The container goes on the LEFT and the player inventory on the right, and the
 * pair is centred as a unit. A player inventory on its own is simply centred.
 *
 * Only a default: Inventory.vue restores a dragged position from localStorage
 * on mount, so anything the player moves by hand still wins afterwards.
 */
const layoutPanels = (player: Model | null, other: Model | null) => {
    const vw = window.innerWidth / 100;
    const toPx = (v: number) => Math.round(v * vw);

    if (!player) return;

    // Anchored to the clothing panel rather than centred as a pair. Centring
    // meant the player grid shifted sideways every time a container opened or
    // closed; anchoring keeps it planted so the layout always reads the same.
    player.coordX = toPx(CLOTHES_RIGHT_VW);

    // Both panels share a top edge, which is what makes them line up when the
    // container is much shorter than the player grid.
    //
    // VoidLine 2026-08-19: anchored to a top margin rather than vertically
    // centred. Centring pushed the whole layout down the screen; this starts it
    // near the top with a deliberate gap, matching the clothing column.
    //
    // The Math.min is the safety net: on a short viewport, or if the grid grows
    // past 20 rows, honouring the margin would push the bottom of the panel off
    // screen. In that case it rides as high as it can instead.
    const margin = Math.round(window.innerHeight * PANEL_TOP_FRACTION);
    const overflow = window.innerHeight - panelHeightVw(player) * vw;
    const top = Math.max(0, Math.min(margin, overflow));
    player.coordY = top;

    if (other) {
        other.coordX = toPx(CLOTHES_RIGHT_VW + panelWidthVw(player) + PANEL_GAP_VW);
        other.coordY = top;
    }
};


const applyRefresh = (data: any) => {
    if (!data) return;

    const list = Array.isArray(data.items) ? data.items : Object.values(data.items ?? {});
    const dirty = new Set<string>();

    for (const raw of list as any[]) {
        if (!raw) continue;

        const entry = raw.item ?? raw;

        // ox tags the player's own slots as 'player' (client.lua updateInventory)
        // and leaves everything else tagged with the *inventory's id* -- a stash
        // name, a drop id, a server id. It never sends the literal 'other', so
        // comparing against that string sent every container update into the
        // player model, quietly corrupting it: items vanished until a reopen
        // rebuilt everything from setupInventory.
        //
        // Only two inventories can be open at once, so anything not 'player'
        // belongs to whatever container is open -- and if none is, it is for an
        // inventory we are not showing and must be ignored rather than guessed.
        const uid = raw.inventory === 'player' ? LEFT_UID : RIGHT_UID;
        const m = models[uid];
        const slot = Number(entry.slot);
        if (!m || !slot) continue;

        if (entry.name) {
            m.items[slot] = {
                slot,
                name: entry.name,
                count: entry.count ?? 1,
                metadata: entry.metadata ?? {},
            };
        } else {
            delete m.items[slot];
        }

        dirty.add(uid);
    }

    // Re-pack and re-push wholesale rather than emitting per-item updates: a
    // single slot change can move every item after it, so a partial update
    // would leave the grid inconsistent with the packing.
    dirty.forEach((uid) => pushModel(models[uid]));
};

export const installInboundBridge = () => {
    window.addEventListener('message', (ev: MessageEvent) => {
        const msg: any = ev.data ?? {};
        if (!msg.action) return; // ignore our own posts

        const data = msg.data ?? {};

        switch (msg.action) {
            case 'init':
                if (data.items) {
                    itemDefs = data.items;
                    post('SET_CEF_ITEMS', { items: toAvpItemDefs(data.items) });
                }
                break;

            case 'setupInventory': {
                if (data.items) {
                    itemDefs = data.items;
                    post('SET_CEF_ITEMS', { items: toAvpItemDefs(data.items) });
                }

                const left = buildModel(LEFT_UID, data.leftInventory, 'player');

                // Opening with the inventory key sends defaultInventory as the
                // right panel -- type 'newdrop', a placeholder for "somewhere to
                // drop to" rather than a real container. Nothing to show for
                // that. A genuine stash, trunk, glovebox or an opened ground
                // drop has its own type and does open.
                const right = data.rightInventory;
                const other =
                    right && right.type && right.type !== 'newdrop'
                        ? buildModel(RIGHT_UID, right, 'other')
                        : null;

                // Positions are worked out for both together, before either is
                // pushed, so the pair lands centred instead of the second panel
                // shoving the first.
                layoutPanels(left, other);

                if (left) {
                    models[LEFT_UID] = left;
                    pushModel(left, true);
                }

                if (other) {
                    models[RIGHT_UID] = other;
                    pushModel(other, true);
                } else {
                    delete models[RIGHT_UID];
                    post('REMOVE_OPENED_INVENTORY', { inventoryUniqueId: RIGHT_UID });
                }

                post('SET_INTERFACE_OPEN', { state: true });
                break;
            }

            case 'refreshSlots':
                applyRefresh(data);
                break;

            case 'closeInventory':
                post('SET_INTERFACE_OPEN', { state: false });
                post('REMOVE_OPENED_INVENTORY', { inventoryUniqueId: RIGHT_UID });
                delete models[RIGHT_UID];

                // Re-centre the player grid for the next solo open, otherwise it
                // stays offset to where it sat beside the container.
                if (models[LEFT_UID]) {
                    layoutPanels(models[LEFT_UID], null);
                    pushModel(models[LEFT_UID], true);
                }
                break;

            case 'toggleHotbar':
                post('SHORTKEYS_STATE', { state: !!data.state });
                break;

            case 'itemNotify': {
                // ox sends a Lua array -- { itemData, localeKey, count } -- which
                // arrives as a JS array, not the object shape this originally
                // assumed. Reading .item/.count off it yielded undefined, so the
                // popup never had a name and never rendered.
                const notify: any[] = Array.isArray(data) ? data : [data];
                const slot = notify[0] ?? {};
                const name = slot.name;

                if (!name) break;

                post('ADD_YIELD', {
                    addedItemName: name,
                    addedQuantity: Number(notify[2]) || slot.count || 1,
                    // 'ui_added' | 'ui_removed' | 'ui_equipped' | 'ui_holstered'
                    yieldKind: notify[1] ?? 'ui_added',
                });
                break;
            }
        }
    });
};

/* -------------------------------------------------------------------------- */
/* outbound: AVP -> ox                                                         */
/* -------------------------------------------------------------------------- */

const resource = () =>
    // @ts-ignore -- injected by CEF
    typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ox_inventory';

const callOx = async (name: string, body: any = {}) => {
    try {
        const res = await fetch(`https://${resource()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body),
        });
        return { data: await res.json().catch(() => null) };
    } catch {
        return { data: null };
    }
};

const sideOf = (uid: string): Side => (uid === RIGHT_UID ? 'other' : 'player');

/**
 * How many units an action should move.
 *
 * ox normalises with `math.max(1, math.floor(data.count or 1))`, so a missing or
 * zero count means ONE item, never the stack. Every action therefore has to send
 * an explicit number.
 *
 * The Quantity box is the split control: 0 (its default) means "all of it", and
 * anything typed is clamped to what the slot actually holds.
 */
const resolveCount = (uid: string, slot: number, typed: any) => {
    const held = models[uid]?.items[slot]?.count ?? 1;
    const n = Number(typed);

    return n > 0 ? Math.min(n, held) : held;
};

/**
 * A move reported as "hash dropped on cell (x, y) of panel P" becomes ox's
 * "slot A of inventory X -> slot B of inventory Y".
 *
 * The target slot is whatever occupies the dropped-on cell -- that is a swap.
 * Landing on empty space has no slot of its own, so it becomes the first free
 * slot in the destination; the re-pack afterwards decides where it draws.
 */
const draggedItemMove = (p: any) => {
    const from = parseHash(p.grabbedItemHash);
    if (!from) return Promise.resolve({ data: null });

    const toUid: string = p.toInventoryUniqueID ?? from.uid;
    const target = models[toUid];
    if (!target) return Promise.resolve({ data: null });

    const count = resolveCount(from.uid, from.slot, p.quantity);
    const cell = { x: Number(p.dropToX), y: Number(p.dropToY) };

    // Dragging a worn garment out of its clothing slot means "take it off",
    // not "move it to another slot". Without this it would swap ox slots, stay
    // flagged worn, and snap straight back into the panel.
    //
    // The drop cell is remembered first, so once it is off it lands where the
    // player actually dropped it rather than wherever the packer would put it.
    const fromModel = models[from.uid];
    const dragged = fromModel?.items[from.slot];

    /* ...but only for YOUR OWN inventory. On someone else's -- a searched body
       (`side === 'other'`) -- a worn garment is drawn as an ordinary grid item,
       because the clothing-panel treatment is player-side only (see the
       `m.side === 'player'` test where wornGuid is applied). Dragging it there
       means "loot it", and routing that through useItem made the LOOTER use the
       victim's item instead of moving it, which is why worn clothing could only
       be taken with the ctrl+click quick-move path. */
    if (dragged?.metadata?.worn && fromModel?.side === 'player') {
        (positions[posKey(fromModel)] ??= {})[from.slot] = cell;
        savePositions();

        return callOx('useItem', from.slot);
    }

    const key = `${cell.x},${cell.y}`;
    const landedOn = target.occupancy[key];
    let toSlot: number | undefined = landedOn;

    if (!toSlot && toUid !== from.uid) {
        // Cross-inventory only: pulling coins out of a wreck should join the
        // pile you already carry rather than starting a new one.
        //
        // Deliberately NOT done for a move within the same grid. There, the
        // player picked an empty cell on purpose -- silently teleporting the
        // stack across the grid to merge with another pile is why the coins
        // looked stuck to the first cell no matter where they were dropped.
        // Dropping directly ONTO a stack still merges, via the occupancy hit
        // above.
        toSlot = mergeableSlot(target, dragged ?? fromModel!.items[from.slot]) ?? undefined;
    }

    if (!toSlot) {
        const free = firstFreeSlot(target);
        if (!free) return Promise.resolve({ data: null });
        toSlot = free;
    }

    if (toUid === from.uid && toSlot === from.slot) return Promise.resolve({ data: null });

    // Record the placement before the swap round-trips, so the re-pack that
    // follows ox's refreshSlots already knows where this belongs.
    //
    // Dropping onto an occupied cell is a swap: the item takes the cell the
    // player aimed at, and whatever was there inherits the cell it came from.
    // Dropping onto empty space just moves, so the source cell is forgotten.
    // ??= not ?? -- `?? {}` would hand back a throwaway object when the key is
    // missing and the deletes below would go nowhere.
    const src = (positions[posKey(models[from.uid] ?? target)] ??= {});
    const dst = (positions[posKey(target)] ??= {});
    const previous = src[from.slot];

    // A split leaves the source slot holding the remainder, so it keeps its
    // cell. Only a move that empties the slot should forget it.
    //
    // This was the bug behind "split 5 coins and the main stack jumps": the
    // source position was deleted unconditionally, so the remainder had nothing
    // remembered and the packer re-placed it wherever it happened to fit.
    const held = fromModel?.items[from.slot]?.count ?? 1;
    const partial = count < held;

    dst[toSlot] = cell;

    if (landedOn && previous && toUid === from.uid) {
        // Swap: the displaced item inherits the cell this one came from.
        src[from.slot] = previous;
    } else if (!partial) {
        delete src[from.slot];
    }

    savePositions();

    // Count must always be sent. ox does `data.count = math.max(1, math.floor(
    // data.count or 1))`, so omitting it moves exactly one item rather than the
    // stack -- which is why dragging a stack only ever moved a single unit.
    //
    // The Quantity box is the split control: 0 (its default) means "all", and a
    // typed value is clamped to what is actually held.
    return callOx('swapItems', {
        fromSlot: from.slot,
        toSlot,
        fromType: sideOf(from.uid),
        toType: sideOf(toUid),
        count,
        instance: target.id,
    });
};

/** Deep value equality, enough for the flat-ish metadata ox items carry. */
const sameMeta = (a: any, b: any): boolean => {
    if (a === b) return true;
    if (!a || !b) return !a === !b || (!Object.keys(a || {}).length && !Object.keys(b || {}).length);
    if (typeof a !== 'object' || typeof b !== 'object') return a === b;

    const ka = Object.keys(a);
    const kb = Object.keys(b);
    if (ka.length !== kb.length) return false;

    return ka.every((k) => sameMeta(a[k], b[k]));
};

/**
 * A slot in `target` holding the same item with the same metadata, which ox
 * would merge into.
 *
 * Without this, dropping on empty grid space took the first FREE slot, so every
 * transfer of an already-held item started a fresh stack -- three separate piles
 * of coins sitting in slots 12, 13 and 14 rather than one.
 */
const mergeableSlot = (target: Model, s: OxSlot): number | null => {
    const def = itemDefs[s.name];
    if (def && def.stack === false) return null; // unique items never merge

    const slots = Object.keys(target.items).map(Number).sort((a, b) => a - b);

    for (const slot of slots) {
        const other = target.items[slot];
        if (other?.name === s.name && sameMeta(other.metadata, s.metadata)) return slot;
    }

    return null;
};

/**
 * Where a quick-moved item should land.
 *
 * Prefer an existing stack of the same item so ctrl-clicking five coins across
 * merges them instead of scattering them over five slots -- ox stacks on its own
 * when the target slot holds a matching item. Otherwise take the first free
 * slot, which for the player inventory already skips the hotkey slots.
 */
const quickMoveSlot = (target: Model, itemName: string) => {
    const slots = Object.keys(target.items).map(Number).sort((a, b) => a - b);

    for (const slot of slots) {
        if (target.items[slot]?.name === itemName) return slot;
    }

    return firstFreeSlot(target);
};

const OUTBOUND: Record<string, (p: any) => Promise<any>> = {
    CEF_LOADED: () => callOx('uiLoaded'),

    /**
     * ctrl + left click: send the item to whichever inventory is not the one it
     * is in. With no container open there is nowhere to send it, so it is a
     * no-op rather than an error.
     */
    QUICK_MOVE: (p) => {
        const h = parseHash(p.grabbedItemHash ?? p.itemHash);
        if (!h) return Promise.resolve({ data: null });

        const from = models[h.uid];
        const toUid = h.uid === LEFT_UID ? RIGHT_UID : LEFT_UID;
        const target = models[toUid];

        if (!from || !target) return Promise.resolve({ data: null });

        const item = from.items[h.slot];
        if (!item) return Promise.resolve({ data: null });

        const toSlot = quickMoveSlot(target, item.name);
        if (!toSlot) return Promise.resolve({ data: null });

        return callOx('swapItems', {
            fromSlot: h.slot,
            toSlot,
            fromType: sideOf(h.uid),
            toType: sideOf(toUid),
            count: resolveCount(h.uid, h.slot, 0),
            instance: target.id,
        });
    },

    DRAGGED_ITEM_MOVE: draggedItemMove,

    // ContextMenu sends grabbedItemHash; the nearby/give path sends itemHash.
    // Accept either rather than depending on which component called.
    // ox's handler is `function(slot, cb)` -- it takes the slot as the whole
    // body, not an object with a slot field. Sending {slot: n} made useSlot()
    // receive a table and silently do nothing, which is why Use did not fire.
    USE_ITEM: (p) => {
        const h = parseHash(p.grabbedItemHash ?? p.itemHash);
        return h ? callOx('useItem', h.slot) : Promise.resolve({ data: null });
    },

    /**
     * The nearby-player list behind the Give button.
     *
     * nearbyStore.open() expects `response.data` to be an array of
     * { serverId, name } and quietly closes itself if it is not -- which is
     * exactly why Give looked dead: nothing answered this, so it got null.
     */
    NEARBY_GET_PLAYERS: () => callOx('nearbyPlayers'),

    /**
     * Hand the item over once a player is picked.
     *
     * Deliberately NOT ox's own `giveItem` callback: that ignores any target
     * and opens ox's lib menu to pick one, which would stack a second picker on
     * top of the AVP list. `giveToPlayer` gives straight to the chosen id.
     */
    GIVE_ITEM_TO_TARGET: async (p) => {
        const h = parseHash(p.itemHash ?? p.grabbedItemHash);
        const serverId = Number(p.serverId);

        if (!h || !serverId) return { data: null };

        // Same reasoning as dropping: it must come off you before it leaves you.
        // Player-side only -- a garment on a searched body is not on YOUR ped,
        // and useItem here would make you use the victim's item.
        if (models[h.uid]?.side === 'player' && models[h.uid]?.items[h.slot]?.metadata?.worn) {
            await callOx('useItem', h.slot);
        }

        return callOx('giveToPlayer', {
            slot: h.slot,
            serverId,
            count: resolveCount(h.uid, h.slot, p.quantity),
        });
    },

    /**
     * Dropping a garment you are wearing takes it off first.
     *
     * `worn` lives in the item's metadata, so a dropped garment kept the flag
     * and the ped kept wearing it -- a shirt on the floor and still on your
     * back. Toggling it off before the drop clears both the flag and the ped.
     */
    DROP_ITEM_ON_GROUND: async (p) => {
        const h = parseHash(p.grabbedItemHash ?? p.itemHash);
        if (!h) return { data: null };

        // Player-side only, for the same reason as GIVE_ITEM_TO_TARGET above.
        if (models[h.uid]?.side === 'player' && models[h.uid]?.items[h.slot]?.metadata?.worn) {
            await callOx('useItem', h.slot);
        }

        return callOx('swapItems', {
            fromSlot: h.slot,
            toSlot: 1,
            fromType: sideOf(h.uid),
            toType: 'newdrop',
            count: resolveCount(h.uid, h.slot, p.quantity),
        });
    },

    ITEM_REMOVE_ATTACHMENT_WEAPON: (p) => {
        const h = parseHash(p.itemHash);
        return h
            ? callOx('removeComponent', { slot: h.slot, component: p.attachmentIndex })
            : Promise.resolve({ data: null });
    },

    /**
     * Dropping an item onto one of the five slot cards. ox's hotkeys are hard
     * bound to inventory slots 1-5, so "assign to hotkey N" is just a swap into
     * slot N -- no separate hotbar state to keep.
     */
    HOTKEY_ASSIGN: (p) => {
        const h = parseHash(p.grabbedItemHash ?? p.itemHash);
        const slot = Number(p.slot);

        if (!h || !slot) return Promise.resolve({ data: null });
        if (h.uid === LEFT_UID && h.slot === slot) return Promise.resolve({ data: null });

        // Clothing does not belong on the quick-use bar. Pressing a number key
        // would toggle the garment on and off, which is not what a hotkey is
        // for, and it would occupy a slot meant for consumables.
        const src = models[h.uid]?.items[h.slot];
        if (src && itemDefs[src.name]?.wearable) return Promise.resolve({ data: null });

        if (h.uid === LEFT_UID) {
            // Same inventory: keep both items where they are on screen.
            swapRememberedCells(LEFT_UID, h.slot, slot);
        } else {
            // Coming from a container -- it has no cell here yet, so let the
            // packer place it rather than inheriting the target slot's spot.
            const player = models[LEFT_UID];

            if (player) {
                delete (positions[posKey(player)] ??= {})[slot];
                savePositions();
            }
        }

        return callOx('swapItems', {
            fromSlot: h.slot,
            toSlot: slot,
            fromType: sideOf(h.uid),
            toType: 'player',
            count: resolveCount(h.uid, h.slot, p.quantity),
            instance: models[LEFT_UID]?.id,
        });
    },

    // The red dot on a container header posts CLOSE_INVENTORY (singular); the
    // interface-wide close posts CLOSE_INVENTORIES. Only the plural was mapped,
    // so clicking the dot did nothing at all.
    //
    // Both become ox's `exit`: ox has a single open container at a time and no
    // notion of closing just the right panel, so closing the stash is closing
    // the inventory.
    /**
     * Dropped onto a clothing slot in the panel. Wearing IS using for these
     * items -- vl_clothing.wear is the item's use export -- so this is just
     * useItem on the dragged garment's slot.
     */
    WEAR_ITEM_ON_SLOTGUID: (p) => {
        const h = parseHash(p.itemHash ?? p.grabbedItemHash);
        return h ? callOx('useItem', h.slot) : Promise.resolve({ data: null });
    },

    CLOSE_INVENTORY: () => callOx('exit'),
    CLOSE_INVENTORIES: () => callOx('exit'),
    CLIENT_SET_INTERFACE_STATE: (p) =>
        p?.state === false ? callOx('exit') : Promise.resolve({ data: null }),
};

/**
 * Stands in for the axios instance the AVP components import. They only ever
 * call .post() and await its `.data`, so matching that shape is enough.
 */
export const OxAxiosShim = {
    post: (action: string, payload: any = {}) => {
        const fn = OUTBOUND[action];
        // AVP-only feature with no ox equivalent (bags, notes, renaming,
        // clothing). Resolve so the caller's await does not hang.
        return fn ? fn(payload) : Promise.resolve({ data: null });
    },
};
