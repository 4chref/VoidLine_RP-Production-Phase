-- =============================================================================
-- combat_drone / server.lua
--
-- The server never simulates the drone itself (no AI runs here). Its job is:
--   1. Handle /spawndrone and /deletedrones commands.
--   2. Keep a lightweight registry of which network IDs are active drones so
--      every client can recognize a drone entity (e.g. to ignore it as a
--      "hostile NPC" target for other drones, or to draw debug info).
--   3. Broadcast spawn/delete requests. Actual CreatePed/DeleteEntity calls
--      happen client-side because peds must be created on a client to be
--      properly networked; OneSync then handles ownership migration between
--      clients automatically based on proximity. Our AI code (client/main.lua)
--      only runs its logic on whichever client currently owns the entity
--      (checked via NetworkGetEntityOwner), so there is exactly one "brain"
--      per drone at any time, regardless of how many clients are nearby.
-- =============================================================================

--   4. Own the warning countdown clock and relay alert-siren state. Both have
--      to outlive OneSync ownership migration -- see the WARNINGS section below
--      and client/warning.lua for why that can't live on a client.

local Drones = {}   -- [netId] = { spawnedBy = source, spawnedAt = os.time() }
local Warnings = {} -- [netId] = { targetSrc, expiresAt, lastBeat }
local Sirens = {}   -- [netId] = true while sounding
local Flags = {}    -- [serverId] = timer ms at which "engage on sight" lapses

local function IsAllowed(src)
    -- Hook your permission system here, e.g.:
    -- return IsPlayerAceAllowed(src, 'command.spawndrone')
    return true
end

-- =============================================================================
-- AUTOMATIC CITY PATROL
-- =============================================================================

--- station index -> netId currently holding it
StationDrones = {}

--- Asks a client to create the drone for `index`.
---
--- A drone has to be made CLIENT-side here: this resource builds a piloted
--- vehicle plus a ped and drives it with client-only natives, so the server
--- cannot create one itself the way vl_hunters does. One client is picked per
--- station and the result is registered back, which keeps it to one drone per
--- station however many players are online.
local function autoLog(msg, ...)
    if Config.AutoSpawn and Config.AutoSpawn.debug then
        print(('[combat_drone] auto: ' .. msg):format(...))
    end
end

--- Asks the nearest client to create the drone for `index`, if one is close
--- enough for the creation to survive.
---
--- A drone has to be made CLIENT-side: this resource builds a piloted vehicle
--- plus a ped and drives it with client-only natives, so the server cannot
--- create one itself the way vl_hunters does. One client is picked per station
--- and the result is registered back, which keeps it to one drone per station
--- however many players are online.
local function postStation(index)
    local cfg = Config.AutoSpawn
    local station = cfg.stations[index]
    if not station then return end

    local coords = vector3(station.x, station.y, station.z)

    local players = GetPlayers()
    if #players == 0 then return end

    local best, bestDist
    for i = 1, #players do
        local ped = GetPlayerPed(players[i])
        if ped and ped ~= 0 then
            local d = #(GetEntityCoords(ped) - coords)
            if not bestDist or d < bestDist then best, bestDist = players[i], d end
        end
    end

    if not best then return end

    -- Too far for the map to be streamed there: the vehicle would be created
    -- and culled in the same frame. Wait for somebody to come closer.
    if bestDist > (cfg.spawnRadius or 500.0) then
        autoLog('station %d: nearest player is %.0f m away (need %.0f) - waiting',
            index, bestDist, cfg.spawnRadius or 500.0)
        return
    end

    autoLog('station %d: asking player %s (%.0f m) to post it', index, best, bestDist)
    TriggerClientEvent('combat_drone:spawnAtStation', best, station, index)
end

