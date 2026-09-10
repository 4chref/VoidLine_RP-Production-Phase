-- =============================================================================
-- vl_kitchen -- server
--
-- Authoritative side of the ration handout. The client can ask, but every check
-- that matters happens here: the player must actually be standing at the chef,
-- must have uses left today, and must have room for the whole pack before a
-- single item is created.
-- =============================================================================

local METADATA_KEY = 'vl_rations'

---@return string YYYY-MM-DD in server local time
local function today()
    return os.date('%Y-%m-%d')
end

---Read the player's ration record, normalising anything stale or malformed.
---@param player table qbx player object
---@return {day: string, count: number, first: number}
---A blank record. Every field is set here and nowhere else, so a new field can
---never again be added to some return paths but not others -- which is exactly
---what broke this: `last` was added for the cooldown but only to the populated
---return, so any player without an existing record got rec.last = nil and the
---cooldown check compared nil with a number.
---@return {day: string, count: number, first: number, last: number}
local function blankRecord()
    return { day = today(), count = 0, first = 0, last = 0 }
end

local function getRecord(player)
    local rec = player.PlayerData and player.PlayerData.metadata
        and player.PlayerData.metadata[METADATA_KEY]

    if type(rec) ~= 'table' then
        return blankRecord()
    end

    if VLKitchen.limit.calendarDay then
        -- New calendar day resets the allowance.
        if rec.day ~= today() then
            return blankRecord()
        end
    else
        -- Rolling 24h from the first collection of the current window.
        local first = tonumber(rec.first)
        if not first or (os.time() - first) >= 86400 then
            return blankRecord()
        end
    end

    -- Normalise every field: a record written by an older version of this
    -- script may be missing keys added since.
    local out = blankRecord()
    out.day = rec.day or out.day
    out.count = tonumber(rec.count) or 0
    out.first = tonumber(rec.first) or 0
    out.last = tonumber(rec.last) or 0
    return out
end

---Human-readable countdown, e.g. "2h 14m" or "43m" or "25s".
---@param seconds number
---@return string
local function humanTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)

    if h > 0 then return ('%dh %dm'):format(h, m) end
    if m > 0 then return ('%dm'):format(m) end
    return ('%ds'):format(seconds)
end

