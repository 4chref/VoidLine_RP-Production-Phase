-- =============================================================================
-- combat_drone / client/utils.lua
-- Small stateless helpers shared by every subsystem.
-- =============================================================================

Utils = {}

function Utils.Vdist(a, b)
    return #(a - b)
end

function Utils.Vdist2D(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

function Utils.Normalize(v)
    local len = #v
    if len < 0.0001 then return vector3(0.0, 0.0, 0.0) end
    return v / len
end

function Utils.Dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

function Utils.Cross(a, b)
    return vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

function Utils.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Utils.Lerp(a, b, t)
    return a + (b - a) * Utils.Clamp(t, 0.0, 1.0)
end

function Utils.RandomFloat(lo, hi)
    return lo + (hi - lo) * (math.random(0, 10000) / 10000.0)
end

-- Ground Z under a coordinate; falls back to the input Z if the probe fails.
--
-- PERF: this was called several times per frame per drone from the flight tick
-- (IDLE and PATROL both re-derive their hover altitude from it), and
-- GetGroundZFor_3dCoord is not cheap. The result depends only on x/y -- the
-- probe always starts 100m above the query point, so the same column always
-- returns the same answer -- and world geometry does not move, so it is safe to
-- memoise on a 2m grid. A failed probe is never cached: its fallback is the
-- caller's own z, which is not a property of the column.
local groundZCache = {}
local groundZCount = 0
local GROUNDZ_GRID = 2.0
local GROUNDZ_MAX = 4096 -- flush wholesale rather than tracking per-entry age

function Utils.GetGroundZ(coords)
    local key = math.floor(coords.x / GROUNDZ_GRID) .. ':' .. math.floor(coords.y / GROUNDZ_GRID)
    local cached = groundZCache[key]
    if cached then return cached end

    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
    if not found then return coords.z end

    if groundZCount >= GROUNDZ_MAX then
        groundZCache = {}
        groundZCount = 0
    end
    groundZCache[key] = z
    groundZCount = groundZCount + 1
    return z
end

-- Signed angle (degrees) from forward vector `fwd` to the direction toward `point`, on the XY plane.
function Utils.AngleToPointDeg(originCoords, fwd, point)
    local dir = Utils.Normalize(vector3(point.x - originCoords.x, point.y - originCoords.y, 0.0))
    local flatFwd = Utils.Normalize(vector3(fwd.x, fwd.y, 0.0))
    local dot = Utils.Clamp(flatFwd.x * dir.x + flatFwd.y * dir.y, -1.0, 1.0)
    local angle = math.deg(math.acos(dot))
    local cross = flatFwd.x * dir.y - flatFwd.y * dir.x
    if cross < 0 then angle = -angle end
    return angle
end

-- Shape test results aren't always ready the same tick they're started; poll
-- until the async test finishes (retval 0 == still pending) instead of
-- trusting a single immediate read, which can silently return stale/empty data.
local SHAPETEST_GUARD = 10

local function PollShapeTestResult(handle)
    local retval, hit, endCoords, surfaceNormal, entityHit
    local guard = 0
    repeat
        retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
        guard = guard + 1
        if retval == 0 and guard < SHAPETEST_GUARD then Wait(0) end
    until retval ~= 0 or guard >= SHAPETEST_GUARD
    -- GetShapeTestResult hands `hit` back as a Lua BOOLEAN, not 0/1. Comparing
    -- it numerically is always false, which silently made every LOS check fail
    -- and every obstacle probe report "clear". Normalise to a real boolean here
    -- so callers can never reintroduce that bug.
    return hit == true or hit == 1, endCoords, surfaceNormal, entityHit
end

-- Polls a whole batch of already-started shape tests at once.
--
-- PERF: the single most important function in this file. Polling tests ONE AT A
-- TIME means each one can burn up to SHAPETEST_GUARD frames waiting on its own
-- result, and the escape-direction fan fires 24 of them -- so a search that the
-- engine could have answered in one or two frames was instead spread across
-- dozens, with the drone's flight thread pinned the whole time. Started
-- together, they all resolve in parallel and the batch costs about what a
-- single test used to.
--
-- `handles` is an array of handles; returns an array of
-- { hit, endCoords, surfaceNormal, entityHit } in the same order. A test that
-- never resolves within the guard is reported as a clean miss, matching what
-- the single-handle path does.
local function PollShapeTestBatch(handles)
    local n = #handles
    local out = {}
    local pending = n
    local guard = 0

    while pending > 0 and guard < SHAPETEST_GUARD do
        for i = 1, n do
            if not out[i] then
                local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handles[i])
                if retval ~= 0 then
                    out[i] = { hit == true or hit == 1, endCoords, surfaceNormal, entityHit }
                    pending = pending - 1
                end
            end
        end
        guard = guard + 1
        if pending > 0 and guard < SHAPETEST_GUARD then Wait(0) end
    end

    for i = 1, n do
        if not out[i] then out[i] = { false, nil, nil, nil } end
    end
    return out
