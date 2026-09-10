--[[
    vl_carloot -- server half.

    Each wreck becomes its own ox_inventory stash, keyed on the prop's rounded
    world position. Static map props never move, so that key is stable across
    restarts and identical for every player looking at the same wreck.

    Loot is seeded exactly once per wreck, ever. The "has this been searched"
    record lives in its own table rather than being inferred from the stash
    being empty -- an emptied stash and a never-opened one look identical, and
    inferring it would turn every wreck into an infinite coin farm.
]]

local INV <const> = 'ox_inventory'

---@type table<string, boolean> stashes registered this session
local registered = {}

local tableReady = false

-- -----------------------------------------------------------------------------
-- Storage
-- -----------------------------------------------------------------------------

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `vl_carloot_searched` (
                `stash_id` VARCHAR(64) NOT NULL,
                `searched_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`stash_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end)

    if ok then
        tableReady = true
        return
    end

    -- The database is unreachable or read-only (InnoDB refuses writes under
    -- innodb_force_recovery). Wrecks still work, but "already searched" is only
    -- remembered until the next restart.
    lib.print.error('[vl_carloot] could not create vl_carloot_searched:', err)
    lib.print.warn('[vl_carloot] falling back to in-memory tracking -- loot will reseed on restart')
end)

--- Claims a wreck. Returns true only for the first ever call for that id, so
--- the caller knows whether to seed loot.
---@param stashId string
---@return boolean firstTime
local function claimWreck(stashId)
    if not tableReady then
        -- Session-only fallback. `registered` already guards the current run.
        return true
    end

    -- Explicit existence check, NOT the return value of the insert.
    -- MySQL.insert.await returns the AUTO_INCREMENT id, and this table's key is
    -- a VARCHAR with no auto-increment column -- so it always returned 0, which
    -- read as "already claimed" and meant no wreck was ever seeded.
    local ok, exists = pcall(MySQL.scalar.await,
        'SELECT 1 FROM `vl_carloot_searched` WHERE `stash_id` = ? LIMIT 1', { stashId })

    if not ok then return true end
    if exists then return false end

    pcall(MySQL.query.await,
        'INSERT IGNORE INTO `vl_carloot_searched` (`stash_id`) VALUES (?)', { stashId })

    return true
end

-- -----------------------------------------------------------------------------
-- Wrecks
-- -----------------------------------------------------------------------------

---@param coords vector3|table
---@return string
local function stashIdFor(coords)
    local mult = 10 ^ Config.CoordPrecision
    return ('carloot-%d-%d-%d'):format(
        math.floor(coords.x * mult + 0.5),
        math.floor(coords.y * mult + 0.5),
        math.floor(coords.z * mult + 0.5)
    )
end

---@param stashId string
---@param seed boolean
local function ensureStash(stashId, seed)
    if registered[stashId] then return end

    -- ox stashes are flat slot lists, not a grid: Config.StashX/Y describe the
    -- shape the panel draws, so the slot count is their product. Weight is in
    -- grams here, kilograms in the config.
    exports[INV]:RegisterStash(
        stashId,
        Config.StashLabel,
        Config.StashX * Config.StashY,
        Config.StashWeight * 1000,
        false -- no owner: any player who finds this wreck sees the same contents
    )

    registered[stashId] = true

    if not seed then return end

    local amount = math.random(Config.CoinMin, Config.CoinMax)
    local ok = exports[INV]:AddItem(stashId, Config.CoinItem, amount)

    -- Logged because a failed AddItem is otherwise indistinguishable from "this
    -- wreck was already looted".
    if ok then
        lib.print.info(('[vl_carloot] seeded %s with %dx %s'):format(stashId, amount, Config.CoinItem))
    else
        lib.print.error(('[vl_carloot] FAILED to seed %s with %dx %s -- is %s a registered ox item?')
            :format(stashId, amount, Config.CoinItem, Config.CoinItem))
    end
end

RegisterNetEvent('vl_carloot:server:search', function(coords)
    local source = source

    if type(coords) ~= 'table'
        or type(coords.x) ~= 'number'
        or type(coords.y) ~= 'number'
        or type(coords.z) ~= 'number' then
        return
    end

    -- Coordinates come from the client, so confirm the player is actually
    -- standing at the wreck they claim to be searching. The allowance is the
    -- target reach plus a margin for the prop's own size.
    local ped = GetPlayerPed(source)
    if ped == 0 then return end

    local pos = GetEntityCoords(ped)
    if #(pos - vec3(coords.x, coords.y, coords.z)) > Config.SearchDistance + 4.0 then
        return
    end

    local stashId = stashIdFor(coords)

    -- claimWreck must run before the stash is built, so the very first search
    -- is the only one that seeds it.
    local firstTime = not registered[stashId] and claimWreck(stashId) or false

    ensureStash(stashId, firstTime)

    -- ox opens inventories client-side, so hand the player straight to it. None
    -- of AVP's dance is needed any more: no detach-before-open (ox has no
    -- observer list to go stale), no manual SET_INTERFACE_OPEN (ox raises its
    -- own UI), and no explicit Save (ox persists stashes itself).
    TriggerClientEvent('ox_inventory:openInventory', source, 'stash', stashId)
end)