CreateThread(function()
    local cfg = Config.AutoSpawn
    if not cfg or not cfg.enabled then
        autoLog('disabled in config')
        return
    end

    Wait(cfg.delayMs or 20000)
    autoLog('%d stations configured, sweeping every %d ms (radius %.0f m)',
        #cfg.stations, cfg.sweepMs or 10000, cfg.spawnRadius or 500.0)

    while true do
        for index = 1, #cfg.stations do
            local netId = StationDrones[index]

            -- Empty station: never posted, or its drone is gone.
            if not netId or not Drones[netId] then
                StationDrones[index] = nil
                postStation(index)
                Wait(1000) -- stagger, so several are not created in one tick
            end
        end

        Wait(cfg.sweepMs or 10000)
    end
end)

RegisterCommand('spawndrone', function(source, args)
    local src = source
    if src == 0 then
        print('[combat_drone] /spawndrone must be run by a player, not the server console.')
        return
    end
    if not IsAllowed(src) then return end
    TriggerClientEvent('combat_drone:spawnRequested', src)
end, false)

RegisterCommand('deletedrones', function(source, args)
    local src = source
    if src ~= 0 and not IsAllowed(src) then return end
    TriggerClientEvent('combat_drone:deleteAllRequested', -1)
    -- Every countdown and siren belonged to a drone that no longer exists, so
    -- clear the HUD for anyone mid-warning rather than leaving it to time out.
    for _, w in pairs(Warnings) do
        TriggerClientEvent('combat_drone:hideWarning', w.targetSrc)
    end
    Drones, Warnings, Sirens = {}, {}, {}
end, false)

RegisterServerEvent('combat_drone:registerDrone')
AddEventHandler('combat_drone:registerDrone', function(netId, stationIndex, stationCoords, stationHeading)
    local src = source
    Drones[netId] = {
        spawnedBy = src,
        spawnedAt = os.time(),
        stationIndex = stationIndex,
    }

    if stationIndex then
        StationDrones[stationIndex] = netId
    end

    TriggerClientEvent('combat_drone:droneRegistered', -1, netId)

    -- Tell EVERY client where this drone lives, not just the one that made it.
    -- Station keeping is decided by whichever client currently controls the
    -- drone, and that changes as players move -- so all of them need the point.
    if stationCoords then
        TriggerClientEvent('combat_drone:setStation', -1, netId, stationCoords, stationHeading)
    end
end)

RegisterServerEvent('combat_drone:unregisterDrone')
AddEventHandler('combat_drone:unregisterDrone', function(netId)
    local d = Drones[netId]
    if d and d.stationIndex and StationDrones[d.stationIndex] == netId then
        -- Freed rather than deleted, so the respawn sweep re-posts this station.
        StationDrones[d.stationIndex] = nil
    end

    Drones[netId] = nil
    Sirens[netId] = nil
    -- A destroyed drone must not leave a countdown ticking on someone's screen.
    -- The ticker below notices the drone is gone and tears the warning down.
    TriggerClientEvent('combat_drone:droneUnregistered', -1, netId)
end)

-- Relays drone damage to the victim's own client, since a client can only
-- damage peds it owns.
--
-- This is a client-triggered damage event, so it is validated rather than
-- trusted: the damage is clamped, and each shooter is rate limited to a
-- plausible rate of fire. Tighten maxDamage/minInterval if you open this server
-- up; a determined cheater could still call it, but only for capped chip damage
-- at a bounded rate.
local maxDamagePerHit = 50
local minIntervalMs = 50
local lastDamageAt = {} -- [source] = GetGameTimer()

RegisterServerEvent('combat_drone:damagePlayer')
AddEventHandler('combat_drone:damagePlayer', function(targetSrc, damage)
    local src = source

    targetSrc = tonumber(targetSrc)
    damage = tonumber(damage)
    if not targetSrc or not damage or damage <= 0 then return end
    if GetPlayerName(tostring(targetSrc)) == nil then return end

    local now = GetGameTimer()
    if lastDamageAt[src] and (now - lastDamageAt[src]) < minIntervalMs then return end
    lastDamageAt[src] = now

    if next(Drones) == nil then return end -- no drones exist, so nothing can be shooting

    TriggerClientEvent('combat_drone:takeDamage', targetSrc, math.min(damage, maxDamagePerHit))
end)

-- =============================================================================
-- WARNINGS
-- =============================================================================
-- The server owns the countdown clock. See client/warning.lua for why: the
-- drone's AI runs on whichever client currently controls it, and OneSync can
-- migrate that mid-countdown. A client-owned timer would restart on every
-- migration, so a player could never actually run out of time.
--
-- Flow:
--   controlling client heartbeats 'warnTarget' while it wants someone warned
--   -> the first beat creates the warning and fixes expiresAt
--   -> every beat pushes the remaining time to the TARGET's client
--   -> the ticker below expires it (flagging the player) or times it out when
--      the beats stop (drone died / lost them / resource stopped)

-- Like the damage relay above, these are client-triggered events and so are
-- rate limited rather than trusted. There is no cheap server-side way to prove
-- a given client really controls a given drone entity, so the guarantee here is
-- bounded nuisance, not authenticity: the worst a spammer achieves is showing a
-- countdown that a real drone isn't backing up. Tighten the interval, or gate
-- these on your own ownership check, if you open this server up.
local eventRate = {} -- [source] = { [event] = last GetGameTimer() }

local function RateLimited(src, key, minInterval)
    local now = GetGameTimer()
    local perSource = eventRate[src]
    if not perSource then
        perSource = {}
        eventRate[src] = perSource
    end
    if perSource[key] and (now - perSource[key]) < minInterval then return true end
    perSource[key] = now
    return false
end

local function ClearWarning(netId, notifyTarget)
    local w = Warnings[netId]
    if not w then return end
    Warnings[netId] = nil
    if notifyTarget and GetPlayerName(tostring(w.targetSrc)) ~= nil then
        -- Only hide the HUD if no OTHER drone is still warning this player.
        for _, other in pairs(Warnings) do
            if other.targetSrc == w.targetSrc then return end
        end
        TriggerClientEvent('combat_drone:hideWarning', w.targetSrc)
    end
end

RegisterServerEvent('combat_drone:warnTarget')
AddEventHandler('combat_drone:warnTarget', function(netId, targetSrc)
    netId = tonumber(netId)
    targetSrc = tonumber(targetSrc)
    if not netId or not targetSrc then return end
    if not Drones[netId] then return end -- unknown drone: ignore
    if GetPlayerName(tostring(targetSrc)) == nil then return end
    -- Half the heartbeat interval: legitimate beats always get through, floods
    -- don't. Dropping a beat is harmless -- the server owns expiresAt, and
    -- staleTimeout is several beats long.
    -- Keyed per drone, not per client: one client can legitimately be warning
    -- several people from several drones at once.
    if RateLimited(source, 'warn:' .. netId, Config.Warning.heartbeatInterval / 2) then return end

    local now = GetGameTimer()
    local w = Warnings[netId]

    if not w or w.targetSrc ~= targetSrc then
        -- New warning, or this drone switched to a different player.
        if w then ClearWarning(netId, true) end
        w = { targetSrc = targetSrc, expiresAt = now + Config.Warning.duration }
        Warnings[netId] = w
    end

    w.lastBeat = now
    TriggerClientEvent('combat_drone:showWarning', targetSrc,
        math.max(w.expiresAt - now, 0), Config.Warning.duration)
end)

RegisterServerEvent('combat_drone:clearWarning')
AddEventHandler('combat_drone:clearWarning', function(netId, targetSrc)
    netId = tonumber(netId)
    local w = Warnings[netId]
    if not w then return end
    if targetSrc and w.targetSrc ~= tonumber(targetSrc) then return end
    ClearWarning(netId, true)
end)

CreateThread(function()
    while true do
        Wait(250)
        local now = GetGameTimer()

        for netId, w in pairs(Warnings) do
            if GetPlayerName(tostring(w.targetSrc)) == nil then
                Warnings[netId] = nil                       -- target disconnected
            elseif not Drones[netId] then
                ClearWarning(netId, true)                   -- the drone was destroyed or deleted
            elseif (now - (w.lastBeat or 0)) > Config.Warning.staleTimeout then
                ClearWarning(netId, true)                   -- the drone stopped caring
            elseif now >= w.expiresAt then
                -- Time's up. Everyone is told, so whichever client controls any
                -- drone knows to engage this player on sight.
                Flags[w.targetSrc] = now + Config.Warning.flagDuration
                TriggerClientEvent('combat_drone:flagPlayer', -1, w.targetSrc, Config.Warning.flagDuration)
                -- Tell the target first: ClearWarning would otherwise hide the
                -- HUD outright, and the expiry banner is the whole point of the
                -- moment the drone opens fire.
                TriggerClientEvent('combat_drone:warningExpired', w.targetSrc)
                ClearWarning(netId, false)
            end
        end

        for serverId, until_ in pairs(Flags) do
            if now >= until_ then Flags[serverId] = nil end
        end
    end
end)

-- =============================================================================
-- ALERT SIREN
-- =============================================================================
-- Decided by the controlling client, heard by everyone: the state is relayed
-- here and each client renders the sound locally from its own copy of the
-- entity, so the sound follows the drone with zero ongoing bandwidth.

RegisterServerEvent('combat_drone:setSiren')
AddEventHandler('combat_drone:setSiren', function(netId, on)
    netId = tonumber(netId)
    if not netId or not Drones[netId] then return end
    if RateLimited(source, 'siren:' .. netId, 250) then return end

    on = on and true or false
    if Sirens[netId] == on or (not on and Sirens[netId] == nil) then return end

    Sirens[netId] = on or nil
    TriggerClientEvent('combat_drone:sirenState', -1, netId, on)
end)

-- =============================================================================
-- AIRSTRIKE TELEGRAPHS
-- =============================================================================
-- The missiles themselves are real networked projectiles, so everyone sees them
-- without any help. Only the ground markers need relaying: they are drawn by
-- each client locally, and bystanders deserve the same warning the target gets.

RegisterServerEvent('combat_drone:strikeMarker')
AddEventHandler('combat_drone:strikeMarker', function(x, y, z, leadMs)
    x, y, z, leadMs = tonumber(x), tonumber(y), tonumber(z), tonumber(leadMs)
    if not x or not y or not z or not leadMs then return end
    if next(Drones) == nil then return end -- no drones exist, so nothing can be calling a strike
    -- One marker per missile, so the legitimate rate is one per Strike.interval.
    if RateLimited(source, 'strike', 300) then return end

    leadMs = math.min(math.max(leadMs, 0), 10000)
    TriggerClientEvent('combat_drone:strikeMarker', -1, x, y, z, leadMs)
end)

AddEventHandler('playerDropped', function()
    lastDamageAt[source] = nil
    eventRate[source] = nil
    Flags[source] = nil
    for netId, w in pairs(Warnings) do
        if w.targetSrc == source then Warnings[netId] = nil end
    end
end)

-- Lets a freshly connected/joined client learn about drones that already exist.
RegisterServerEvent('combat_drone:requestRegistry')
AddEventHandler('combat_drone:requestRegistry', function()
    local src = source
    local ids = {}
    for netId in pairs(Drones) do
        ids[#ids + 1] = netId
    end
    TriggerClientEvent('combat_drone:syncRegistry', src, ids)

    -- Siren state is edge-triggered, so a client that joined after a drone
    -- started sounding would otherwise never hear it.
    for netId in pairs(Sirens) do
        TriggerClientEvent('combat_drone:sirenState', src, netId, true)
    end

    -- Same for "engage on sight" flags. A joining client can become the
    -- controller of a nearby drone within seconds, and without these it would
    -- hand an already-flagged player a fresh warning instead of opening fire.
    local now = GetGameTimer()
    for serverId, until_ in pairs(Flags) do
        if until_ > now then
            TriggerClientEvent('combat_drone:flagPlayer', src, serverId, until_ - now)
        end
    end
end)
