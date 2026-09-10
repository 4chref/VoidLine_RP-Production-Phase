-- VoidLine: bunker hallway laser grid, spanning the corridor between
-- (3122.3640, 5409.7617, 23.5893) and (3137.3428, 5384.3853, 26.1472).
--
-- Recreates the actual Kortz Center Heist vault laser grid MECHANIC (GTA
-- Online, Title Update 1.73, July 2026) rather than its exact visual asset
-- -- that DLC releases after both my own knowledge cutoff and the last
-- update of the community particle-effects dump this file's earlier
-- attempts relied on, so there's no way to verify a real asset name for it
-- without guessing (and a wrong ptfx name just silently renders nothing).
-- Per player-facing guides for it:
--
--   - Lasers move in small synced groups (2-3 together), not independently.
--   - One single laser moves on its own, randomly, separate from the groups.
--   - 3 wall panels, each permanently deactivates the laser section you just
--     passed once interacted with -- a ratcheting safety net, not a toggle.
--
-- Visual is kq_lasers's own native line (no ptfx) -- a ptfx-overlay attempt
-- was tried here and reverted: SetOpacity(0.0) did not actually hide the
-- native line as the docs implied, so the result was the solid line PLUS a
-- dashed particle chain on top of it, worse than either alone.
--
-- Ground height is probed per point with GetGroundZFor_3dCoord rather than
-- trusting the given path z -- an earlier version's beams floated above the
-- floor because the given coordinates aren't exactly floor level.
--
-- VoidLine 2026-08-31: this used to build all 28 beams (3 fences x 9 + 1
-- roamer) unconditionally at resource start, for every player, forever --
-- and 6 of those beams (the "moving" pair per fence) fully deleted and
-- recreated their laser object every 50ms nonstop. That's 120 laser
-- create/destroy calls a second, 24/7, whether or not anyone was anywhere
-- near the bunker -- a very plausible cause of the periodic freezes/FPS
-- drops reported after this resource was added. The whole system is now
-- gated behind two live conditions and only exists (built once) or churns
-- (the sweep) while BOTH are true:
--   1. GlobalState.blackout.active -- a blackout is happening
--   2. the bunker exit door is unlocked ("open"), read from ox_doorlock via
--      main/server/bunker_door.lua
-- The moment either drops, every laser and target zone this file owns is
-- torn down immediately -- back to zero cost, same as the resource not
-- being there at all.

local PATH_START = vector3(3122.3640, 5409.7617, 23.5893)
local PATH_END   = vector3(3137.3428, 5384.3853, 26.1472)

local HALF_WIDTH = 3.2       -- fence spans this far each side of centre -- wall to wall
local BEAMS_PER_FENCE = 9    -- parallel vertical lines making up one fence
local CEILING_HEIGHT = 3.4   -- each beam: floor to the ceiling -- was 2.6, fell short
local FLOOR_OFFSET = 0.05    -- start just above the floor, not clipped into it

local GROUP_SLIDE_RANGE = 0.7    -- how far a synced-pair beam swings from its home slot
-- Continuous sine sweep instead of a two-position jump: many small position
-- updates rather than one big teleport, so the motion actually reads as a
-- smooth glide. Each beam is a single line now, so this can run fast.
local GROUP_SWEEP_STEP_MS = 50
local GROUP_SWEEP_SPEED = 0.12   -- radians added to phase per step -- lower = slower full cycle

local ROAMER_INTERVAL_MIN_MS = 800
local ROAMER_INTERVAL_MAX_MS = 2200

local delta = PATH_END - PATH_START
local horizDelta = vector3(delta.x, delta.y, 0.0)
local horizLen = #horizDelta

-- Horizontal vector perpendicular to the hallway's direction of travel --
-- i.e. across its width, which is what "one beam per lateral offset" walks
-- along to build a fence.
local perp = vector3(-horizDelta.y / horizLen, horizDelta.x / horizLen, 0.0)
local up = vector3(0.0, 0.0, 1.0)

---@param t number 0-1 fraction along the hallway
local function pointOnPath(t)
    return PATH_START + delta * t
end

-- Finds the actual ground height at a point instead of trusting the given
-- path z. Requests collision there first and gives it a moment to stream in
-- -- without that, GetGroundZFor_3dCoord can fail simply because the map
-- hasn't loaded around a point nobody is standing near yet.
---@param point vector3
---@return number groundZ
local function groundZAt(point)
    RequestCollisionAtCoord(point.x, point.y, point.z)

    local tries = 0
    local found, groundZ = false, point.z
    while not found and tries < 40 do
        Wait(50)
        found, groundZ = GetGroundZFor_3dCoord(point.x, point.y, point.z + 10.0, false)
        tries = tries + 1
    end

    -- Fall back to the raw path z if the probe never resolves, so the fence
    -- still gets created (just possibly off) instead of silently vanishing.
    return found and groundZ or point.z
