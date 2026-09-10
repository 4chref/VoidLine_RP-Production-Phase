-- =============================================================================
-- combat_drone / client/obstacle.lua
--
-- Spatial awareness for the flight controller. Everything here answers one
-- question: "given where the drone is and where it wants to go, what is in the
-- way and what should it do about it?"
--
-- WHY THIS IS NOT JUST A FORWARD RAYCAST
-- The original version fired one thin ray straight ahead and added a weak
-- steering nudge if it hit something. That fails in the three ways drones
-- actually crash:
--   1. A hairline ray fits through gaps the hull does not, so the drone would
--      steer "clear" straight into a wall corner. Every probe here is a CAPSULE
--      sized to the model's real width (Obstacle.HullRadius).
--   2. Probing a fixed 12m ahead is far too short when closing at 9m/s with
--      only 4m/s^2 of deceleration -- physically it cannot stop in time. The
--      look-ahead now scales with speed, and a brake factor slows the drone
--      down *before* it needs to turn.
--   3. The drone only looked where it was going, never where it was ABOUT to
--      go, so every reposition/orbit turn was flown blind into whatever the new
--      heading pointed at. Both directions are probed now.
--
-- Results are cached per drone and refreshed on Config.ObstacleAvoidance
-- .updateInterval rather than every frame: shape tests are the single most
-- expensive thing this resource does, and at 100ms a 9m/s drone has moved 0.9m,
-- which is nothing against a 5m emergency margin.
-- =============================================================================

Obstacle = {}

local RAYCAST_FLAGS = 1 + 2 + 16 -- world map + vehicles + objects (buildings/walls/trees/vehicles/props)

local ZERO = vector3(0.0, 0.0, 0.0)
local UP = vector3(0.0, 0.0, 1.0)

-- =============================================================================
-- HULL SIZE
-- =============================================================================

local hullRadiusCache = {}

-- Half the model's widest horizontal dimension, plus padding. This is what
-- turns "is there a line of sight" into "can this thing physically fit".
function Obstacle.HullRadius(ent)
    local model = GetEntityModel(ent)
    local r = hullRadiusCache[model]
    if not r then
        local mn, mx = GetModelDimensions(model)
        if mn and mx then
            r = math.max(math.abs(mx.x - mn.x), math.abs(mx.y - mn.y)) * 0.5
        end
        if not r or r <= 0.1 then r = 1.5 end -- model not streamed yet: assume something drone-sized
        hullRadiusCache[model] = r
    end
    return r + Config.ObstacleAvoidance.hullPadding
end

-- =============================================================================
-- PROBES
-- =============================================================================

-- Height of whatever is directly beneath a point: terrain OR a rooftop, ledge or
-- bridge deck. GetGroundZFor_3dCoord only knows about the map's *ground*, so a
-- drone crossing a tower block believed it had 60m of clearance while the roof
-- was 2m under it -- that single blind spot caused most of the rooftop crashes.
function Obstacle.SurfaceZ(pos, ignoreEnt)
    local groundZ = Utils.GetGroundZ(pos)
    local hit, coords = Utils.RaycastPoint(
        vector3(pos.x, pos.y, pos.z),
        vector3(pos.x, pos.y, pos.z - Config.ObstacleAvoidance.surfaceProbeDepth),
        ignoreEnt, RAYCAST_FLAGS
    )
    if hit and coords then return math.max(coords.z, groundZ) end
    return groundZ
end

-- Is the straight line from `from` to `to` flyable by a body of `radius`?
-- Used to decide whether a destination is reachable before committing to it.
function Obstacle.IsPathClear(from, to, ignoreEntity, radius)
    if radius and radius > 0 then
        local hit = Utils.CapsuleCast(from, to, radius, ignoreEntity, RAYCAST_FLAGS)
        return not hit
    end
    local hit = Utils.RaycastPoint(from, to, ignoreEntity, RAYCAST_FLAGS)
    return not hit
end

-- =============================================================================
-- SENSING
-- =============================================================================

local function EmptySense()
    return {
        avoid = ZERO,
        blocked = false,
        brake = 1.0,
        nearest = math.huge,
        blockNormal = nil,
        surfaceZ = nil,
        ceilingClear = math.huge,
        nextUpdateAt = 0,
    }
end

function Obstacle.Init(drone)
    drone.sense = EmptySense()
end

