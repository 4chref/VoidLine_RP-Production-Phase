-- =============================================================================
-- combat_drone / client/warning.lua
--
-- The drone challenges before it kills. On spotting a player it holds station,
-- sounds its alert, and puts a countdown on THAT PLAYER'S screen: leave, or be
-- eliminated. Only when the countdown runs out does it open fire.
--
-- WHY THE SERVER OWNS THE CLOCK
-- The countdown has to be displayed on the target's machine while it is decided
-- on the (different) machine that currently controls the drone, and OneSync can
-- migrate that control mid-countdown. If each controlling client kept its own
-- timer, every migration would silently restart the player's countdown and the
-- warning would never expire while anyone kept moving. So:
--
--   controlling client --(heartbeat while it wants the target warned)--> server
--   server owns expiresAt, pushes remaining ms to the TARGET client
--   server declares the expiry and broadcasts it to everyone
--
-- Heartbeats also double as a liveness signal: if the drone dies, loses the
-- target, or the resource stops, the beats stop, the server tears the warning
-- down, and the countdown disappears from the player's screen on its own.
--
-- After a countdown expires the player is FLAGGED. Flagged players get no
-- second warning from any drone until the flag ages out -- otherwise a player
-- could farm warnings forever by stepping in and out of range.
-- =============================================================================

Warning = {}

-- serverId -> game-time ms at which the "engage on sight" flag lapses.
local flagged = {}

local function IsFlagged(serverId)
    local until_ = flagged[serverId]
    if not until_ then return false end
    if GetGameTimer() >= until_ then
        flagged[serverId] = nil
        return false
    end
    return true
end

function Warning.Init(drone)
    drone.warning = nil
    -- [serverId] = game time the countdown for that player began.
    --
    -- Deliberately NOT cleared by Warning.Pause. Two reasons: a target who keeps
    -- ducking in and out of sight must not be able to restart their own
    -- countdown, and the local expiry fallback in Warning.Evaluate depends on it
    -- surviving the WARNING -> LOST_TARGET -> WARNING cycle.
    drone.warnStartedAt = {}
end

-- =============================================================================
-- DECISION
-- =============================================================================

-- What should the drone do about a confirmed, visible target right now?
-- Returns 'warn' (hold fire, run the countdown) or 'engage' (weapons free).
function Warning.Evaluate(drone, target, isUrgent)
    if not Config.Warning.enabled then return 'engage' end

    -- Someone already shooting at the drone has forfeited the courtesy.
    if isUrgent then return 'engage' end

    -- NPCs get no warning: there is nobody to show a countdown to.
    local serverId = Utils.ServerIdFromPed(target)
    if not serverId then return 'engage' end

    if IsFlagged(serverId) then return 'engage' end

    -- LOCAL EXPIRY FALLBACK.
    --
    -- The server owns the countdown the player SEES, and it should normally win
    -- this race (hence the grace period). But the drone's ability to open fire
    -- must not depend on a round trip completing: if the relay, the flag
    -- broadcast or the NUI page is broken in any way, the drone would otherwise
    -- orbit a non-complying player forever and never shoot. Weapons-free is
    -- decided here, on the machine that actually pulls the trigger.
    local startedAt = drone.warnStartedAt and drone.warnStartedAt[serverId]
    if startedAt and (GetGameTimer() - startedAt) >= (Config.Warning.duration + Config.Warning.localGrace) then
        flagged[serverId] = GetGameTimer() + Config.Warning.flagDuration
        Warning.ShowExpired(serverId)
        if Config.Debug then
            print(('[combat_drone] drone %s: countdown on %d expired locally -- weapons free')
                :format(tostring(drone.ped), serverId))
        end
        return 'engage'
    end

    return 'warn'
end

-- =============================================================================
-- LIFECYCLE (controlling client)
-- =============================================================================

-- Call every decision tick while the drone wants `target` warned. Starts the
-- warning on the first call and heartbeats it afterwards.
function Warning.Sustain(drone, target)
    local serverId = Utils.ServerIdFromPed(target)
    if not serverId then return end

    local now = GetGameTimer()

    drone.warnStartedAt = drone.warnStartedAt or {}
    drone.warnStartedAt[serverId] = drone.warnStartedAt[serverId] or now

    local w = drone.warning
    if not w or w.serverId ~= serverId then
        w = { serverId = serverId, target = target, nextBeatAt = 0 }
        drone.warning = w
    end

    if now < w.nextBeatAt then return end
    w.nextBeatAt = now + Config.Warning.heartbeatInterval

    TriggerServerEvent('combat_drone:warnTarget', drone.netId, serverId)