end

local function bunkerTrigger()
    return {
        {
            event = 'kq_lasers:dispatch:client:trigger',
            type = 'client',
            parameters = {
                title = 'Bunker hallway laser tripped!',
                message = 'A security laser in the bunker hallway has been tripped.',
                jobs = { 'police' },
            },
        },
    }
end

local function laserData(origin, endPoint)
    return {
        origin = origin,
        endPoint = endPoint,
        maxLength = 4.0,
        damage = 15,
        ragdoll = true,
        cooldown = 3000,
        triggers = bunkerTrigger(),
    }
end

-- A single floor-to-ceiling beam at `groundPoint`, shifted `lateralOffset`
-- metres sideways.
local function fenceBeam(groundPoint, lateralOffset)
    local base = groundPoint + perp * lateralOffset
    return base + up * FLOOR_OFFSET, base + up * CEILING_HEIGHT
end

-- One single line per beam -- the multi-line "thick band" simulation was
-- too many lines stacked in one spot and looked cluttered rather than
-- solid. Returns an array (of one) so call sites don't need two code paths.
local function createThickBeam(name, groundPoint, lateralOffset)
    local o, e = fenceBeam(groundPoint, lateralOffset)
    return { exports['vl_lasers']:CreateLaser(name, laserData(o, e)) }
end

-- ─── activation gate ────────────────────────────────────────────────────────

local blackoutActive = false
local bunkerDoorId = nil
local bunkerDoorOpen = false
local systemActive = false
local sweepThreadsRunning = false -- flag the moving-beam/roamer threads poll to know when to stop

local fencePositions = { 0.2, 0.5, 0.8 }
local fenceGroundPoints = nil -- computed once on first activation, reused after
local fenceLasers = {}        -- fenceLasers[fenceIndex] = { laser, laser, ... }
local roamerLasers = {}
local panelZones = {}

local function deleteAll(list)
    for i = 1, #list do
        local laser = list[i]
        if laser and laser.Delete then laser.Delete() end
    end
end

local function stopSystem()
    if not systemActive then return end
    systemActive = false
    sweepThreadsRunning = false -- the moving-beam and roamer threads see this and exit on their next tick

    for f = 1, #fencePositions do
        deleteAll(fenceLasers[f] or {})
        fenceLasers[f] = {}
    end
    deleteAll(roamerLasers)
    roamerLasers = {}

    for i = 1, #panelZones do
        exports.ox_target:removeZone(panelZones[i])
    end
    panelZones = {}
end

