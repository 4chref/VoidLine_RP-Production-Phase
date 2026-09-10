<template>
    <div class="clothes-parent" :style="{
        filter: (contextMenuStore.opened || inputStore.isOpened || nearbyStore.isOpened) ? 'blur(2px)' : ''
    }">
        <!-- VoidLine: the Myself/Target selector is removed. Target drove AVP's
             frisk inventory, which ox has no equivalent for, and a lone
             "Myself" tab is just noise. -->

        <div class="character-image"></div>

        <!-- BODY CONDITION
             VoidLine: replaced the thirteen AVP clothing slots that used to sit
             here. They read `selectedWeared`, which ox_inventory never
             populates, so they were permanently empty decoration -- nothing
             functional was lost. The hotkey slots below ARE real and untouched.

             Cards sit at the outer edges with a leader line running back to the
             part they describe, so nothing overlaps the silhouette.

             Severity comes from qbx_medical (1-4 per body part) via
             modules/bodydamage/client.lua, which groups its fifteen parts into
             these five and reports the worst of each. -->

        <!-- Leader lines. One SVG behind the cards rather than a border trick
             per card: the endpoints are arbitrary points on the silhouette, not
             box edges. preserveAspectRatio="none" lets the 0-100 viewBox map
             straight onto the container's own percentage coordinates, so the
             numbers below are the same units as the card `left`/`top`. -->
        <svg class="dmg-lines" viewBox="0 0 100 100" preserveAspectRatio="none">
            <defs>
                <!-- One gradient per line, running along that line's own axis
                     (gradientUnits="userSpaceOnUse" means these coordinates are
                     the same viewBox units as the line itself). The leader
                     fades up out of nothing at the card and arrives solid at
                     the dot, so the eye is pulled toward the body part. -->
                <linearGradient v-for="ind in indicators" :key="'grad-' + ind.key"
                    :id="'dmgline-' + ind.key" gradientUnits="userSpaceOnUse"
                    :x1="ind.line.x1" :y1="ind.line.y1" :x2="ind.line.x2" :y2="ind.line.y2">
                    <stop offset="0%" stop-color="#ffffff" stop-opacity="0" />
                    <stop offset="55%" stop-color="#ffffff" stop-opacity="0.55" />
                    <stop offset="100%" stop-color="#ffffff" stop-opacity="0.95" />
                </linearGradient>
            </defs>
            <line v-for="ind in indicators" :key="ind.key"
                :x1="ind.line.x1" :y1="ind.line.y1" :x2="ind.line.x2" :y2="ind.line.y2"
                :stroke="'url(#dmgline-' + ind.key + ')'" />
        </svg>

        <!-- Endpoint dots are DIVs, not <circle> elements. The SVG above is
             stretched by preserveAspectRatio="none", which would squash a
             circle into an ellipse; a div sized in vw stays round whatever the
             container's aspect ratio does. -->
        <div v-for="ind in indicators" :key="'dot-' + ind.key" class="dmg-dot"
            :style="{ left: ind.line.x2 + '%', top: ind.line.y2 + '%' }"></div>

        <div v-for="ind in indicators" :key="ind.key" class="dmg-card" :class="dmgClass(ind.key)"
            :style="ind.style">
            <div class="dmg-name">{{ ind.label }}</div>
            <div class="dmg-value">{{ condition(ind.key) }}%</div>
            <div class="dmg-bar">
                <div class="dmg-fill" :style="{ width: condition(ind.key) + '%' }"></div>
            </div>
        </div>

        <!-- SLOTS -->
        <!-- Two rows of five. Row 2 sits `calc(105% + 4.5vw)` down: the cards
             are 3.5vw tall, so that is a 1vw gutter, and mixing % with vw keeps
             the gap fixed regardless of how tall the container renders. -->
        <ClothesItem slot-guid="HOTKEY_SLOT_1" :inv_unique_id="iUniqueId" :item="atHotkey(1)"
            :show-quantity="true" name="Slot (1)" :height="3.5" :width="3.5" :style="{
                    left: '8%',
                    top: '105%'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_2" :inv_unique_id="iUniqueId" :item="atHotkey(2)"
            :show-quantity="true" name="Slot (2)" :height="3.5" :width="3.5" :style="{
                    left: '25%',
                    top: '105%'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_3" :inv_unique_id="iUniqueId" :item="atHotkey(3)"
            :show-quantity="true" name="Slot (3)" :height="3.5" :width="3.5" :style="{
                    left: '42%',
                    top: '105%'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_4" :inv_unique_id="iUniqueId" :item="atHotkey(4)"
            :show-quantity="true" name="Slot (4)" :height="3.5" :width="3.5" :style="{
                    left: '59%',
                    top: '105%'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_5" :inv_unique_id="iUniqueId" :item="atHotkey(5)"
            :show-quantity="true" name="Slot (5)" :height="3.5" :width="3.5" :style="{
                    left: '76%',
                    top: '105%'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_6" :inv_unique_id="iUniqueId" :item="atHotkey(6)"
            :show-quantity="true" name="Slot (6)" :height="3.5" :width="3.5" :style="{
                    left: '8%',
                    top: 'calc(105% + 4.5vw)'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_7" :inv_unique_id="iUniqueId" :item="atHotkey(7)"
            :show-quantity="true" name="Slot (7)" :height="3.5" :width="3.5" :style="{
                    left: '25%',
                    top: 'calc(105% + 4.5vw)'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_8" :inv_unique_id="iUniqueId" :item="atHotkey(8)"
            :show-quantity="true" name="Slot (8)" :height="3.5" :width="3.5" :style="{
                    left: '42%',
                    top: 'calc(105% + 4.5vw)'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_9" :inv_unique_id="iUniqueId" :item="atHotkey(9)"
            :show-quantity="true" name="Slot (9)" :height="3.5" :width="3.5" :style="{
                    left: '59%',
                    top: 'calc(105% + 4.5vw)'
                }" />

        <ClothesItem slot-guid="HOTKEY_SLOT_10" :inv_unique_id="iUniqueId" :item="atHotkey(10)"
            :show-quantity="true" name="Slot (10)" :height="3.5" :width="3.5" :style="{
                    left: '76%',
                    top: 'calc(105% + 4.5vw)'
                }" />

    </div>