end

-- Hard stop: the drone has genuinely stood down (destroyed, retreating, the
-- player left, or the countdown already expired and it is now shooting). The
-- countdown comes off the target's screen immediately.
function Warning.Cancel(drone, reason)
    local w = drone.warning
    if not w then return end
    drone.warning = nil

    -- A hard stand-down means the next encounter starts a fresh countdown.
    if drone.warnStartedAt then drone.warnStartedAt[w.serverId] = nil end

    if Config.Debug then
        print(('[combat_drone] drone %s: warning on %d cancelled (%s)')
            :format(tostring(drone.ped), w.serverId, reason or 'unspecified'))
    end

    TriggerServerEvent('combat_drone:clearWarning', drone.netId, w.serverId)
end

-- Soft stop: just stop heartbeating, without telling the server to cancel.
--
-- Used when the drone has momentarily lost sight of the target rather than lost
-- the target. The server keeps the countdown alive for staleTimeout, so someone
-- who ducks behind a car for a second comes back to their ORIGINAL countdown --
-- if this cancelled outright, breaking line of sight would be a free reset and
-- nobody would ever actually run out of time.
function Warning.Pause(drone, reason)
    if not drone.warning then return end
    if Config.Debug then
        print(('[combat_drone] drone %s: warning on %d paused (%s)')
            :format(tostring(drone.ped), drone.warning.serverId, reason or 'unspecified'))
    end
    drone.warning = nil
end

-- Has the target moved far enough away to be let off? Checked against the
-- flyer's position, since that is what the player is running from.
function Warning.HasEscaped(drone, target)
    if not target or not DoesEntityExist(target) then return true end
    local d = Utils.Vdist(GetEntityCoords(Utils.Flyer(drone)), GetEntityCoords(target))
    return d > Config.Warning.clearRadius
end

-- =============================================================================
-- NETWORK
-- =============================================================================

-- Server -> the warned player only. Repeated on every heartbeat, which is what
-- keeps the on-screen countdown alive (the page hides itself if the beats stop).
RegisterNetEvent('combat_drone:showWarning', function(remaining, duration)
    SendNUIMessage({
        action = 'warn_show',
        remaining = remaining,
        duration = duration,
        message = Config.Warning.message,
        sub = Config.Warning.subMessage,
        tag = Config.Warning.tag,
    })
end)

RegisterNetEvent('combat_drone:hideWarning', function()
    SendNUIMessage({ action = 'warn_hide' })
end)

-- Time's up, on this player's own screen. Sent by the server when it declares
-- the expiry, and raised locally by Warning.ShowExpired if the drone had to fall
-- back to its own clock.
local function ShowExpiredHud()
    -- The sub-line names what is actually coming, so the banner matches what the
    -- player is about to experience: the drone opening fire, or ordnance.
    local sub = Config.Strike.enabled
        and Config.Warning.expiredStrikeSubMessage
        or Config.Warning.expiredSubMessage

    SendNUIMessage({
        action = 'warn_expired',
        message = Config.Warning.expiredMessage,
        sub = sub,
        displayMs = Config.Warning.expiredDisplayMs,
    })
end

RegisterNetEvent('combat_drone:warningExpired', ShowExpiredHud)

-- Called by the local expiry fallback. Only the warned player sees the banner,
-- so this is a no-op on every other client.
function Warning.ShowExpired(serverId)
    if serverId ~= GetPlayerServerId(PlayerId()) then return end
    ShowExpiredHud()
end

-- Broadcast to everyone: this player's countdown ran out and every drone may
-- now engage them on sight for `duration` ms.
RegisterNetEvent('combat_drone:flagPlayer', function(serverId, duration)
    flagged[serverId] = GetGameTimer() + (tonumber(duration) or Config.Warning.flagDuration)
end)

RegisterNetEvent('combat_drone:unflagPlayer', function(serverId)
    flagged[serverId] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SendNUIMessage({ action = 'warn_hide' })
end)