local function startSystem()
    if systemActive then return end
    systemActive = true
    sweepThreadsRunning = true

    -- Ground points only need probing once -- the hallway geometry never
    -- changes, so cache them across activations instead of re-probing
    -- (up to 2s per point) every single time a blackout starts.
    if not fenceGroundPoints then
        fenceGroundPoints = {}
        for f, t in ipairs(fencePositions) do
            local rawPoint = pointOnPath(t)
            fenceGroundPoints[f] = vector3(rawPoint.x, rawPoint.y, groundZAt(rawPoint))
        end
    end

    -- Three fences, spaced out along the hallway -- 3 wall panels below map
    -- one-to-one onto these.
    for f, t in ipairs(fencePositions) do
        fenceLasers[f] = {}
        local groundPoint = fenceGroundPoints[f]

        -- Beams 4 and 6 (of 9) are this fence's synced-moving pair -- near
        -- the centre, so their swing range doesn't need clamping against
        -- the fence's own edges.
        local movingSlots = { [4] = true, [6] = true }

        for b = 1, BEAMS_PER_FENCE do
            -- Evenly spaced from -HALF_WIDTH to +HALF_WIDTH.
            local homeOffset = -HALF_WIDTH + (2 * HALF_WIDTH) * (b - 1) / (BEAMS_PER_FENCE - 1)

            if movingSlots[b] then
                local name = ('bunker_hallway_fence_%d_%d'):format(f, b)
                CreateThread(function()
                    -- Randomised start phase so this fence's two moving
                    -- beams (and other fences' moving beams) don't swing in
                    -- lockstep.
                    local phase = math.random() * 2 * math.pi
                    local current = createThickBeam(name, groundPoint, homeOffset)
                    for _, laser in ipairs(current) do fenceLasers[f][#fenceLasers[f] + 1] = laser end

                    while sweepThreadsRunning do
                        Wait(GROUP_SWEEP_STEP_MS)
                        if not sweepThreadsRunning then break end
                        phase = phase + GROUP_SWEEP_SPEED
                        local offset = homeOffset + GROUP_SLIDE_RANGE * math.sin(phase)
                        for _, laser in ipairs(current) do
                            if laser and laser.Delete then laser.Delete() end
                        end
                        current = createThickBeam(name, groundPoint, offset)
                        for _, laser in ipairs(current) do fenceLasers[f][#fenceLasers[f] + 1] = laser end
                    end
                end)
            else
                local created = createThickBeam(('bunker_hallway_fence_%d_%d'):format(f, b), groundPoint, homeOffset)
                for _, laser in ipairs(created) do fenceLasers[f][#fenceLasers[f] + 1] = laser end
            end
        end
    end

    -- One single laser, independent of the fences, that roams randomly
    -- along the hallway and across its width on its own irregular timer.
    CreateThread(function()
        while sweepThreadsRunning do
            local t = 0.3 + math.random() * 0.4 -- stays within the fenced stretch
            local lateralOffset = -HALF_WIDTH + math.random() * (2 * HALF_WIDTH)
            local rawPoint = pointOnPath(t)
            local groundPoint = vector3(rawPoint.x, rawPoint.y, groundZAt(rawPoint))

            if not sweepThreadsRunning then break end

            deleteAll(roamerLasers)
            roamerLasers = createThickBeam('bunker_hallway_roamer', groundPoint, lateralOffset)

            Wait(math.random(ROAMER_INTERVAL_MIN_MS, ROAMER_INTERVAL_MAX_MS))
        end
    end)

    -- Three wall panels, one per fence. Interacting with panel N permanently
    -- deactivates every laser in fence N -- SetActive(false), a documented
    -- kq_lasers laser method -- matching "each panel deactivates the lasers
    -- you just passed".
    for f, t in ipairs(fencePositions) do
        local groundPoint = fenceGroundPoints[f]
        -- Set back against a wall, just past the fence so reaching it means
        -- you've already crossed that section. Side picked at random per
        -- panel, same as the real heist not fixing them to one wall.
        local wallSide = math.random(0, 1) == 1 and 1 or -1
        local panelCoords = groundPoint + perp * (HALF_WIDTH + 0.3) * wallSide + up * 1.2

        local zoneId = exports.ox_target:addBoxZone({
            coords = vector3(panelCoords.x, panelCoords.y, panelCoords.z),
            size = vector3(0.4, 0.4, 0.6),
            rotation = 0.0,
            debug = false,
            options = {
                {
                    name = ('bunker_hallway_panel_%d'):format(f),
                    icon = 'fa-solid fa-microchip',
                    label = ('Hack Panel %d'):format(f),
                    onSelect = function()
                        for _, laser in ipairs(fenceLasers[f]) do
                            if laser and laser.SetActive then laser.SetActive(false) end
                        end
                        Notify(('Laser section %d deactivated.'):format(f))
                    end,
                },
            },
        })
        panelZones[#panelZones + 1] = zoneId
    end
end

local function evaluateSystem()
    if blackoutActive and bunkerDoorOpen then
        startSystem()
    else
        stopSystem()
    end
end

-- Blackout state: GlobalState.blackout, owned by vl_blackout (see vl_panel).
CreateThread(function()
    blackoutActive = GlobalState.blackout and GlobalState.blackout.active or false
    evaluateSystem()
end)

AddStateBagChangeHandler('blackout', 'global', function(_, _, value)
    blackoutActive = value and value.active or false
    evaluateSystem()
end)

-- Bunker door state: resolved once via ox_doorlock (server-side only lookup,
-- see main/server/bunker_door.lua), then tracked live from ox_doorlock's own
-- state-change event.
CreateThread(function()
    local info = lib.callback.await('vl_lasers:server:getBunkerDoorInfo', false)
    if info then
        bunkerDoorId = info.id
        bunkerDoorOpen = info.open
        evaluateSystem()
    end
end)

RegisterNetEvent('ox_doorlock:setState', function(id, state)
    if bunkerDoorId and id == bunkerDoorId then
        bunkerDoorOpen = (state == 0)
        evaluateSystem()
    end
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    stopSystem()
end)
