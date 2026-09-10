return {
    doctorCallCooldown = 1, -- Time in minutes for cooldown between doctors calls
    -- VoidLine: was true, which is the Qbox default. On every respawn
    -- server/hospital.lua called exports.ox_inventory:ClearInventory(src) --
    -- the whole inventory, not just items flagged deletable.
    --
    -- That is what actually emptied players' inventories after death. It is
    -- unrelated to avp_grid_inventory: the wipe hits ox_inventory, which is the
    -- source of truth under the ox bridge, so the AVP grid was correctly showing
    -- an inventory that really was empty.
    --
    -- (The upstream comment read "Enable to disable removing all items", which
    -- is garbled. The code is `if config.wipeInvOnRespawn then wipeInventory()`
    -- -- true wipes, false keeps.)
    wipeInvOnRespawn = false, -- true = clear the player's entire inventory on respawn
    -- VoidLine: Renewed-Banking is REMOVED from this server -- no bank, no ATMs,
    -- no society accounts. The only currency is the `core` item.
    --
    -- Left as a stub rather than deleted because qbx_ambulancejob calls this
    -- unconditionally when a patient pays a doctor; dropping the key would turn
    -- that into a nil call and error the treatment flow.
    depositSociety = function(society, amount) -- luacheck: ignore society amount
        return
    end
}