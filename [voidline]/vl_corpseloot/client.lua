-- =============================================================================
-- vl_corpseloot / client.lua
--
-- One job: put "Search body" on a downed player so their carried items can
-- be looted.
-- =============================================================================

-- addGlobalPlayer, not addGlobalPed: this must never appear on an NPC.
exports.ox_target:addGlobalPlayer({
    {
        name = 'vl_corpseloot:search',
        icon = VLCorpseLoot.target.icon,
        label = VLCorpseLoot.target.label,
        distance = VLCorpseLoot.target.distance,

        -- IsPedFatallyInjured is USELESS on this server. qbx_medical's OnDeath
        -- calls ResurrectPlayer(), sets health to max and makes the ped
        -- invincible -- a "dead" player here is a live, full-health ped playing
        -- the `dead_a` animation, so the native reports false for exactly the
        -- people you want to search.
        --
        -- qbx_medical replicates a statebag instead, readable on any client:
        -- Player(serverId).state.isDead, true for DEAD *and* LAST_STAND
        -- (qbx_medical/server/main.lua:39). vl_bodydrag hit this same wall and
        -- documented it at client/client.lua:52 -- this is the same fix.
        canInteract = function(entity)
            if not entity or entity == cache.ped then return false end
            if LocalPlayer.state.isDead == true then return false end

            -- Returns -1 for anything that is not a player ped.
            local ply = NetworkGetPlayerIndexFromPed(entity)
            if ply == -1 then return false end

            local sid = GetPlayerServerId(ply)
            if sid <= 0 or sid == cache.serverId then return false end

            return Player(sid).state.isDead == true
        end,

        -- Straight to ox. It runs its own server-side check (the target must
        -- have ox's `canSteal` bag set, and be within 1.8m), so there is no
        -- point duplicating that here -- and no window of our own to keep in
        -- sync with theirs.
        onSelect = function()
            exports.ox_inventory:openNearbyInventory()
        end,
    },
})
