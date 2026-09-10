-- =============================================================================
-- combat_drone / client/strike.lua
--
-- What happens when the countdown runs out: the drone breaks off and leaves,
-- and the target is hit by missiles falling out of the sky.
--
-- WHY THE DRONE LEAVES FIRST
-- The drone is the spotter, not the shooter. It withdraws (gaining distance and
-- altitude, see the WITHDRAWING state in statemachine.lua) both so it reads as
-- "it called something in on you" and so it isn't standing in its own ordnance
-- when the rockets land. Config.Strike.delay is deliberately longer than the
-- drone needs to clear the blast radius.
--
-- EACH MISSILE IS AIMED WHEN IT IS FIRED, NOT UP FRONT
-- Computing all impact points at call time would make the whole strike dodgeable
-- by taking one step, and would also make it unavoidable for anyone standing
-- still -- the worst of both. Instead every missile picks its own impact point
-- from the target's CURRENT position (plus lead and scatter), telegraphs it with
-- a ground marker for Config.Strike.markerLeadTime, and only then launches. A
-- player who sprints can outrun individual missiles; a player who stays put
-- cannot survive the salvo. That is the whole point of "leave the area".
--
-- The missiles are real GTA projectiles, so the trail, the impact explosion and
-- the damage are all the game's own -- nothing here simulates a blast.
-- =============================================================================

Strike = {}

local lastStrikeAt = {} -- serverId -> game time of that player's last strike

-- =============================================================================
-- WEAPON
-- =============================================================================

local assetsRequested = {}
local function EnsureAsset(hash)
    if HasWeaponAssetLoaded(hash) then return true end
    if not assetsRequested[hash] then
        assetsRequested[hash] = true
        RequestWeaponAsset(hash, 31, 0)
    end
    return false
end

-- Preload so the first missile of a strike isn't swallowed while the asset
-- streams in -- a strike that visibly starts late reads as broken.
CreateThread(function()
    Wait(2000)
    if Config.Strike.enabled then
        EnsureAsset(Config.Strike.weapon)
        EnsureAsset(Config.Strike.fallbackWeapon)
    end
end)

-- Never returns an unloaded hash: ShootSingleBulletBetweenCoords with an asset
-- that hasn't streamed in silently produces no projectile at all. nil here means
-- "fall back to a direct explosion" rather than "fire nothing".
local function StrikeWeapon()
    if EnsureAsset(Config.Strike.weapon) then return Config.Strike.weapon end
    if EnsureAsset(Config.Strike.fallbackWeapon) then return Config.Strike.fallbackWeapon end
    return nil
end

-- =============================================================================
-- IMPACT MARKERS
-- =============================================================================
-- The telegraph. Drawn by every client that can see the spot, so bystanders get
-- the same warning the target does.

local markers = {}

function Strike.AddMarker(pos, leadMs)
    local now = GetGameTimer()
    markers[#markers + 1] = {
        pos = pos,
        born = now,
        expires = now + leadMs,
        duration = math.max(leadMs, 1),
    }
end

