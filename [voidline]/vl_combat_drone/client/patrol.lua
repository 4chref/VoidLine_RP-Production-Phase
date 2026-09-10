-- =============================================================================
-- combat_drone / client/patrol.lua
-- Cycles through Config.PatrolPoints, waiting briefly at each one.
-- =============================================================================

Patrol = {}

function Patrol.Init(drone)
    -- Start at the nearest patrol point rather than always index 1.
    local coords = GetEntityCoords(Utils.Flyer(drone))
    local bestIdx, bestDist = 1, math.huge
    for i, p in ipairs(Config.PatrolPoints) do
        local d = Utils.Vdist(coords, p)
        if d < bestDist then bestDist, bestIdx = d, i end
    end
    drone.patrol = {
        index = bestIdx,
        waitingUntil = 0,
    }
end

-- STATION KEEPING.
--
-- A drone with drone.station set does not tour the patrol route: its "current
-- patrol point" is always its own station. Hooking in here rather than adding a
-- new state means every existing behaviour follows automatically --
--   PATROL    hovers over the station instead of touring
--   RETURNING already flies to Patrol.GetCurrentPoint, so after a strike and
--             the withdrawal it comes home to the same spot by itself
--   SEARCHING and the combat states are untouched
-- and no flight, obstacle or altitude code had to change.
function Patrol.GetCurrentPoint(drone)
    if drone.station then return drone.station end
    if #Config.PatrolPoints == 0 then return GetEntityCoords(Utils.Flyer(drone)) end
    return Config.PatrolPoints[drone.patrol.index]
end

-- Call every patrol-decision tick. Advances to next point once close enough
-- and the wait timer has elapsed. Returns the point the drone should be
-- flying toward right now.
-- The full 3D point a stationed drone should be sitting at.
--
-- PATROL and RETURNING both used to derive altitude as
-- `GetGroundZ(point) + patrolHoverHeight`. That is right for a ground-level
-- patrol route, and wrong for a station whose Z is already the altitude -- it
-- would add the hover height a second time. Both states call this instead, so
-- the rule lives in one place.
---@return vector3
function Patrol.GetHoldDestination(drone)
    local point = Patrol.GetCurrentPoint(drone)

    if drone.station and Config.AutoSpawn and Config.AutoSpawn.absoluteAltitude then
        return point
    end

    local groundZ = Utils.GetGroundZ(point)
    return vector3(point.x, point.y, groundZ + Config.Movement.patrolHoverHeight)
end

function Patrol.Update(drone)
    -- Stationed drones never advance an index: there is one point and they hold
    -- it. Returned before the wait/advance logic below so a drone sitting on its
    -- station does not tick a timer that would move it on.
    if drone.station then return drone.station end

    if #Config.PatrolPoints == 0 then
        return GetEntityCoords(Utils.Flyer(drone))
    end

    local now = GetGameTimer()
    local point = Patrol.GetCurrentPoint(drone)
    local coords = GetEntityCoords(Utils.Flyer(drone))
    local dist = Utils.Vdist2D(coords, point)

    if dist < 4.0 then
        if drone.patrol.waitingUntil == 0 then
            drone.patrol.waitingUntil = now + Config.PatrolWaitTime
        elseif now >= drone.patrol.waitingUntil then
            drone.patrol.index = (drone.patrol.index % #Config.PatrolPoints) + 1
            drone.patrol.waitingUntil = 0
        end
    else
        drone.patrol.waitingUntil = 0
    end

    return point
end
