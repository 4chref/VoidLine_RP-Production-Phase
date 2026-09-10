-- =============================================================================
-- combat_drone / client/movement.lua
--
-- Drives the drone's simulated flight. GTA peds have no native flight task, and
-- an airborne vehicle steered by script has no autopilot, so we:
--   1. Freeze the ped's physics response to gravity/collision-falling
--      (SetEntityHasGravity false, FreezeEntityPosition is NOT used, since
--      that would make it fully static -- instead we keep it a mission
--      entity with gravity disabled and drive position ourselves). Piloted
--      drones keep their physics and are steered by velocity instead.
--   2. Integrate a velocity vector every tick (acceleration/deceleration
--      toward a desired velocity), blend in obstacle avoidance, clamp to
--      configured min/max altitude, and move the flyer smoothly -- small
--      continuous steps, not a single long-distance teleport.
--   3. Smoothly rotate heading toward the direction of travel, or toward a
--      forced "face" target during combat.
--
-- COLLISION SAFETY (see also client/obstacle.lua)
-- Steering away from obstacles is not on its own enough to stop a drone
-- hitting things, because steering only changes *where* it is heading, never
-- how fast it gets there. Three separate mechanisms handle that here:
--   * the sensed brake factor caps speed as obstacles get close, so there is
--     always enough runway to turn;
--   * CancelIntoSurface removes the component of velocity that points into a
--     surface the drone is already nearly touching, so it slides along walls
--     instead of pressing into them;
--   * a stuck detector notices when the drone is being commanded to move but
--     isn't actually going anywhere (wedged in an alley, under an awning) and
--     forces a vertical escape.
-- =============================================================================

Movement = {}

local ZERO = vector3(0.0, 0.0, 0.0)

function Movement.Init(drone)
    drone.velocity = drone.velocity or ZERO
    Obstacle.Init(drone)
    drone.stuck = { since = nil, escapeUntil = 0, lastPos = nil, lastCheck = 0, escapeDir = nil }

    if Utils.IsPiloted(drone) then
        -- The vehicle carries its own physics; we only steer it. Gravity stays
        -- ON (velocity is re-applied every tick, which holds it up) so it falls
        -- naturally if the AI ever stops driving it.
        local veh = drone.vehicle
        SetEntityInvincible(veh, false)
        SetVehicleEngineOn(veh, true, true, false)
        if Config.Piloted.holdHoverNozzle then
            SetVehicleFlightNozzlePosition(veh, 1.0) -- VTOL hover
        end
        if Config.Movement.collisionProof then
            -- Scraping a lamp post should not write off an armed drone, but it
            -- must still be shootable. Only the collision proof is set; bullets,
            -- fire and explosions all still hurt it exactly as before.
            SetEntityProofs(veh, false, false, false, true, false, false, false, false)
        end
        return
    end

    SetEntityHasGravity(drone.ped, false)
    SetEntityInvincible(drone.ped, false)
    SetEntityCollision(drone.ped, true, true)
end

-- =============================================================================
-- ALTITUDE
-- =============================================================================

-- Clamp a desired position's Z so the drone stays within its configured
-- altitude band above whatever is beneath it. `surfaceZ` comes from the
-- obstacle sense and is roof-aware, unlike a plain ground probe.
local function ClampAltitude(pos, surfaceZ)
    local baseZ = surfaceZ or Utils.GetGroundZ(pos)
    local minZ = baseZ + Config.Movement.minAltitudeAboveGround
    local maxZ = baseZ + Config.Movement.maxAltitudeAboveGround
    return vector3(pos.x, pos.y, Utils.Clamp(pos.z, minZ, maxZ))
end

-- Destinations are chosen by combat/patrol logic that knows nothing about
-- geometry, so a hover point can easily land inside a building or below a roof.
-- Lifting it to a flyable height here is far cheaper than letting the drone
-- discover the problem by flying into it.
--
-- The surface probe under the destination is cached and only re-run when the
-- destination has actually moved somewhere new (or the cache has aged out) --
-- an orbit point slides a few centimetres per frame and does not deserve a
-- fresh raycast each time.
function Movement.SanitizeDestination(drone, dest)
    local c = drone.destProbe
    if not c then
        c = { at = 0, pos = nil, surfaceZ = nil }
        drone.destProbe = c
    end

    local now = GetGameTimer()
    local moved = (not c.pos) or Utils.Vdist2D(c.pos, dest) > Config.Movement.destProbeMoveThreshold
    if moved or now >= c.at then
        c.surfaceZ = Obstacle.SurfaceZ(dest, Utils.Flyer(drone))
        c.pos = dest
        c.at = now + Config.Movement.destProbeInterval
    end

    local minZ = (c.surfaceZ or Utils.GetGroundZ(dest)) + Config.Movement.minAltitudeAboveGround
    if dest.z < minZ then
        return vector3(dest.x, dest.y, minZ)
    end
    return dest