</template>

<script lang="ts" setup>
import { computed, ref, onMounted, onUnmounted } from "vue";
import ClothesItem from "../components/ClothesItem.vue";
import { useInventory } from "../store/inventory.store";
import { useContextMenuStore } from "../store/contextmenu.store";
import { useInputStore } from "../store/input.store";
import { useNearbyStore } from "../store/nearby.store";

const inventoryStore = useInventory();
const contextMenuStore = useContextMenuStore();
const inputStore = useInputStore();
const nearbyStore = useNearbyStore();

const me = ref(true);

const friskedInventory = computed(() => {
    return Object.values(inventoryStore.inventories).find(a => a.isFrisk);
});

function setFriskTarget() {
    if (isFrisking.value) {
        me.value = false;
    }
}

const iUniqueId = computed(() => {
    return me.value ? inventoryStore.playerInventory?.inventoryUniqueId : friskedInventory.value?.inventoryUniqueId;
});

const selectedWeared = computed(() => {
    return me.value ?
        inventoryStore.playerInventory?.items.filter(a => typeof a.slotGUID === 'string')
        :
        friskedInventory.value?.items.filter(a => typeof a.slotGUID === 'string');
});

const isFrisking = computed(() => {
    return friskedInventory.value ? true : false;
});

/**
 * VoidLine: the five Slot cards are ox inventory slots 1-5, not AVP "worn"
 * items. ox binds hotkey<i> straight to useSlot(i) in client.lua, so whatever
 * sits in slot N is exactly what pressing N uses -- the card just shows it.
 */
const atHotkey = (n: number) => {
    return inventoryStore.playerInventory?.items.find(a => a.itemHash === `ox-player:${n}`);
};

/**
 * Body-damage indicators. Positions mirror the old clothing-slot layout so the
 * silhouette stays framed the same way: head above, arms either side, body
 * centre, legs below.
 */