end

-- Fires a set of capsule sweeps concurrently. `casts` is an array of
-- { from, to, radius }; returns results in the same order and format as
-- PollShapeTestBatch. See the perf note above for why this exists.
function Utils.BatchCapsuleCast(casts, ignoreEntity, flags)
    local handles = {}
    for i = 1, #casts do
        local c = casts[i]
        handles[i] = StartShapeTestCapsule(
            c.from.x, c.from.y, c.from.z,
            c.to.x, c.to.y, c.to.z,
            c.radius, flags or 1, ignoreEntity, 7
        )
    end
    return PollShapeTestBatch(handles)
end

-- World geometry only: map + vehicles + objects. Peds are deliberately NOT
-- included, otherwise the ped being looked at blocks the probe to itself.
local LOS_FLAGS = 1 + 2 + 16

-- Line of sight check between two points, ignoring the given entity.
-- Uses a shape test capsule so thin foliage doesn't create a false "clear" result.
function Utils.HasLineOfSight(fromCoords, toCoords, ignoreEntity)
    local handle = StartShapeTestCapsule(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x, toCoords.y, toCoords.z,
        0.25, LOS_FLAGS, ignoreEntity, 7
    )
    local hit = PollShapeTestResult(handle)
    return not hit
end

-- Line of sight from one entity to another. Preferred over HasLineOfSight for
-- ped targets: the engine handles ignoring both entities itself.
function Utils.HasLineOfSightToEntity(fromEntity, toEntity)
    return HasEntityClearLosToEntity(fromEntity, toEntity, 17)
end

-- Single ray shape test, returns hit(bool), hitCoords, hitEntity
function Utils.RaycastPoint(fromCoords, toCoords, ignoreEntity, flags)
    local handle = StartShapeTestLosProbe(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x, toCoords.y, toCoords.z,
        flags or 1, ignoreEntity, 7
    )
    local hit, endCoords, _, entityHit = PollShapeTestResult(handle)
    return hit, endCoords, entityHit
end

-- Swept-sphere test: the same probe, but with the drone's actual body width.
-- A hairline ray happily threads between a lamp post and a wall that the hull
-- cannot fit through, which is exactly how the drone used to clip scenery; the
-- avoidance system probes with this instead.
--
-- Returns hit(bool), hitCoords, surfaceNormal, hitEntity. The normal is what
-- lets the drone slide ALONG a wall instead of only backing away from it.
function Utils.CapsuleCast(fromCoords, toCoords, radius, ignoreEntity, flags)
    local handle = StartShapeTestCapsule(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x, toCoords.y, toCoords.z,
        radius, flags or 1, ignoreEntity, 7
    )
    return PollShapeTestResult(handle)
end

function Utils.DrawText3D(coords, text, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(r or 255, g or 255, b or 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(sx, sy)
end

-- Nearby player peds (excluding the local player unless includeSelf) within radius, alive only.
function Utils.GetNearbyPlayerPeds(coords, radius, includeSelf)
    local result = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
            if includeSelf or ped ~= PlayerPedId() then
                local d = Utils.Vdist(coords, GetEntityCoords(ped))
                if d <= radius then
                    result[#result + 1] = { ped = ped, playerId = playerId, distance = d }
                end
            end
        end
    end
    return result
end

-- Is this drone flown as a piloted vehicle (rather than as a flying ped)?
function Utils.IsPiloted(drone)
    return Config.FlightMode == 'piloted'
        and drone.vehicle ~= nil
        and drone.vehicle ~= 0
        and DoesEntityExist(drone.vehicle)
end

-- The entity that actually moves through the world: the vehicle when piloted,
-- otherwise the ped itself. Everything positional (movement, detection, debug)
-- must go through this rather than assuming drone.ped.
function Utils.Flyer(drone)
    if Utils.IsPiloted(drone) then return drone.vehicle end
    return drone.ped
end

-- Server id of the player behind this ped, or nil for NPCs. Warnings are
-- addressed by server id because they have to be delivered to a machine other
-- than the one simulating the drone.
function Utils.ServerIdFromPed(ped)
    if not ped or ped == 0 or not IsPedAPlayer(ped) then return nil end
    local playerIdx = NetworkGetPlayerIndexFromPed(ped)
    if not playerIdx or playerIdx == -1 then return nil end
    local serverId = GetPlayerServerId(playerIdx)
    if not serverId or serverId <= 0 then return nil end
    return serverId
end

function Utils.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