end

-- =============================================================================
-- COLLISION SAFETY
-- =============================================================================

-- Strips the part of `vel` that drives into a surface the drone is already
-- close to, and adds a gentle push back off it. Uses the normal cached by the
-- obstacle sense, so this costs nothing per frame.
local function CancelIntoSurface(vel, normal)
    local n = Utils.Normalize(normal)
    if #n < 0.01 then return vel end

    local into = Utils.Dot(vel, n)
    if into >= 0.0 then return vel end -- already moving away from the surface

    local slide = vel - n * into                       -- component along the wall
    return slide + n * Config.ObstacleAvoidance.separationSpeed
end

-- Notices "commanded to move, but not actually moving" and forces a vertical
-- escape for a short while. Steering alone cannot solve a drone wedged against
-- geometry, because every direction it wants to go is the direction it is stuck
-- against; going up almost always is the answer, and the ceiling check in
-- obstacle.lua prevents that from being suggested under an overhang.
local function UpdateStuckEscape(drone, coords, commandedSpeed, now, sense)
    local cfg = Config.ObstacleAvoidance
    local s = drone.stuck
    if not s then
        s = { since = nil, escapeUntil = 0, lastPos = nil, lastCheck = 0, escapeDir = nil }
        drone.stuck = s
    end

    if now < s.escapeUntil then
        return s.escapeDir
    end

    if now - s.lastCheck < cfg.stuckCheckInterval then return nil end
    local elapsed = (now - s.lastCheck) / 1000.0
    s.lastCheck = now

    local prev = s.lastPos
    s.lastPos = coords
    if not prev or elapsed <= 0.0 then return nil end

    local actualSpeed = Utils.Vdist(coords, prev) / elapsed
    local tryingToMove = commandedSpeed > cfg.stuckSpeed

    if tryingToMove and actualSpeed < cfg.stuckSpeed then
        s.since = s.since or now
        if now - s.since >= cfg.stuckTime then
            s.since = nil
            s.escapeUntil = now + cfg.stuckDuration
            -- A random lateral kick so two drones wedged in the same corner
            -- don't pick identical escapes and stay locked together, plus a
            -- vertical component -- upward normally, but DOWNWARD if the drone
            -- is under an overhang, or the escape just jams it into the roof.
            local a = math.random() * math.pi * 2.0
            local roomAbove = (sense and sense.ceilingClear or math.huge) >= cfg.ceilingClearance
            local vertical = roomAbove and 1.0 or -0.6
            s.escapeDir = Utils.Normalize(vector3(math.cos(a) * 0.45, math.sin(a) * 0.45, vertical))
            if Config.Debug then
                print(('[combat_drone] drone %s stuck -- forcing vertical escape'):format(tostring(drone.ped)))
            end
            return s.escapeDir
        end
    else
        s.since = nil
    end

    return nil
end

-- =============================================================================
-- SEEK
-- =============================================================================