type DamageEntry = { severity: number; percent: number };
const damage = ref<Record<string, DamageEntry>>({});

const indicators = [
    // left/top place the card; line.x1,y1 is the card's inner edge and x2,y2
    // the point on the silhouette it points at. Both in container percent.
    //
    // The arms are deliberately crossed: the card on the LEFT of the panel is
    // the character's RIGHT arm. The silhouette faces the camera, so its left
    // side appears on the viewer's right -- labelling by screen side had them
    // backwards.
    //
    // Arm endpoints sit lower (y 52) than the torso: the arms hang well below
    // shoulder height, and anchoring them level with the chest left the dots
    // floating in the gap beside the body instead of on the limb.
    { key: "head", label: "Head",      style: { left: "0%",  top: "3%"  }, line: { x1: 23, y1: 7,  x2: 49, y2: 11 } },
    { key: "rarm", label: "Right Arm", style: { left: "0%",  top: "36%" }, line: { x1: 23, y1: 40, x2: 37, y2: 57 } },
    { key: "legs", label: "Legs",      style: { left: "0%",  top: "69%" }, line: { x1: 23, y1: 73, x2: 47, y2: 78 } },
    { key: "body", label: "Body",      style: { left: "77%", top: "17%" }, line: { x1: 77, y1: 21, x2: 53, y2: 33 } },
    { key: "larm", label: "Left Arm",  style: { left: "77%", top: "50%" }, line: { x1: 77, y1: 54, x2: 66, y2: 52 } },
];
/**
 * Condition REMAINING, not damage taken: an untouched part reads 100% and drops
 * as it is injured. qbx_medical caps severity at 4, so the scale lands on
 * 100 / 75 / 50 / 25 / 0 -- there is no finer resolution to show.
 */
function condition(key: string) {
    return 100 - (damage.value[key]?.percent ?? 0);
}
// Banding is by SEVERITY, not the percentage: severity is the value qbx_medical
// actually reasons about, and mapping colour off the rounded percent would put
// the boundaries in slightly the wrong places.
function dmgClass(key: string) {
    const s = damage.value[key]?.severity ?? 0;
    if (s <= 0) return "dmg-ok";
    if (s === 1) return "dmg-light";
    if (s === 2) return "dmg-moderate";
    if (s === 3) return "dmg-heavy";
    return "dmg-critical";
}
function onDamageMessage(event: MessageEvent) {
    if (event.data?.action === "bodyDamage") {
        damage.value = event.data.data ?? {};
    }
}

onMounted(async () => {
    window.addEventListener("message", onDamageMessage);
    // Ask for a snapshot: statebag handlers only push on CHANGE, so without
    // this the panel shows a clean body until the player's next injury.
    try {
        const res = await fetch("https://ox_inventory/bodyDamage:request", {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: "{}",
        });
        damage.value = (await res.json()) ?? {};
    } catch (e) {
        // NUI unavailable (browser preview) -- leave the indicators at zero.
    }
});

onUnmounted(() => window.removeEventListener("message", onDamageMessage));

const atSlotGUID = (slotGUID: string) => {
    return selectedWeared.value?.find(a => {
        return a.slotGUID == slotGUID;
    });
}

</script>


<style lang="scss" scoped>
$textstroke: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000;


/* VoidLine: body-damage indicators (replaced the clothing slots). */
.dmg-lines {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    overflow: visible;

    line {
        /* No `stroke` here on purpose: the colour comes from a per-line
           gradient bound in the template, and a CSS stroke would beat that
           presentation attribute and flatten the fade. */
        stroke-width: 2px;
        stroke-linecap: round;
        /* The viewBox is stretched by preserveAspectRatio="none", which would
           smear the stroke thickness with it. This keeps it even. */
        vector-effect: non-scaling-stroke;
    }
}

