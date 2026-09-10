-- =============================================================================
-- vl_hud / client/threat.lua
--
-- Generic threat registry. Anything that wants the threat icon lit registers a
-- source here; the icon is on while at least one source is live.
--
-- Sources are tracked SEPARATELY rather than collapsed into one boolean. Two
-- overlapping threats would otherwise cancel each other the moment the first
-- one cleared, and the icon would go dark while you were still being shot.
--
-- Every source carries an expiry, so nothing can pin the icon on forever. Two
-- ways to use that:
--
--   sustained -- the source repeats while the threat lasts (a heartbeat).
--                Re-calling extends the window, so it simply goes stale on its
--                own if the source dies mid-threat.
--
--   pulse     -- a one-shot event (took a hit, countdown expired). Holds the
--                icon for a fixed window, then clears itself.
--
-- ADDING A THREAT LATER
-- From another resource, with no changes to this file:
--     exports.vl_hud:SetThreat('bandits', true)     -- call again to sustain
--     exports.vl_hud:SetThreat('bandits', false)    -- explicit all-clear
--     exports.vl_hud:PulseThreat('gunshot')         -- one-shot, self-clearing
-- Or add another adapter at the bottom of this file, the way the drone one is
-- written, when the source resource should not have to know the HUD exists.
-- =============================================================================

Threat = {}

-- key -> game-time ms at which this source stops counting as live.
local sources = {}

local function cfg()
    return VLHud.threat or {}
end

---Mark a source live for a window, or clear it outright.
---@param key string
---@param active boolean
---@param holdMs number|nil defaults to VLHud.threat.staleMs
function Threat.Set(key, active, holdMs)
    if type(key) ~= 'string' or key == '' then return end

    if not active then
        sources[key] = nil
        return
    end

    sources[key] = GetGameTimer() + (tonumber(holdMs) or cfg().staleMs or 2500)
end

---One-shot: hold the icon for a window, then let it clear itself.
---@param key string
---@param holdMs number|nil defaults to VLHud.threat.holdMs
function Threat.Pulse(key, holdMs)
    Threat.Set(key, true, tonumber(holdMs) or cfg().holdMs or 6000)
end

---@return boolean
function Threat.IsActive()
    local now = GetGameTimer()
    for key, until_ in pairs(sources) do
        if now >= until_ then
            sources[key] = nil   -- clearing an existing key during pairs() is safe
        else
            return true
        end
    end
    return false
end

exports('SetThreat', function(key, active, holdMs)
    Threat.Set(key, active, holdMs)
end)

exports('PulseThreat', function(key, holdMs)
    Threat.Pulse(key, holdMs)
end)

exports('IsThreatActive', function()
    return Threat.IsActive()
end)

-- =============================================================================
-- ADAPTER: vl_combat_drone
--
-- Listens to the events that resource ALREADY sends -- nothing in
-- vl_combat_drone changes. Net events are addressed by name across the whole
-- client, so registering handlers here just means they run alongside the
-- drone's own.
--
-- Four signals, covering the ways a drone becomes your problem:
--
--   showWarning     you are being challenged. Heartbeats once a second while
--                   the drone holds you, so it is used as a sustained source.
--   warningExpired  your countdown ran out; weapons free on you.
--   takeDamage      you are being hit right now.
--   sirenState      a drone somewhere is actively hunting. Broadcast to
--                   everyone, so it is filtered by distance below.
--
-- combat_drone:flagPlayer is deliberately NOT a source. Being flagged lasts 90
-- seconds and only means "no second warning IF a drone sees you" -- flashing
-- the icon that whole time, potentially miles from any drone, would train
-- players to ignore it. The siren-proximity check below covers the case that
-- actually matters, which is a flagged player being hunted for real.
-- =============================================================================

local droneCfg = (cfg().sources or {}).combatDrone

if droneCfg then
    local KEY = 'combat_drone'

    RegisterNetEvent('combat_drone:showWarning', function()
        Threat.Set(KEY, true)
    end)

    RegisterNetEvent('combat_drone:hideWarning', function()
        Threat.Set(KEY, false)
    end)

    RegisterNetEvent('combat_drone:warningExpired', function()
        Threat.Pulse(KEY)
    end)

    RegisterNetEvent('combat_drone:takeDamage', function()
        Threat.Pulse(KEY)
    end)

    -- ---------------------------------------------------------------------
    -- Siren proximity
    --
    -- A drone runs its alert siren while warning, tracking, engaging or
    -- withdrawing -- i.e. whenever it is hunting somebody. That is broadcast to
    -- every client, so it has to be filtered by distance to mean anything
    -- locally: a drone screaming across the map is not your threat.
    -- ---------------------------------------------------------------------

    local sirens = {}   -- netId -> true

    RegisterNetEvent('combat_drone:sirenState', function(netId, on)
        sirens[netId] = on and true or nil
    end)

    RegisterNetEvent('combat_drone:droneUnregistered', function(netId)
        sirens[netId] = nil
    end)

    CreateThread(function()
        local radius = tonumber(cfg().droneAlertRadius) or 90.0

        while true do
            local near = false

            if next(sirens) then
                local me = GetEntityCoords(cache.ped)

                for netId in pairs(sirens) do
                    if NetworkDoesNetworkIdExist(netId) then
                        local ent = NetworkGetEntityFromNetworkId(netId)
                        if ent ~= 0 and DoesEntityExist(ent) then
                            if #(me - GetEntityCoords(ent)) <= radius then
                                near = true
                                break
                            end
                        end
                    else
                        -- Out of scope entirely, so distance is unknowable.
                        -- Drop it rather than hold the icon on indefinitely.
                        sirens[netId] = nil
                    end
                end
            end

            Threat.Set('combat_drone_near', near, 1500)
            Wait(near and 300 or 700)
        end
    end)
end

-- =============================================================================
-- ADAPTER: air raid (now part of vl_panel; was its own vl_airraid resource)
--
-- No net events, no export call either resource has to know the other exists
-- for -- whichever resource owns the air raid system publishes
-- GlobalState.airraid = { active, ... }, the exact same city-wide pattern the
-- power icon already reads (GlobalState.blackout in client/main.lua). This
-- just mirrors that, and does not care which resource actually sets it.
--
-- Kept SUSTAINED with a heartbeat rather than one Threat.Set(true) call at raid
-- start: this module's own design is that every source expires on its own
-- (VLHud.threat.staleMs) so nothing can pin the icon on forever if whatever
-- set it dies unexpectedly. A single call would go stale and silently clear
-- itself a couple of seconds into what could be a raid running for minutes --
-- re-asserting it periodically is what keeps it lit for the actual duration
-- while still inheriting that same safety net the moment the heartbeat stops.
-- =============================================================================

local airRaidCfg = (cfg().sources or {}).airRaid

if airRaidCfg then
    local KEY = 'air_raid'

    local function isRaidActive()
        local s = GlobalState.airraid
        return s ~= nil and s.active == true
    end

    CreateThread(function()
        while true do
            if isRaidActive() then
                Threat.Set(KEY, true)
                Wait(1500)
            else
                Threat.Set(KEY, false)
                Wait(1500) -- GlobalState needs a moment to replicate on a fresh join
            end
        end
    end)
end
