-- =============================================================================
-- vl_blackout -- server
--
-- Rewritten from the ESX original. Three things changed on purpose:
--
--   1. The original exposed `custom_blackout:endBlackoutServer` as a net event
--      with no permission check, so ANY client could end a blackout at will.
--      That event is gone; only the server ends a blackout.
--
--   2. The original relied on a client noticing the timer had expired and
--      telling the server to stop. That meant a blackout with no players never
--      ended, and any player could lie about it. The end is now scheduled
--      server-side.
--
--   3. Late-joiner sync used `playerJoining`, which fires before the client's
--      scripts are running, so the message was usually missed. State now lives
--      in GlobalState, which FiveM replicates to every client automatically,
--      including ones that connect later.
-- =============================================================================

local endsAtEpoch = 0   -- os.time() value the current blackout ends at
local endToken = 0      -- invalidates a pending end-timer when state changes

-- Unlocks (state = 0) the configured doors when a blackout starts, since
-- their electronic lock has no power, and relocks (state = 1) them the
-- moment it ends. Looked up by name each time rather than cached, so a door
-- re-created in ox_doorlock's admin tool (new row id) is still found.
--
-- Called from plain server code, never from inside a net event handler, so
-- the ambient `source` global setDoorState reads is nil here -- that is what
-- lets this bypass the door's passcode/permission check instead of needing
-- one of its own.
-- VoidLine 2026-08-31: getDoorFromName used to be a single, immediate try.
-- ox_doorlock loads its own door list from the database ASYNCHRONOUSLY, so
-- calling this from onResourceStart (fires the instant vl_panel itself
-- starts, often within the same boot tick as ox_doorlock) could easily lose
-- that race -- the door genuinely exists in the DB, ox_doorlock just hadn't
-- finished loading it yet, so the lookup returned nil and this gave up
-- forever for that boot ("not found... skipping"), even though the door was
-- really there the whole time. Retries now instead of trying once. Costs
-- nothing in the normal case (door found immediately, no wait at all) --
-- only the genuinely-missing-door case pays the extra time, and even then
-- it's capped at ~2.5s total before giving up with the same message as before.
local function findDoorRetrying(doorName)
    for attempt = 1, 10 do
        local door = exports.ox_doorlock:getDoorFromName(doorName)
        if door then return door end
        if attempt < 10 then Wait(250) end
    end
    return nil
end

local function setDoorsForBlackout(active)
    if GetResourceState('ox_doorlock') ~= 'started' then return end

    for _, doorName in ipairs(VLBlackout.doors) do
        local door = findDoorRetrying(doorName)
        if door then
            exports.ox_doorlock:setDoorState(door.id, active and 0 or 1)
        else
            print(("[vl_blackout] door '%s' not found in ox_doorlock, skipping"):format(doorName))
        end
    end
end

local function setState(active, duration)
    endToken = endToken + 1
    local token = endToken

    endsAtEpoch = active and (os.time() + duration) or 0

    GlobalState.blackout = {
        active = active,
        duration = active and duration or 0,
        endsAt = endsAtEpoch,
        version = (GlobalState.blackout and GlobalState.blackout.version or 0) + 1,
    }

    setDoorsForBlackout(active)

    if active then
        SetTimeout(duration * 1000, function()
            -- Only fire if this is still the newest blackout.
            if endToken == token then
                setState(false, 0)
                print('[vl_blackout] blackout ended (timer expired)')
            end
        end)
    end
end

---@return boolean
local function isActive()
    local s = GlobalState.blackout
    return s ~= nil and s.active == true
end

---@param src number 0 = console
local function allowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(tostring(src), VLBlackout.ace)
end

local function notify(src, text, kind)
    if src == 0 then
        print('[vl_blackout] ' .. text)
        return
    end
    -- Qbox's own notification pipeline, so it matches the rest of the server.
    exports.qbx_core:Notify(src, text, kind or 'inform')
end

-- Seconds by default; an `m` suffix means minutes, so /blackouton 5m works.
---@param arg string|nil
---@return integer seconds
local function parseDuration(arg)
    if not arg or arg == '' then return VLBlackout.defaultDuration end

    local minutes = tostring(arg):lower():match('^(%d+)m$')
    if minutes then return tonumber(minutes) * 60 end

    return math.floor(tonumber(arg) or VLBlackout.defaultDuration)
end

RegisterCommand(VLBlackout.commands.on, function(src, args)
    if not allowed(src) then
        notify(src, 'Only admins can control the power grid.', 'error')
        return
    end

    if isActive() then
        notify(src, ('A blackout is already running. Use /%s.'):format(VLBlackout.commands.off), 'error')
        return
    end

    local duration = parseDuration(args[1])
    if duration < 5 then duration = 5 end

    setState(true, duration)
    notify(src, ('Blackout triggered for %d seconds.'):format(duration), 'success')
end, false)

RegisterCommand(VLBlackout.commands.off, function(src)
    if not allowed(src) then
        notify(src, 'Only admins can control the power grid.', 'error')
        return
    end

    if not isActive() then
        notify(src, 'There is no blackout running.', 'error')
        return
    end

    setState(false, 0)
    notify(src, 'Power restored.', 'success')
end, false)

-- -----------------------------------------------------------------------------
-- Automatic blackouts
-- -----------------------------------------------------------------------------

CreateThread(function()
    if not VLBlackout.auto.enabled then return end

    local cfg = VLBlackout.auto
    while true do
        Wait(cfg.intervalMinutes * 60000)
        if not isActive() and math.random() < cfg.chance then
            local duration = math.random(cfg.minDuration, cfg.maxDuration)
            print(('[vl_blackout] automatic blackout for %d seconds'):format(duration))
            setState(true, duration)
        end
    end
end)

-- -----------------------------------------------------------------------------
-- Lifecycle
-- -----------------------------------------------------------------------------

-- Read-only. A joining client asks how much of the current blackout is left,
-- because it cannot compute that itself (no `os` library on the client). This
-- mutates nothing and replies only to the caller, so it is not an attack
-- surface the way the original's end-blackout event was.
RegisterNetEvent('vl_blackout:requestState', function()
    local src = source
    if not src or src == 0 then return end

    if not isActive() then
        TriggerClientEvent('vl_blackout:syncState', src, false, 0)
        return
    end

    local remaining = math.max(0, endsAtEpoch - os.time())
    TriggerClientEvent('vl_blackout:syncState', src, true, remaining)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Never come back up believing a blackout is still running -- and if
    -- this resource restarted mid-blackout, the door it unlocked would
    -- otherwise stay unlocked forever with nothing left to relock it.
    GlobalState.blackout = { active = false, duration = 0, endsAt = 0, version = 0 }
    setDoorsForBlackout(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerClientEvent('vl_blackout:forceCleanup', -1)
end)