-- Picks the most flyable direction out of a fan of candidates, trading off
-- "how far can I actually get that way" against "how close is that to where I
-- wanted to go". Climbing gets a deliberate bonus: over a city, up is almost
-- always the way out, and it never risks flying into a pedestrian or a car.
-- The fan of candidate directions is fixed by config, so build it once instead
-- of recomputing probeCount * #probePitches sin/cos pairs on every search.
local escapeFan = nil

local function EscapeFan()
    if escapeFan then return escapeFan end

    local cfg = Config.ObstacleAvoidance
    local count = math.max(cfg.probeCount, 4)
    escapeFan = {}

    for i = 0, count - 1 do
        local yaw = (i / count) * math.pi * 2.0
        for _, pitch in ipairs(cfg.probePitches) do
            local cp = math.cos(pitch)
            escapeFan[#escapeFan + 1] =
                Utils.Normalize(vector3(math.cos(yaw) * cp, math.sin(yaw) * cp, math.sin(pitch)))
        end
    end

    return escapeFan
end

-- PERF: this used to sweep the fan one direction at a time, and every single
-- sweep blocked on its own shape test result -- 24 tests serialised, each able
-- to cost several frames. The whole fan is now fired in one batch and read back
-- together, which is what the engine wants and is where most of this resource's
-- CPU time went while drones were manoeuvring near geometry.
local function FindEscapeDirection(origin, desiredDir, look, radius, ignoreEnt)
    local cfg = Config.ObstacleAvoidance
    local fan = EscapeFan()

    local casts = {}
    for i = 1, #fan do
        casts[i] = { from = origin, to = origin + fan[i] * look, radius = radius }
    end

    local results = Utils.BatchCapsuleCast(casts, ignoreEnt, RAYCAST_FLAGS)

    local best, bestScore = nil, -math.huge
    for i = 1, #fan do
        local cand = fan[i]
        local r = results[i]

        -- "How far can I actually get this way": the hit distance when
        -- something was in the way, the full probe length when nothing was.
        -- A capsule that starts already overlapping reports ~0, which is
        -- "touching", not a valid clear distance -- hence the clamp at 0.
        local clear = look
        if r[1] and r[2] ~= nil then
            clear = math.min(math.max(Utils.Vdist(origin, r[2]), 0.0), look)
        end

        local align = Utils.Dot(cand, desiredDir)          -- -1 .. 1
        local score = clear
            + align * look * cfg.headingBias
            + (cand.z > 0.0 and cand.z * look * cfg.climbBias or 0.0)

        if score > bestScore then
            bestScore = score
            best = cand
        end
    end

    return best, bestScore
end

-- Refreshes (on cadence) and returns the drone's obstacle picture:
--   avoid       steering vector to blend into the desired velocity
--   blocked     true if anything is inside the look-ahead
--   brake       0..1 multiplier on max speed
--   nearest     distance to the closest thing ahead
--   blockNormal surface normal of the closest thing ahead (for wall sliding)
--   surfaceZ    height of the ground/roof directly below
function Obstacle.Update(drone, desiredDir, speed)
    local sense = drone.sense
    if not sense then
        sense = EmptySense()
        drone.sense = sense
    end

    local now = GetGameTimer()
    if now < sense.nextUpdateAt then return sense end
    sense.nextUpdateAt = now + Config.ObstacleAvoidance.updateInterval

    local cfg = Config.ObstacleAvoidance
    local ent = Utils.Flyer(drone)
    if not DoesEntityExist(ent) then return sense end

    local origin = GetEntityCoords(ent)
    local radius = Obstacle.HullRadius(ent)

    sense.surfaceZ = Obstacle.SurfaceZ(origin, ent)

    local travelDir = Utils.Normalize(drone.velocity or ZERO)
    if #travelDir < 0.01 then travelDir = desiredDir end
    if #travelDir < 0.01 then travelDir = GetEntityForwardVector(ent) end

    -- Stopping distance plus a reaction margin. Below maxSpeed this shortens,
    -- so a slow-moving drone isn't spooked by scenery it will never reach.
    local look = Utils.Clamp(speed * cfg.lookaheadTime, cfg.minLookahead, cfg.checkDistance)

    local avoid = ZERO
    local nearest = math.huge
    local nearestNormal = nil
    local blocked = false

    -- Probe both where we are going and where we want to go. During a
    -- reposition those differ by up to 180 degrees, and only checking one of
    -- them is how the drone used to turn straight into a wall.
    local dirs = { travelDir }
    if #desiredDir > 0.01 and Utils.Dot(desiredDir, travelDir) < 0.985 then
        dirs[#dirs + 1] = desiredDir
    end

    -- PERF: the directional sweeps and the ceiling probe are independent, so
    -- they go out as one batch rather than blocking on each other in turn.
    local casts = {}
    for i = 1, #dirs do
        casts[i] = { from = origin, to = origin + dirs[i] * look, radius = radius }
    end
    casts[#casts + 1] = { from = origin, to = origin + UP * cfg.ceilingClearance, radius = radius }

    local probes = Utils.BatchCapsuleCast(casts, ent, RAYCAST_FLAGS)

    for i, d in ipairs(dirs) do
        local r = probes[i]
        -- A reported hit with no coordinates carries no usable distance, so it
        -- counts as clear -- same as the old single-sweep path did.
        local hit = r[1] and r[2] ~= nil
        local normal = r[3]
        local clear = look
        if hit then
            -- A capsule that starts already overlapping reports ~0, which is
            -- "touching", not a valid clear distance -- hence the clamp at 0.
            clear = math.min(math.max(Utils.Vdist(origin, r[2]), 0.0), look)
        end
        if hit then
            blocked = true
            if clear < nearest then
                nearest = clear
                nearestNormal = normal
            end

            local urgency = Utils.Clamp(1.0 - (clear / look), 0.0, 1.0)
            local n = normal and Utils.Normalize(normal) or ZERO
            if #n < 0.01 then n = -d end

            -- Two components: push straight off the surface, and slide along it
            -- (the travel direction with its into-the-wall part removed). The
            -- slide is what makes the drone skirt a building instead of
            -- bouncing off it and immediately re-approaching.
            local along = ZERO
            if cfg.wallSlide then
                along = Utils.Normalize(d - n * Utils.Dot(d, n))
            end

            avoid = avoid + n * (urgency * cfg.pushWeight) + along * (urgency * cfg.slideWeight)
        end
    end

    -- Something close enough to matter: find the genuinely best way around,
    -- rather than trusting the wall normal to point somewhere useful (an
    -- interior corner's normal aims straight back into the other wall).
    if blocked and nearest < look * cfg.escapeSearchFraction then
        local escapeDir = FindEscapeDirection(origin, desiredDir, look, radius, ent)
        if escapeDir then
            local urgency = Utils.Clamp(1.0 - (nearest / look), 0.0, 1.0)
            avoid = avoid + escapeDir * (urgency * cfg.escapeWeight)
        end
    end

    -- Ceiling check, run unconditionally so the answer is always available.
    -- Climbing is the fallback escape everywhere in this system -- the fan
    -- search prefers it, and the stuck detector forces it -- so "is there
    -- actually room above" has to be known even when nothing is blocking
    -- horizontally, or a drone wedged under an awning escapes into the awning.
    -- Its probe was fired with the directional sweeps above; read it back here.
    local ceilingProbe = probes[#dirs + 1]
    local ceilingClear = cfg.ceilingClearance
    if ceilingProbe[1] and ceilingProbe[2] ~= nil then
        ceilingClear = math.min(math.max(Utils.Vdist(origin, ceilingProbe[2]), 0.0), cfg.ceilingClearance)
    end
    sense.ceilingClear = ceilingClear

    if avoid.z > 0.0 and ceilingClear < cfg.ceilingClearance then
        avoid = vector3(avoid.x, avoid.y, math.min(avoid.z, 0.0) - 0.2)
    end

    -- Brake profile: full speed while the nearest obstacle is beyond the
    -- look-ahead, easing to minBrakeFactor as it closes to the emergency
    -- distance. Turning while still doing 9m/s is what actually produced the
    -- collisions -- the steering was fine, the speed was not.
    local brake = 1.0
    if blocked then
        local span = math.max(look - cfg.emergencyDistance, 0.5)
        local t = Utils.Clamp((nearest - cfg.emergencyDistance) / span, 0.0, 1.0)
        brake = Utils.Lerp(cfg.minBrakeFactor, 1.0, t)
    end

    sense.avoid = avoid
    sense.blocked = blocked
    sense.brake = brake
    sense.nearest = nearest
    sense.blockNormal = (nearest <= cfg.emergencyDistance) and nearestNormal or nil

    return sense
end
