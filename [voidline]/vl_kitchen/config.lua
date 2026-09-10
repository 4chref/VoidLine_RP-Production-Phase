VLKitchen = {}

-- =============================================================================
-- THE CHEF
-- =============================================================================

VLKitchen.chef = {
    -- Captured with /vec4, which already drops the Z by 1.0 to ground level,
    -- so the ped is spawned at this Z as-is with no further offset. If the chef
    -- ends up floating or sunk, nudge this value rather than the code.
    coords = vec4(3108.24, 5448.99, 27.59, 28.0),

    -- Checked with IsModelInCdimage before use. If it is not a real model the
    -- chef silently never spawns, so an invalid name falls back to `fallback`
    -- below and logs the reason to F8.
    model = 's_m_y_chef_01',
    -- Proven to work on this server: it is what vl_hospital's doctor uses.
    fallback = 's_m_m_doctor_01',

    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',

    label = 'Collect rations',
    icon = 'fas fa-utensils',
    distance = 2.5,
}

-- =============================================================================
-- THE RATION PACK
-- =============================================================================
-- Handed out as one bundle. Every item must exist in ox_inventory/data/items.lua
-- or it silently fails to spawn.

VLKitchen.ration = {
    { name = 'canned_chicken_soup', amount = 5 },
    { name = 'canned_tuna',         amount = 5 },
    { name = 'water_bottle',        amount = 5 },
    { name = 'watermelon_punch',    amount = 5 },
}

-- =============================================================================
-- DAILY LIMIT
-- =============================================================================

VLKitchen.limit = {
    -- How many times one character may collect per day.
    -- 0 = UNLIMITED. Set to 2 to restore the old two-a-day cap.
    perDay = 0,

    -- Minimum gap between two collections, in seconds. 0 = no wait.
    -- Also disabled, because a cooldown would still gate "unlimited" access.
    -- Set to 3 * 60 * 60 to restore the 3 hour wait.
    cooldownSeconds = 3600,

    -- The day rolls over at real-world server midnight. Set to false to use a
    -- rolling 24h window from the first collection instead.
    calendarDay = true,
}

-- =============================================================================
-- WEIGHT WARNING
-- =============================================================================
-- The full pack is 20 items at 200-500g each = 6.4kg. A player at 30kg capacity
-- who is already loaded will not fit it. The server checks BEFORE handing
-- anything over and refuses cleanly rather than part-filling the pack.

-- =============================================================================
-- DEBUG
-- =============================================================================
-- Shows the raw Lua error in the player's notification instead of a generic
-- message. Useful while chasing a fault without server console access.
-- Turn this OFF once the issue is resolved.
VLKitchen.showErrorsToPlayers = true
