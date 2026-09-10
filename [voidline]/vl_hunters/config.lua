-- =============================================================================
-- vl_hunters
--
-- Hostile groups that spawn around the player and patrol on foot.
--
-- SERVER-AUTHORITATIVE, NETWORKED (changed 2026-09-02).
--
-- This used to be entirely client-side: every player spawned their own local
-- peds with CreatePed(..., isNetwork = false), so two players in the same
-- street saw different hunters and nobody could see anybody else's. That was a
-- deliberate trade for entity budget, but it means the hunters are not really
-- part of the world -- you cannot fight one together, and a kill only happens
-- on one machine.
--
-- Now: clients still FIND the spawn spot (GetClosestVehicleNode and
-- GetSafeCoordForPed are client natives, and the client knows what is on screen
-- near it), but they ask the SERVER to create the ped. The server owns the
-- population, enforces the caps, and creates one networked entity everyone
-- sees. Whichever client currently has control drives its AI.
--
-- The entity cost the old comment warned about is real, so the caps below now
-- matter much more: `max` is per pack ACROSS THE SERVER, not per player.

-- PACKS
--
-- Everything below is a list of packs rather than one hardcoded enemy, so a new
-- group is a config entry and no code. Each pack keeps its own population,
-- distances and behaviour.
--
-- Only one pack ships now. The structure is kept because it costs nothing and
-- a second group is a copy of the block below with different numbers --
-- `useRoadNodes = false` in particular spawns a pack off the road network, in
-- yards and alleys, which is how a close-range group would be placed.
-- =============================================================================

VLHunters = {}

VLHunters.enabled = true

-- Print each spawn/despawn and each failed spawn cycle. Left ON: this resource
-- does its work out of sight by design, so with it off there is no way to tell
-- "not spawning" from "spawning behind you".
VLHunters.debug = true

-- Shared by every pack.
VLHunters.performance = {
    -- How often the live population is re-checked (distance, combat, patrol).
    tickMs = 1000,

    -- How often a client asks the server to top up the population near it.
    requestMs = 4000,
}

-- =============================================================================
-- WRECK HUNTERS
-- =============================================================================

-- One hunter posted near each destroyed vehicle.
--
-- Deduplicated by the vehicle's NETWORK id on the server, so the several
-- clients that can all see the same wreck produce exactly one hunter between
-- them -- not one each.
VLHunters.wreck = {
    enabled = true,

    -- Which pack the wreck guard is drawn from.
    packId = 'terminator',

    -- How often a client sweeps nearby vehicles for fresh wrecks.
    scanMs = 4000,

    -- Only wrecks within this range of the reporting player are considered.
    searchRadius = 150.0,

    -- A vehicle counts as wrecked at or below this engine/body health.
    -- 0 is "actually destroyed"; raise toward 200 to include badly damaged but
    -- still-running cars.
    healthThreshold = 0.0,

    -- Placed this far from the wreck: far enough not to spawn inside the
    -- bodywork, close enough to read as guarding it.
    offset = 4.0,

    -- Server-wide cap on wreck guards, independent of the packs' own `max`.
    -- A street full of burnt-out cars would otherwise fill the entity pool.
    max = 20,

    -- A wreck stops counting once it is this far from every player, and its
    -- guard is removed with it.
    despawnDistance = 300.0,
}

---@class VLHuntersPack
VLHunters.packs = {

    -- =========================================================================
    { id = 'terminator',
      enabled = true,

      ped = {
          -- Streamed by resources/[assets]/vl_terminator, which registers it
          -- through peds.meta. If this reports invalid, check that resource.
          model = 't800',

          -- Deliberately fragile, but NOT below ~101.
          --
          -- A ped's fatally-injured threshold sits at 100: give it a max health
          -- under that and it is already past dying the instant it spawns, so
          -- it arrives as a corpse. 60 did exactly that. client.lua clamps
          -- anything lower and warns, so this cannot silently produce bodies
          -- again.
          --
          -- 110 is two rifle rounds, or one to the head with critical hits on
          -- (see useCriticalHits below).
          health = 110,
          armour = 0,

          weapon = 'WEAPON_ASSAULTRIFLE_MK2',
          ammo = 250,

          -- rpemotes calls this walk style "Muscle"
          -- ([standalone]/rpemotes/client/AnimationList.lua:497).
          walkClipset = 'move_m@muscle@a',

          -- ONE HIT, THEN MISSES.
          --
          -- They open at full accuracy so the first shot that lands actually
          -- lands -- the player feels the contact. The moment a hunter damages
          -- a player, the server flags it and its accuracy drops to
          -- accuracySpent for the rest of its life, so it keeps firing and
          -- keeps missing. The flag is per HUNTER, not per player: one that has
          -- already tagged someone stays harmless to everybody.
          accuracy = 100,
          accuracySpent = 0,

          combatAbility = 0,  -- 0 poor, 1 average, 2 professional

          -- Movement. 0 stationary · 1 defensive · 2 will advance.
          -- 1 makes them shuffle and reposition badly instead of flanking.
          combatMovement = 1,

          -- No cover, so they stand in the open rather than fighting properly.
          useCover = false,

          -- Wide, slow reactions: they notice late and lose track easily.
          alertness = 0,

          -- Headshots and similar kill outright, which is what actually makes
          -- them feel fragile without pushing health under the fatal floor.
          useCriticalHits = true,
      },

      spawn = {
          -- SERVER-WIDE, not per player. Six used to mean "six each".
          max = 12,
          minDistance = 80.0,
          maxDistance = 180.0,
          despawnDistance = 260.0,
          intervalMs = 8000,
          chance = 0.7,
          attempts = 12,
          requireOutOfSight = true,
          -- Snap to the road network, so they patrol streets.
          useRoadNodes = true,
      },

      patrol = { radius = 120.0, minimalLength = 10.0, timeBetweenWalks = 2.0, reissueMs = 15000 },
      combat = { detectRadius = 60.0, keepRadius = 150.0, reissueMs = 4000 },
    },

}
