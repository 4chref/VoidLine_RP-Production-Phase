-- =============================================================================
-- vl_apocalypse -- server
--
-- Owns the switch and nothing else. State lives in GlobalState, which FiveM
-- replicates to every client including late joiners.
--
-- There is deliberately no net event a client can fire to toggle this: the only
-- ways in are the ACE-gated command, the console, and the export.
-- =============================================================================

local RESOURCE = GetCurrentResourceName()
local STATE_FILE = 'apocalypse_state.json'

local function log(fmt, ...)
    print(('[%s] ' .. fmt):format(RESOURCE, ...))
end

---@return boolean
local function isActive()
    local s = GlobalState.vlApocalypse
    return s ~= nil and s.active == true
end

local function save(state)
    if not Config.Persist then return end
    SaveResourceFile(RESOURCE, STATE_FILE, json.encode({
        active = state,
        savedAt = os.date('%Y-%m-%d %H:%M:%S'),
    }), -1)
end

---@return boolean? nil when there is nothing saved
local function loadPersisted()
    if not Config.Persist then return nil end
    local raw = LoadResourceFile(RESOURCE, STATE_FILE)
    if not raw or raw == '' then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        log('%s is unreadable, ignoring it', STATE_FILE)
        return nil
    end
    return decoded.active == true
end

---Routing bucket population. OFF by default -- see the warning in config.lua.
---@param enabled boolean
local function applyRoutingBuckets(enabled)
    if not Config.RoutingBuckets.Enabled then return end

    for _, bucket in ipairs(Config.RoutingBuckets.Buckets) do
        SetRoutingBucketPopulationEnabled(bucket, not enabled)
        log('routing bucket %d population %s', bucket,
            enabled and 'DISABLED' or 'enabled')
    end
end

---@param state boolean
---@return boolean changed
local function setState(state)
    if isActive() == state then return false end

    GlobalState.vlApocalypse = {
        active = state,
        version = (GlobalState.vlApocalypse and GlobalState.vlApocalypse.version or 0) + 1,
    }
    applyRoutingBuckets(state)
    save(state)

    log('apocalypse %s', state and 'ENABLED' or 'DISABLED')
    return true
end

---@param src number 0 = console
local function allowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(tostring(src), Config.Ace)
end

local function notify(src, text, kind)
    if src == 0 then
        log('%s', text)
        return
    end
    if GetResourceState('qbx_core') ~= 'started' then return end
    exports.qbx_core:Notify(src, text, kind or 'inform')
end

--   /apocalypse            toggle
--   /apocalypse on|off     force a state
--   /apocalypse status     report
RegisterCommand('apocalypse', function(src, args)
    if not allowed(src) then
        notify(src, 'You are not cleared to change the world population.', 'error')
        return
    end

    local mode = (args[1] or ''):lower()

    if mode == 'status' then
        notify(src, ('World population removal is %s.')
            :format(isActive() and 'ACTIVE' or 'off'), 'inform')
        return
    end

    local want
    if mode == 'on' or mode == 'start' then
        want = true
    elseif mode == 'off' or mode == 'stop' then
        want = false
    elseif mode == '' or mode == 'toggle' then
        want = not isActive()
    else
        notify(src, 'Usage: /apocalypse [on|off|toggle|status]', 'error')
        return
    end

    if not setState(want) then
        notify(src, ('Already %s.'):format(want and 'active' or 'off'), 'error')
        return
    end

    notify(src, want
        and 'The world is being emptied.'
        or 'Traffic and aircraft restored.', 'success')
end, false)

-- For event scripts: exports.vl_apocalypse:SetApocalypse(false)
exports('SetApocalypse', function(state) return setState(state == true) end)
exports('IsApocalypseActive', isActive)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end

    -- Come back up in whatever state we went down in, falling back to config on
    -- a fresh install.
    local state = loadPersisted()
    local source = 'saved state'
    if state == nil then
        state = Config.Enabled == true
        source = 'config Enabled'
    end

    GlobalState.vlApocalypse = { active = state, version = 0 }
    applyRoutingBuckets(state)

    log('starting %s (from %s)', state and 'ACTIVE' or 'inactive', source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end

    -- Hand the world back: clear the live state so clients restore, and undo
    -- the bucket switch. The saved file is left alone -- a restart is not the
    -- admin turning this off.
    applyRoutingBuckets(false)
    GlobalState.vlApocalypse = { active = false, version = 0 }
end)