---@param src number
---@return boolean nearChef
local function isAtChef(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local c = VLKitchen.chef.coords
    local dx, dy, dz = coords.x - c.x, coords.y - c.y, coords.z - c.z

    -- Slightly wider than the target distance: the client can legitimately be a
    -- little further out by the time the event lands, but not across the map.
    local allowed = (VLKitchen.chef.distance or 2.5) + 2.0
    return (dx * dx + dy * dy + dz * dz) <= (allowed * allowed)
end

---Can the whole pack fit?
---
---CanCarryItem checks each item against the CURRENT free weight in isolation,
---so four separate calls can all pass while the combined pack still does not
---fit. Compare the total pack weight against remaining capacity instead.
---@param src number
---@return boolean ok
---@return string? why
local function canCarryPack(src)
    local inv = exports.ox_inventory:GetInventory(src)
    if not inv then return false, 'no inventory' end

    local packWeight = 0
    for i = 1, #VLKitchen.ration do
        local entry = VLKitchen.ration[i]
        local item = exports.ox_inventory:Items(entry.name)
        if not item then
            return false, ('item "%s" is not defined in ox_inventory'):format(entry.name)
        end
        packWeight = packWeight + (item.weight or 0) * entry.amount
    end

    local free = (inv.maxWeight or 0) - (inv.weight or 0)
    if packWeight > free then
        return false, ('pack is %dg, only %dg free'):format(packWeight, free)
    end

    return true
end

---Every refusal is logged with the player and the reason. Without this the
---only signal is a generic message on one client, which makes "it works for me
---but not for him" impossible to diagnose.
local function refuse(src, playerMsg, logMsg)
    -- Plain print, not lib.print.info: ox_lib's print levels are convar-gated
    -- and info is commonly suppressed, which would hide exactly the diagnostic
    -- this exists to produce.
    print(('[vl_kitchen] refused %s (%s): %s')
        :format(GetPlayerName(src) or '?', src, logMsg or playerMsg))
    return false, playerMsg
end

local function doCollect(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        return refuse(src, 'No character loaded.', 'qbx_core:GetPlayer returned nil')
    end

    if not isAtChef(src) then
        local ped = GetPlayerPed(src)
        local c = ped ~= 0 and GetEntityCoords(ped) or vec3(0, 0, 0)
        local k = VLKitchen.chef.coords
        return refuse(src, 'You are not at the kitchen.',
            ('distance %.1fm from chef (at %.1f, %.1f, %.1f)')
                :format(#(c - vec3(k.x, k.y, k.z)), c.x, c.y, c.z))
    end

    local rec = getRecord(player)

    local perDay = tonumber(VLKitchen.limit.perDay) or 0
    if perDay > 0 and rec.count >= perDay then
        return refuse(src,
            ('You have already collected your rations %d times today.'):format(perDay),
            ('daily limit reached: count=%d day=%s'):format(rec.count, rec.day))
    end

    -- Cooldown between collections, so the daily allowance cannot be taken all
    -- at once. Checked against the server clock, never anything client-supplied.
    local cooldown = VLKitchen.limit.cooldownSeconds or 0
    if cooldown > 0 and rec.last > 0 then
        local elapsed = os.time() - rec.last
        if elapsed < cooldown then
            return refuse(src,
                ('The kitchen has nothing more for you yet. Come back in %s.')
                    :format(humanTime(cooldown - elapsed)),
                ('cooldown: %ds remaining'):format(cooldown - elapsed))
        end
    end

    local fits, why = canCarryPack(src)
    if not fits then
        return refuse(src, 'You cannot carry a full ration pack right now.', why)
    end

    -- Spend the allowance BEFORE handing anything out. If two requests race,
    -- the second reads the already-incremented count and is refused, so the
    -- worst case is a lost use rather than a duplicated pack.
    local now = os.time()
    rec.count = rec.count + 1
    if rec.first == 0 then rec.first = now end
    rec.last = now
    rec.day = today()
    player.Functions.SetMetaData(METADATA_KEY, rec)

    local given, failed = 0, {}
    for i = 1, #VLKitchen.ration do
        local entry = VLKitchen.ration[i]
        if exports.ox_inventory:AddItem(src, entry.name, entry.amount) then
            given = given + 1
        else
            failed[#failed + 1] = entry.name
        end
    end

    if #failed > 0 then
        -- CanCarryItem passed but AddItem did not: almost always a missing item
        -- definition in ox_inventory/data/items.lua. Loud, because it is a
        -- config error the owner needs to see rather than a player problem.
        lib.print.error(('[vl_kitchen] failed to give: %s -- are these defined in ox_inventory/data/items.lua?')
            :format(table.concat(failed, ', ')))
    end

    if given == 0 then
        -- Nothing was actually handed over, so give the allowance back rather
        -- than charging them a use for a failed handout.
        rec.count = rec.count - 1
        if rec.count < 1 then rec.first, rec.last = 0, 0 end
        player.Functions.SetMetaData(METADATA_KEY, rec)

        return refuse(src, 'The kitchen is out of supplies. Tell an admin.',
            'every AddItem failed - check the item names exist in ox_inventory')
    end

    local cd = tonumber(VLKitchen.limit.cooldownSeconds) or 0

    -- Unlimited: no allowance to report.
    if perDay <= 0 then
        if cd > 0 then
            return true, ('Rations collected. Next in %s.'):format(humanTime(cd))
        end
        return true, 'Rations collected.'
    end

    local left = perDay - rec.count
    if left <= 0 then
        return true, 'Rations collected. That was your last one today.'
    end

    if cd > 0 then
        return true, ('Rations collected. %d left today, next in %s.')
            :format(left, humanTime(cd))
    end

    return true, ('Rations collected. %d collection%s left today.')
        :format(left, left == 1 and '' or 's')
end

-- Wrapped so a runtime error cannot vanish. An erroring ox_lib callback returns
-- nil, which the client renders as a notification with a title and no text --
-- exactly the "says Kitchen with nothing else" symptom, and completely silent
-- on the server. Now the stack trace is printed and the player is told.
lib.callback.register('vl_kitchen:server:collect', function(src)
    local ok, a, b = pcall(doCollect, src)

    if not ok then
        local err = tostring(a)
        print(('[vl_kitchen] ERROR for %s (%s): %s')
            :format(GetPlayerName(src) or '?', src, err))
        print(debug.traceback('[vl_kitchen] traceback', 2))

        -- DEBUG: the raw error is surfaced to the player on purpose while this
        -- is being chased down, so it can be read without server console access.
        -- Set VLKitchen.showErrorsToPlayers = false once it is fixed.
        if VLKitchen.showErrorsToPlayers then
            return false, err
        end
        return false, 'Something went wrong at the kitchen. Tell an admin.'
    end

    -- A nil first return would produce the same blank notification, so make it
    -- explicit rather than passing it through.
    if a == nil then
        print(('[vl_kitchen] collect returned nil for %s (%s)'):format(GetPlayerName(src) or '?', src))
        return false, 'The kitchen did not respond. Tell an admin.'
    end

    return a, b
end)
--
-- Lets the client show the remaining allowance on the target label.
lib.callback.register('vl_kitchen:server:remaining', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return 0 end
    local rec = getRecord(player)
    local perDay = tonumber(VLKitchen.limit.perDay) or 0
    if perDay <= 0 then return -1 end   -- -1 signals "unlimited"
    return math.max(0, perDay - rec.count)
end)