.dmg-dot {
    position: absolute;
    width: 0.55vw;
    height: 0.55vw;
    /* Centred on its coordinate, so the value in `indicators` is the point the
       line actually terminates at rather than the dot's top-left corner. */
    transform: translate(-50%, -50%);
    border-radius: 50%;
    background: #ffffff;
    box-shadow: 0 0 0.3vw rgba(0, 0, 0, 0.8);
    pointer-events: none;
}

.dmg-card {
    position: absolute;
    width: 23%;
    padding: 0.45vw 0.5vw;
    box-sizing: border-box;
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 3px;
    /* Same fill the inventory slots use (see ClothesItem.vue .clothes-item):
       a 45-degree hatch over a grey wash, so these cards read as part of the
       same UI rather than as a separate overlay. */
    background: repeating-linear-gradient(-45deg,
            rgba(100, 100, 100, .45),
            rgba(0, 0, 0, .25) .35vw);
    background-color: rgba(49, 49, 49, .65);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    transition: border-color 0.2s ease, background 0.2s ease;
}

.dmg-name {
    font-size: 0.75vw;
    color: #cfcfcf;
    text-shadow: $textstroke;
    white-space: nowrap;
}

.dmg-value {
    font-size: 0.85vw;
    font-weight: 700;
    line-height: 1.2;
    color: #fff;
    text-shadow: $textstroke;
}

.dmg-bar {
    height: 0.35vw;
    margin-top: 0.2vw;
    background: rgba(255, 255, 255, 0.12);
    border-radius: 2px;
    overflow: hidden;
}

.dmg-fill {
    height: 100%;
    width: 0;
    transition: width 0.25s ease, background 0.25s ease;
    background: currentColor;
}

/* currentColor drives the bar fill, so each band only sets `color` once. */
.dmg-ok       { color: #5fa77c; }
.dmg-light    { color: #d8c65a; border-color: rgba(216, 198, 90, 0.5); }
.dmg-moderate { color: #e09a3e; border-color: rgba(224, 154, 62, 0.55); }
.dmg-heavy    { color: #d95f3b; border-color: rgba(217, 95, 59, 0.65); }
/* Severity only drives the border and the bar (via currentColor) -- setting a
   background here would paint over the slot hatch above. */
.dmg-critical {
    color: #e0344a;
    border-color: rgba(224, 52, 74, 0.85);
}

.clothes-parent {
    position: absolute;
    // VoidLine 2026-08-19: was left 5% / top 12%. Pulled toward the top-left so
    // the whole layout starts near the corner with a deliberate margin, and so
    // the second row of hotkey cards (slots 6-10) stops falling off the bottom
    // of the screen -- at 12% it was clipped by the viewport edge.
    //
    // These two values and CLOTHES_RIGHT_VW in plugins/ox-adapter.ts are the
    // whole layout origin. Move one without the other and the grid either
    // overlaps the clothing column or leaves a gap beside it.
    left: 2%;
    top: 3%;
    display: flex;
    justify-content: center;
    align-items: center;

    .character-image {
        position: relative;
        width: 25vw;
        height: 35vw;
        background-image: url("/characters/char_male.png");
        background-position: center;
        background-size: cover;
        background-repeat: no-repeat;
        opacity: 0.65;
    }

    .character-selector {
        position: absolute;
        top: -3.5vw;
        display: flex;
        width: 60%;
        overflow: hidden;
        border: .1vw solid rgba(20, 20, 20, .5);

        .character-entry {
            position: relative;
            flex: 1;
            color: white;
            font-size: .8vw;
            background-color: rgba(20, 20, 20, .5);
            white-space: nowrap;
            overflow: hidden;
            padding: .25vw 1.75vw;
            text-align: center;
            text-shadow: $textstroke;
            transition: background-color 0.5s ease;

            &:hover {
                background-color: rgba(119, 96, 96, 0.5);
            }

            &.active {
                background-color: rgba(175, 138, 138, 0.5);
            }

            // &:nth-child(1) {
            //     clip-path: polygon(20% 0, 100% 0, 100% 100%, 0% 100%);
            // }

            // &:nth-child(2) {
            //     clip-path: polygon(0 100%, 0 0, 80% 0, 100% 100%);
            // }
        }
    }
}
</style>