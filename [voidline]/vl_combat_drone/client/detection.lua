-- =============================================================================
-- combat_drone / client/detection.lua
--
-- Handles "can the drone actually perceive this target right now" -- distance,
-- field of view, line of sight, and a per-target memory of last known
-- position/time so the drone behaves like it has real senses instead of
-- omniscient wallhacks. Runs on a scan interval, not every frame.
-- =============================================================================

Detection = {}

-- drone.knownTargets[entity] = {
--   lastSeenCoords = vector3, lastSeenTime = GetGameTimer(),
--   isVisible = bool, firstSeenTime = number
-- }

local function IsMoving(ped)
    return GetEntitySpeed(ped) > 0.5
end

function Detection.Init(drone)
    drone.knownTargets = {}
end

-- Full scan: looks at nearby players (and optionally hostile NPCs) and
-- updates the drone's memory for anyone within radius+FOV+LOS.
function Detection.Scan(drone)
    -- Sense from whatever is actually flying: in piloted mode the pilot ped sits
    -- inside the vehicle, so its own coords/forward vector are the vehicle's.
    local ped = Utils.Flyer(drone)
    local coords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local now = GetGameTimer()

    local radius = Config.Detection.radius
    -- includeSelf MUST be true: the drone's AI only runs on whichever client
    -- currently controls it (normally the closest player), so excluding the
    -- local player meant the drone could never see the very player standing
    -- next to it -- with one player on the server, it never saw anyone at all.
    local candidates = Utils.GetNearbyPlayerPeds(coords, radius + Config.Detection.movementBonusRadius, true)

    for _, c in ipairs(candidates) do
        local target = c.ped
        local targetCoords = GetEntityCoords(target)
        local dist = c.distance

        local effectiveRadius = radius
        if IsMoving(target) or IsPedShooting(target) then
            effectiveRadius = radius + Config.Detection.movementBonusRadius
        end

        if dist <= effectiveRadius then
            local angle = Utils.AngleToPointDeg(coords, fwd, targetCoords)
            local halfFov = Config.Detection.fov / 2.0

            -- Being actively shot at grants awareness even slightly outside FOV
            -- (a drone "hears"/reacts to incoming fire), everything else needs
            -- to be within the visual cone.
            local underFire = drone.currentAttacker == target and (now - (drone.lastAttackedTime or 0)) < 3000
            local withinFov = math.abs(angle) <= halfFov or underFire

            if withinFov then
                local hasLos = true
                if Config.Detection.requireLineOfSight then
                    hasLos = Utils.HasLineOfSightToEntity(ped, target)
                end

                if hasLos then
                    drone.knownTargets[target] = drone.knownTargets[target] or { firstSeenTime = now }
                    drone.knownTargets[target].lastSeenCoords = targetCoords
                    drone.knownTargets[target].lastSeenTime = now
                    drone.knownTargets[target].isVisible = true
                    drone.knownTargets[target].distance = dist
                else
                    if drone.knownTargets[target] then
                        drone.knownTargets[target].isVisible = false
                    end
                end
            elseif drone.knownTargets[target] then
                drone.knownTargets[target].isVisible = false
            end
        elseif drone.knownTargets[target] then
            drone.knownTargets[target].isVisible = false
        end
    end

    -- Purge stale memory.
    for target, mem in pairs(drone.knownTargets) do
        if not DoesEntityExist(target) or IsEntityDead(target) then
            drone.knownTargets[target] = nil
        elseif (now - mem.lastSeenTime) > Config.TargetMemoryDuration then
            drone.knownTargets[target] = nil
        end
    end
end

-- Cheap, frequent re-check of LOS on a single (already selected) target,
-- without doing a full area scan.
--
-- PERF: the flight thread calls this EVERY FRAME on the current target, and
-- HasEntityClearLosToEntity is a real world trace. At 60fps that is 60 traces
-- per second per engaged drone for an answer that cannot meaningfully change
-- that fast -- losRefreshInterval throttles the trace to ~10Hz and reuses the
-- last result in between. The distance is still recomputed on every call: it is
-- pure arithmetic, it costs nothing, and combat range gating reads it.
function Detection.RefreshVisibility(drone, target)
    if not target or not DoesEntityExist(target) then return false end
    local flyer = Utils.Flyer(drone)
    local targetCoords = GetEntityCoords(target)
    local now = GetGameTimer()

    local mem = drone.knownTargets[target]

    local hasLos
    if mem and mem.nextLosAt and now < mem.nextLosAt then
        hasLos = mem.isVisible
    else
        hasLos = Utils.HasLineOfSightToEntity(flyer, target)
        if mem then
            mem.nextLosAt = now + Config.Detection.losRefreshInterval
        end
    end

    if mem then
        mem.isVisible = hasLos
        -- Keep distance fresh on the flight tick, not just on the 1s area scan:
        -- combat range gating reads it, and both parties move fast enough that
        -- a second-old value is badly out of date.
        mem.distance = Utils.Vdist(GetEntityCoords(flyer), targetCoords)
        if hasLos then
            mem.lastSeenCoords = targetCoords
            mem.lastSeenTime = now
        end
    end
    return hasLos
end

function Detection.GetVisibleTargets(drone)
    local out = {}
    for target, mem in pairs(drone.knownTargets) do
        if mem.isVisible then out[#out + 1] = target end
    end
    return out
end