-- Steers the drone toward `desiredPos` this tick. `speedFactor` (0-1) scales
-- max speed (e.g. slower cruise during patrol vs full speed in combat).
-- Returns the distance remaining to the destination.
function Movement.SeekPosition(drone, desiredPos, dt, speedFactor)
    speedFactor = speedFactor or 1.0
    local ent = Utils.Flyer(drone)
    if not DoesEntityExist(ent) then return 0.0 end

    local coords = GetEntityCoords(ent)
    local now = GetGameTimer()

    desiredPos = Movement.SanitizeDestination(drone, desiredPos)

    local toDesired = desiredPos - coords
    local dist = #toDesired
    local dir = dist > 0.01 and (toDesired / dist) or ZERO

    local currentSpeed = #drone.velocity
    local sense = Obstacle.Update(drone, dir, math.max(currentSpeed, Config.Movement.maxSpeed * speedFactor * 0.5))

    local maxSpeed = Config.Movement.maxSpeed * speedFactor * sense.brake
    -- Slow down as it approaches the destination so it doesn't overshoot/oscillate.
    local desiredSpeed = math.min(maxSpeed, dist * 1.5)
    local desiredVel = dir * desiredSpeed

    desiredVel = desiredVel + sense.avoid * Config.ObstacleAvoidance.avoidanceStrength

    local escapeDir = UpdateStuckEscape(drone, coords, desiredSpeed, now, sense)
    if escapeDir then
        -- The escape replaces the seek (whatever we were flying toward is what
        -- got us wedged) but keeps avoidance, so it still steers off surfaces on
        -- the way out.
        desiredVel = escapeDir * Config.Movement.maxSpeed * 0.8
            + sense.avoid * Config.ObstacleAvoidance.avoidanceStrength
    end

    local velDiff = desiredVel - drone.velocity
    local diffLen = #velDiff
    if diffLen > 0.001 then
        local accelDir = velDiff / diffLen
        -- Braking is intentionally allowed to be sharper than accelerating: the
        -- drone needs to be able to shed speed faster than it gained it when
        -- something appears in front of it.
        local rate = (#desiredVel > currentSpeed) and Config.Movement.acceleration or Config.Movement.deceleration
        if sense.blocked and #desiredVel < currentSpeed then
            rate = rate * Config.ObstacleAvoidance.emergencyDecelMultiplier
        end
        local step = math.min(diffLen, rate * dt)
        drone.velocity = drone.velocity + accelDir * step
    end

    -- Hard guarantee: never command velocity into a surface we're already on
    -- top of, whatever the steering maths above decided.
    if sense.blockNormal then
        drone.velocity = CancelIntoSurface(drone.velocity, sense.blockNormal)
    end

    -- The avoidance blend can legitimately exceed the braked speed cap (getting
    -- away from a wall matters more than the speed limit), so clamp to the
    -- unbraked maximum rather than the braked one.
    local hardMax = Config.Movement.maxSpeed * math.max(speedFactor, 0.6)
    if #drone.velocity > hardMax then
        drone.velocity = Utils.Normalize(drone.velocity) * hardMax
    end

    local newPos = coords + drone.velocity * dt
    newPos = ClampAltitude(newPos, sense.surfaceZ)

    if IsEntityAVehicle(ent) then
        -- Drive vehicles with velocity instead of teleporting them: physics
        -- responds properly, it looks like flight rather than stuttering, and
        -- crucially it does NOT wipe the pilot's shoot task the way a
        -- per-frame SetEntityCoords does.
        local delta = newPos - coords
        local step = math.max(dt, 0.001)
        SetEntityVelocity(ent, delta.x / step, delta.y / step, delta.z / step)
    else
        SetEntityCoordsNoOffset(ent, newPos.x, newPos.y, newPos.z, true, true, true)
    end

    return dist
end

-- =============================================================================
-- FACING
-- =============================================================================

-- Smoothly rotate heading toward a world point (used to face a combat target).
function Movement.FacePoint(drone, point, dt)
    local ent = Utils.Flyer(drone)
    local coords = GetEntityCoords(ent)
    local dx, dy = point.x - coords.x, point.y - coords.y
    if dx == 0 and dy == 0 then return end
    local targetHeading = math.deg(math.atan(dy, dx)) - 90.0
    if targetHeading < 0 then targetHeading = targetHeading + 360.0 end

    local current = GetEntityHeading(ent)
    local diff = (targetHeading - current + 540.0) % 360.0 - 180.0
    local maxStep = Config.Movement.turnRateDegPerSec * dt
    local step = Utils.Clamp(diff, -maxStep, maxStep)
    local newHeading = (current + step) % 360.0

    if IsEntityAVehicle(ent) and Config.Piloted.keepLevel then
        -- Pin pitch/roll at zero: an airborne vehicle being steered by velocity
        -- has nothing stopping it from tumbling, and a hovering drone should
        -- stay flat.
        SetEntityRotation(ent, 0.0, 0.0, newHeading, 2, true)
    else
        SetEntityHeading(ent, newHeading)
    end
end

-- Heading follows current velocity direction (used outside combat).
function Movement.FaceVelocity(drone, dt)
    if #drone.velocity < 0.3 then return end
    local coords = GetEntityCoords(Utils.Flyer(drone))
    Movement.FacePoint(drone, coords + drone.velocity, dt)
end

-- Turns the drone to face a fixed compass heading.
--
-- Needed for station keeping: FaceVelocity gives up below 0.3 m/s, so a drone
-- hovering on its post has nothing to orient it and keeps whatever facing it
-- happened to arrive with. Reuses FacePoint by projecting a target a short way
-- out along the heading, so the same turn-rate smoothing applies.
---@param heading number degrees
function Movement.FaceHeading(drone, heading, dt)
    local rad = math.rad(heading)
    local coords = GetEntityCoords(Utils.Flyer(drone))
    -- GTA headings are clockwise from north (+Y), hence -sin for x.
    local ahead = vector3(coords.x - math.sin(rad) * 20.0,
                          coords.y + math.cos(rad) * 20.0,
                          coords.z)
    Movement.FacePoint(drone, ahead, dt)
end

-- Point on a horizontal circle of `radius` around `center`, advancing by
-- `angularSpeed` rad/s, tracked via drone.orbitAngle.
function Movement.GetOrbitPoint(drone, center, radius, angularSpeed, dt)
    drone.orbitAngle = (drone.orbitAngle or 0.0) + angularSpeed * dt
    local x = center.x + math.cos(drone.orbitAngle) * radius
    local y = center.y + math.sin(drone.orbitAngle) * radius
    return vector3(x, y, center.z)
end