CreateThread(function()
    while true do
        if #markers == 0 then
            Wait(200) -- nothing incoming: cost nothing
        else
            local now = GetGameTimer()
            local cfg = Config.Strike.marker

            for i = #markers, 1, -1 do
                local m = markers[i]
                if now >= m.expires then
                    table.remove(markers, i)
                else
                    -- t goes 0 -> 1 as impact approaches.
                    local t = Utils.Clamp((now - m.born) / m.duration, 0.0, 1.0)

                    -- The ring closes in on the impact point, so the danger
                    -- reads as "arriving" rather than just "here".
                    local radius = Utils.Lerp(cfg.startRadius, cfg.endRadius, t)
                    -- Flashing accelerates toward impact.
                    local blinkHz = Utils.Lerp(cfg.slowBlinkHz, cfg.fastBlinkHz, t)
                    local on = (math.floor((now / 1000.0) * blinkHz * 2.0) % 2) == 0
                    local alpha = on and cfg.alphaOn or cfg.alphaOff

                    local c = cfg.color
                    DrawMarker(1, m.pos.x, m.pos.y, m.pos.z - 0.95,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        radius * 2.0, radius * 2.0, cfg.height,
                        c.r, c.g, c.b, alpha,
                        false, false, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
    end
end)

-- Marker positions are relayed so everyone nearby sees the telegraph, not just
-- whichever client happens to be running the drone's AI.
RegisterNetEvent('combat_drone:strikeMarker', function(x, y, z, leadMs)
    if not Config.Strike.marker.enabled then return end
    local pos = vector3(x, y, z)
    -- Skip telegraphs far enough away to be invisible anyway.
    if Utils.Vdist(GetEntityCoords(PlayerPedId()), pos) > Config.Strike.marker.drawDistance then return end
    Strike.AddMarker(pos, leadMs)
end)

-- =============================================================================
-- FIRING
-- =============================================================================

local function LaunchMissile(ownerPed, impact)
    local cfg = Config.Strike
    -- Launch from almost directly overhead, with a small offset so the missiles
    -- don't all fall down an identical vertical line.
    local from = vector3(
        impact.x + Utils.RandomFloat(-cfg.launchJitter, cfg.launchJitter),
        impact.y + Utils.RandomFloat(-cfg.launchJitter, cfg.launchJitter),
        impact.z + cfg.spawnHeight
    )

    local hash = StrikeWeapon()
    if hash then
        -- A real rocket: its own trail, its own impact explosion, its own damage.
        ShootSingleBulletBetweenCoords(
            from.x, from.y, from.z,
            impact.x, impact.y, impact.z,
            cfg.damage,
            true,
            hash,
            ownerPed,
            true,   -- audible
            false,  -- visible projectile
            cfg.speed
        )
    elseif cfg.explosionFallback then
        -- Neither rocket asset streamed in. Detonate directly rather than have
        -- the strike silently do nothing -- no projectile was created, so this
        -- cannot double up with one.
        AddExplosion(impact.x, impact.y, impact.z, cfg.explosionType,
            cfg.explosionScale, true, false, cfg.cameraShake)
    end

    Strike.missilesFired = (Strike.missilesFired or 0) + 1
end

-- =============================================================================
-- THE STRIKE
-- =============================================================================

function Strike.OnCooldown(serverId)
    local last = lastStrikeAt[serverId]
    return last ~= nil and (GetGameTimer() - last) < Config.Strike.cooldown
end

-- Used by /dronestrike so repeated tests aren't swallowed by the cooldown.
function Strike.ClearCooldown(serverId)
    lastStrikeAt[serverId] = nil
end

-- Called once by the state machine when a countdown expires. Runs to completion
-- on its own thread: the drone is leaving, and the strike must not depend on it
-- still being there (or on this client still controlling it).
function Strike.Call(drone, target)
    if not Config.Strike.enabled then return false end
    if not target or not DoesEntityExist(target) then return false end

    local serverId = Utils.ServerIdFromPed(target)
    if serverId and Strike.OnCooldown(serverId) then return false end
    if serverId then lastStrikeAt[serverId] = GetGameTimer() end

    -- Resolved now: the drone may be deleted before the salvo finishes, and an
    -- invalid owner entity means the rocket never spawns.
    local ownerPed = (drone and DoesEntityExist(drone.ped)) and drone.ped or PlayerPedId()

    local cfg = Config.Strike
    if Config.Debug then
        print(('[combat_drone] strike called on %s (%d missiles)')
            :format(tostring(serverId or target), cfg.count))
    end

    CreateThread(function()
        Wait(cfg.delay) -- lets the drone clear its own blast radius first

        for i = 1, cfg.count do
            if not DoesEntityExist(target) or IsEntityDead(target) then return end

            local tc = GetEntityCoords(target)

            -- Lead a moving target, so sprinting in a straight line isn't a free
            -- escape -- but only by a fraction of its velocity, so changing
            -- direction still beats it.
            local lead = vector3(0.0, 0.0, 0.0)
            if cfg.leadTarget then
                local v = GetEntityVelocity(target)
                lead = vector3(v.x, v.y, 0.0) * cfg.leadFactor
            end

            local impact = vector3(
                tc.x + lead.x + Utils.RandomFloat(-cfg.spread, cfg.spread),
                tc.y + lead.y + Utils.RandomFloat(-cfg.spread, cfg.spread),
                tc.z
            )
            impact = vector3(impact.x, impact.y, Utils.GetGroundZ(impact))

            if cfg.marker.enabled then
                Strike.AddMarker(impact, cfg.markerLeadTime) -- locally, with no round-trip delay
                TriggerServerEvent('combat_drone:strikeMarker', impact.x, impact.y, impact.z, cfg.markerLeadTime)
            end

            Wait(cfg.markerLeadTime)
            if not DoesEntityExist(target) then return end
            LaunchMissile(ownerPed, impact)

            Wait(cfg.interval)
        end
    end)

    return true
end
