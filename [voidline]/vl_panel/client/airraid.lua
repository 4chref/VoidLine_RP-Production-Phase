-- =============================================================================
-- vl_airraid -- client
--
-- Three independent jobs, kept separate on purpose:
--   1. Track GlobalState.airraid ({active, startedAt, delays}) and tell the
--      NUI to start/stop. `delays` is the server-rolled cascade order --
--      sirens start randomly one by one rather than all at once, see
--      server/main.lua's rollCascade() -- and `startedAt` phase-locks each
--      site's loop to when IT actually began, so walking up to a site that
--      kicked in ten seconds ago sounds like catching it already mid-wail,
--      not triggering a fresh one.
--   2. While active, stream each in-range site's position in LISTENER SPACE
--      (x = right, y = up, z = behind the camera) so the NUI's Web Audio
--      listener never has to move -- it sits at the origin with the default
--      orientation, and the sites move around it. Mathematically identical to
--      moving/rotating the listener, and far cheaper: three numbers per site,
--      no AudioListener.orientation calls, no version-dependent Web Audio API
--      surface to depend on. Lifted from vl_combat_drone/client/audio.lua,
--      which already proved this exact technique out in this server for the
--      drone siren -- this is the same architecture, not a parallel one.
--   3. While active, keep one flashing radius blip per site on the map.
--
-- All the actual audio -- panning, distance falloff, the fade envelope -- is
-- Web Audio API work and lives in html/app.js. This file's job is only ever
-- "when" and "where", never "how it sounds".
-- =============================================================================

local active = false
local blips = {}
local playing = {} -- site index -> true while that site currently has a voice

-- How many seconds the raid had already been running, as of a known LOCAL
-- GetGameTimer() reading. Together these let any later moment's "elapsed"
-- be derived (raidBaseElapsed + (GetGameTimer() - raidBaseGameTimer) / 1000)
-- without ever touching os.time() client-side -- see start()'s comment for why.
local raidBaseElapsed = 0
local raidBaseGameTimer = 0

-- site index -> seconds after raidBaseElapsed that site is due to start
-- cascading in ("sirens start randomly one by one"). Read once from
-- GlobalState.airraid.delays in start() -- server-rolled and replicated, see
-- server/main.lua's rollCascade(), so every client uses the identical
-- schedule rather than each picking its own random order.
local siteDelays = {}

-- =============================================================================
-- STATE
-- =============================================================================

---@return boolean
local function isActive()
    local s = GlobalState.airraid
    return s ~= nil and s.active == true
end

-- =============================================================================
-- ZONE BLIP
--
-- ONE blip covering the whole siren zone, not one per site -- see
-- config.lua's VLAirRaid.zoneBlip for why. AddBlipForRadius only draws a
-- circle, so it is auto-fitted from VLAirRaid.zone.polygon: centred on the
-- average of its vertices, radius reaching the farthest one. Computed ONCE at
-- load -- the polygon is static config, never anything that changes at
-- runtime -- not recomputed every time the blip is (re)created.
-- =============================================================================

---@return number cx, number cy, number cz, number radius
local function fitZoneCircle()
    local poly = VLAirRaid.zone.polygon
    local cx, cy = 0.0, 0.0
    for _, p in ipairs(poly) do cx = cx + p.x; cy = cy + p.y end
    cx, cy = cx / #poly, cy / #poly

    local radius = 0.0
    for _, p in ipairs(poly) do
        local d = math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
        if d > radius then radius = d end
    end

    -- Blips don't really care about elevation the way a radius blip's
    -- footprint does, but AddBlipForRadius still wants a Z -- the average
    -- across all sites is as reasonable a "ground level" as any single guess.
    local cz = 0.0
    for _, site in ipairs(VLAirRaid.sites) do cz = cz + site.z end
    cz = cz / #VLAirRaid.sites

    return cx, cy, cz, radius
end

local ZONE_CX, ZONE_CY, ZONE_CZ, ZONE_RADIUS = fitZoneCircle()

local function createBlips()
    if #blips > 0 then return end

    local cfg = VLAirRaid.zoneBlip
    local blip = AddBlipForRadius(ZONE_CX, ZONE_CY, ZONE_CZ, ZONE_RADIUS)

    SetBlipDisplay(blip, cfg.display)
    SetBlipColour(blip, cfg.colour)
    SetBlipAlpha(blip, cfg.alpha)
    SetBlipFlashes(blip, true)

    -- Not every game build exposes this one; a missing flash interval just
    -- means the default rate, not a broken blip.
    if type(SetBlipFlashInterval) == 'function' then
        SetBlipFlashInterval(blip, cfg.flashIntervalMs)
    end

    blips[#blips + 1] = blip
end

local function removeBlips()
    for _, blip in ipairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}
end

-- =============================================================================
-- CAMERA BASIS
-- =============================================================================

---@return vector3 camPos, vector3 forward, vector3 right, vector3 up
local function cameraBasis()
    local rot = GetGameplayCamRot(2)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)
    local cp = math.cos(pitch)

    local forward = vector3(-math.sin(yaw) * cp, math.cos(yaw) * cp, math.sin(pitch))
    local up = vector3(0.0, 0.0, 1.0)
    local right = vector3(forward.y * up.z - forward.z * up.y,
        forward.z * up.x - forward.x * up.z,
        forward.x * up.y - forward.y * up.x)
    local rl = #right
    right = rl > 0.0001 and (right / rl) or vector3(1.0, 0.0, 0.0)

    -- Recompute up as forward x right, so it stays perpendicular to forward
    -- even when looking nearly straight up or down (world-up degenerates
    -- there, which would otherwise roll the whole basis).
    up = vector3(right.y * forward.z - right.z * forward.y,
        right.z * forward.x - right.x * forward.z,
        right.x * forward.y - right.y * forward.x)

    return GetGameplayCamCoord(), forward, right, up
end

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

-- Full volume out to VLAirRaid.audio.refDistance from a site, straight fade
-- out to `refDistance * rangeMultiplier` beyond it. Computed once: both
-- inputs are static config, never anything that changes at runtime. This is
-- the PER-SITE range (which direction a siren pans from); VLAirRaid.zone
-- below is the separate, citywide question of whether the siren is audible
-- AT ALL right now.
local AUDIO_REF_DISTANCE = VLAirRaid.audio.refDistance
local AUDIO_MAX_DISTANCE = VLAirRaid.audio.refDistance * VLAirRaid.audio.rangeMultiplier

-- =============================================================================
-- ZONE GEOMETRY
--
-- Standard point-in-polygon (ray casting) and point-to-nearest-edge distance.
-- Together: 1.0 while standing inside VLAirRaid.zone.polygon no matter how far
-- from the nearest SITE, fading to 0.0 over zone.fadeDistance metres once
-- outside it -- see config.lua's VLAirRaid.zone for why this exists as its
-- own factor rather than folding into the per-site falloff above.
-- =============================================================================

---@param px number
---@param py number
---@param poly { x: number, y: number }[]
---@return boolean
local function pointInPolygon(px, py, poly)
    local inside = false
    local j = #poly
    for i = 1, #poly do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

---Shortest distance from (px, py) to the segment (ax, ay)-(bx, by).
local function distanceToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local lenSq = dx * dx + dy * dy

    if lenSq < 1e-6 then
        local ex, ey = px - ax, py - ay
        return math.sqrt(ex * ex + ey * ey)
    end

    local t = ((px - ax) * dx + (py - ay) * dy) / lenSq
    t = math.max(0.0, math.min(1.0, t))

    local cx, cy = ax + t * dx, ay + t * dy
    local ex, ey = px - cx, py - cy
    return math.sqrt(ex * ex + ey * ey)
end

---@param px number
---@param py number
---@param poly { x: number, y: number }[]
---@return number
local function distanceToPolygonEdge(px, py, poly)
    local minD = math.huge
    local j = #poly
    for i = 1, #poly do
        local d = distanceToSegment(px, py, poly[j].x, poly[j].y, poly[i].x, poly[i].y)
        if d < minD then minD = d end
        j = i
    end
    return minD
end

---1.0 inside the zone, fading linearly to 0.0 over VLAirRaid.zone.fadeDistance
---once outside it.
---@param px number
---@param py number
---@return number
local function zoneGain(px, py)
    local zone = VLAirRaid.zone
    if pointInPolygon(px, py, zone.polygon) then return 1.0 end

    local d = distanceToPolygonEdge(px, py, zone.polygon)
    return math.max(0.0, 1.0 - d / zone.fadeDistance)
end

-- =============================================================================
-- VOICES
-- =============================================================================

---@param i integer site index
---@param siteElapsed number seconds since THIS site's own cascade trigger (>= 0)
local function startVoice(i, siteElapsed)
    if playing[i] then return end
    playing[i] = true

    local cfg = VLAirRaid.audio

    SendNUIMessage({
        action = 'sound_start',
        id = i,
        src = cfg.file,
        volume = cfg.volume,
        distanceModel = cfg.distanceModel,
        refDistance = AUDIO_REF_DISTANCE,
        maxDistance = AUDIO_MAX_DISTANCE,
        rolloff = cfg.rolloffFactor,
        fadeInMs = cfg.fadeInMs,
        -- How long INTO THIS SITE'S OWN LOOP we are, so the NUI resumes
        -- playback at the right phase (modulo the buffer's length) instead of
        -- always starting fresh at 0:00 -- see html/app.js's startVoice().
        elapsed = siteElapsed,
    })
end

local function stopVoice(i)
    if not playing[i] then return end
    playing[i] = nil
    SendNUIMessage({ action = 'sound_stop', id = i, fadeMs = VLAirRaid.audio.fadeOutMs })
end

local function stopAllVoices()
    playing = {}
    SendNUIMessage({ action = 'sound_stop_all', fadeMs = VLAirRaid.audio.fadeOutMs })
end

-- =============================================================================
-- RANGE CHECK (slow) + POSITION STREAM (fast)
--
-- Split for the same reason vl_combat_drone splits them: which sites are
-- audible at all changes slowly (walking speed against fixed points), so that
-- check can be cheap and infrequent. Where they sit in listener space changes
-- every time the camera so much as turns, so that has to be fast for the
-- panning to read as real-time head-tracking rather than a slideshow.
-- =============================================================================

local function startRangeCheck()
    CreateThread(function()
        while active do
            local coords = GetEntityCoords(cache.ped)
            local globalElapsed = raidBaseElapsed + (GetGameTimer() - raidBaseGameTimer) / 1000.0

            -- Whether this part of the map is under the siren AT ALL right
            -- now -- 1.0 anywhere inside VLAirRaid.zone.polygon, fading to 0.0
            -- over zone.fadeDistance once outside it. Applied as ONE extra
            -- multiplier on the master bus (html/app.js smooths the actual
            -- transition) rather than touching each site's own gain, since it
            -- answers a city-wide question, not a per-site one.
            SendNUIMessage({
                action = 'master_volume',
                value = VLAirRaid.audio.masterVolume * zoneGain(coords.x, coords.y),
            })

            for i, site in ipairs(VLAirRaid.sites) do
                -- Negative means this site's cascade turn has not come up yet --
                -- silent regardless of distance, even standing right on it.
                -- This check being re-evaluated every tick (not just on
                -- movement) is exactly what makes a site already-in-range start
                -- itself the moment its turn arrives, with no player movement
                -- needed to trigger it.
                local siteElapsed = globalElapsed - (siteDelays[i] or 0)

                if siteElapsed < 0 then
                    stopVoice(i)
                else
                    local dx, dy, dz = site.x - coords.x, site.y - coords.y, site.z - coords.z
                    local inRange = (dx * dx + dy * dy + dz * dz) <= AUDIO_MAX_DISTANCE * AUDIO_MAX_DISTANCE

                    if inRange then
                        startVoice(i, siteElapsed)
                    else
                        stopVoice(i)
                    end
                end
            end

            Wait(VLAirRaid.performance.checkIntervalMs)
        end

        stopAllVoices()
    end)
end

local function startPositionStream()
    CreateThread(function()
        while active do
            if next(playing) ~= nil then
                local camPos, fwd, right, up = cameraBasis()
                local batch = {}

                for i, site in ipairs(VLAirRaid.sites) do
                    if playing[i] then
                        local rel = vector3(site.x, site.y, site.z) - camPos
                        batch[#batch + 1] = {
                            id = i,
                            -- Web Audio listener space: +x right, +y up, -z forward.
                            x = dot(rel, right),
                            y = dot(rel, up),
                            z = -dot(rel, fwd),
                        }
                    end
                end

                if #batch > 0 then
                    SendNUIMessage({ action = 'sound_pos_batch', positions = batch })
                end
            end

            Wait(VLAirRaid.performance.orientationIntervalMs)
        end
    end)
end

-- =============================================================================
-- OUTPOST INTRUDER ALARM
--
-- Its own pair of loops rather than extra entries in the siren ones. Two
-- reasons, both about lifetime:
--
--   * it starts BEFORE the raid does. The siren loops run `while active`, and
--     `active` is only true once the sirens begin -- four seconds after this.
--   * it is a different sound with a much tighter range (see
--     VLAirRaid.intruderAudio), so it shares none of the siren's tuning.
--
-- Voice ids are strings ('op1'..) so they can never collide with the sirens'
-- integer indices in the NUI's voice map.
-- =============================================================================

local intruderActive = false
local intruderPlaying = {}

local function startIntruderVoice(i)
    if intruderPlaying[i] then return end
    intruderPlaying[i] = true

    local cfg = VLAirRaid.intruderAudio

    SendNUIMessage({
        action = 'sound_start',
        id = 'op' .. i,
        src = cfg.file,
        volume = cfg.volume,
        distanceModel = cfg.distanceModel,
        refDistance = cfg.refDistance,
        maxDistance = cfg.maxDistance,
        rolloff = cfg.rolloffFactor,
        fadeInMs = cfg.fadeInMs,
        fadeOutMs = cfg.fadeOutMs,

        -- A fixed number of plays, then silence -- not a loop. The NUI
        -- re-arms a fresh buffer source per repeat and fades the voice out
        -- when the count runs out (see startVoice in html/airraid.js).
        plays = cfg.plays,

        -- No phase lock. The sirens resume mid-loop so a late arrival hears an
        -- already-sounding siren; a one-shot alarm should start from the top.
        elapsed = 0,
    })
end

local function stopIntruderVoice(i)
    if not intruderPlaying[i] then return end
    intruderPlaying[i] = nil
    SendNUIMessage({ action = 'sound_stop', id = 'op' .. i, fadeMs = VLAirRaid.intruderAudio.fadeOutMs })
end

local function stopAllIntruderVoices()
    for i in pairs(intruderPlaying) do
        SendNUIMessage({ action = 'sound_stop', id = 'op' .. i, fadeMs = VLAirRaid.intruderAudio.fadeOutMs })
    end
    intruderPlaying = {}
end

local function startIntruderLoops()
    local cfg = VLAirRaid.intruderAudio
    local maxSq = cfg.maxDistance * cfg.maxDistance

    -- Range
    CreateThread(function()
        while intruderActive do
            local coords = GetEntityCoords(cache.ped)

            for i, op in ipairs(VLAirRaid.outposts) do
                local dx, dy, dz = op.x - coords.x, op.y - coords.y, op.z - coords.z

                if (dx * dx + dy * dy + dz * dz) <= maxSq then
                    startIntruderVoice(i)
                else
                    stopIntruderVoice(i)
                end
            end

            Wait(VLAirRaid.performance.checkIntervalMs)
        end

        stopAllIntruderVoices()
    end)

    -- Position, for the same head-tracking reason as the sirens.
    CreateThread(function()
        while intruderActive do
            if next(intruderPlaying) ~= nil then
                local camPos, fwd, right, up = cameraBasis()
                local batch = {}

                for i, op in ipairs(VLAirRaid.outposts) do
                    if intruderPlaying[i] then
                        local rel = vector3(op.x, op.y, op.z) - camPos
                        batch[#batch + 1] = {
                            id = 'op' .. i,
                            x = dot(rel, right),
                            y = dot(rel, up),
                            z = -dot(rel, fwd),
                        }
                    end
                end

                if #batch > 0 then
                    SendNUIMessage({ action = 'sound_pos_batch', positions = batch })
                end
            end

            Wait(VLAirRaid.performance.orientationIntervalMs)
        end
    end)
end

RegisterNetEvent('vl_airraid:intruder', function(on)
    if on then
        if intruderActive then return end
        intruderActive = true
        startIntruderLoops()
    else
        intruderActive = false   -- the loops stop themselves and clean up
    end
end)

-- =============================================================================
-- BLACKOUT
--
-- A plain full blackout: the lights go out and stay out until the raid ends.
-- No countdown HUD, no audio cue, no flicker -- see VLAirRaid.intro.blackout
-- in config.lua for why this does not just run /blackouton.
--
-- SetArtificialLightsState is a client-side native with NO state of its own, so
-- nothing else can tell whether the lights are off or who turned them off. That
-- makes turning them back ON the dangerous half, which is what the guard below
-- is for.
-- =============================================================================

RegisterNetEvent('vl_airraid:blackout', function(on, affectVehicles)
    if on then
        SetArtificialLightsState(true)
        -- Passing true means vehicle lights ALSO die, so the config value goes
        -- straight through. (The blackout system's applyLights still passes
        -- true unconditionally, so its affectVehicles option remains inert --
        -- known, deliberately left alone until the blackout's own cut-out is
        -- confirmed working. Flagged, not fixed.)
        SetArtificialLightsStateAffectsVehicles(affectVehicles == true)
        return
    end

    -- Never restore lights that vl_blackout is currently responsible for. An
    -- admin can legitimately have a real blackout running when the raid ends,
    -- and turning the city back on underneath it would leave that system
    -- believing the map is dark while it is not.
    local bo = GlobalState.blackout
    if bo and bo.active == true then return end

    SetArtificialLightsState(false)
    SetArtificialLightsStateAffectsVehicles(false)
end)

-- =============================================================================
-- RADIO TRANSMISSION
--
-- Passive: no NUI focus, no input. The player is meant to be running while
-- they read it.
-- =============================================================================

RegisterNetEvent('vl_airraid:radio', function(data)
    if type(data) ~= 'table' then return end

    SendNUIMessage({
        action = 'radio_show',
        channel = data.channel,
        text = data.text,
        sound = data.sound,
        volume = data.volume,
        holdMs = data.holdMs,
        typeMs = data.typeMs,
    })
end)

-- =============================================================================
-- STATE -> EFFECT
-- =============================================================================

local function start()
    if active then return end
    active = true

    -- One server round trip per activation, not per site. FiveM's client Lua
    -- has NO `os` library at all -- os.time() is nil there and throws the
    -- moment it's touched, which is exactly why vl_blackout's own client.lua
    -- has to ask the server for its remaining time rather than computing it
    -- locally (see its onState() comment). Only the server can say how many
    -- seconds the raid has actually been running.
    --
    -- Asked ONCE here rather than once per site-enter event: GetGameTimer() is
    -- a plain local millisecond counter, always safe client-side and with no
    -- wall-clock involved at all, so everything after this one reply is
    -- derived from it (see startVoice's `elapsed` calculation) instead of
    -- asking the server again every time a new site comes into range.
    local ok, serverElapsed = pcall(function()
        return lib.callback.await('vl_airraid:getElapsed', false)
    end)
    raidBaseElapsed = (ok and serverElapsed) or 0
    raidBaseGameTimer = GetGameTimer()

    siteDelays = (GlobalState.airraid and GlobalState.airraid.delays) or {}

    -- No one-time master_volume send here any more -- startRangeCheck()'s
    -- loop sends it every tick anyway (masterVolume * the live zone factor),
    -- and its first iteration runs before this function returns, so a
    -- separate initial send would only ever be redundant with it.

    createBlips()
    startRangeCheck()
    startPositionStream()
end

local function stop()
    if not active then return end
    active = false

    removeBlips()
    stopAllVoices()
end

-- State bag handlers run outside a coroutine (same reason vl_blackout's own
-- handler dispatches into a thread): start() now yields on the callback
-- above, which a bare state bag handler cannot do.
AddStateBagChangeHandler('airraid', 'global', function(_, _, value)
    CreateThread(function()
        if value ~= nil and value.active == true then start() else stop() end
    end)
end)

-- The state bag change handler above only fires on a CHANGE. A client already
-- connected when a raid starts gets that change event fine; one who joins
-- mid-raid needs the current value read once, the same pattern vl_hud already
-- uses for the blackout key.
CreateThread(function()
    Wait(1500) -- GlobalState needs a moment to replicate on a fresh join
    if isActive() then start() end
end)

-- See server/main.lua: GlobalState during onResourceStop is not trusted to
-- replicate, so the server also broadcasts this directly.
RegisterNetEvent('vl_airraid:forceStop', function()
    stop()
end)

RegisterNUICallback('ready', function(data, cb)
    if VLAirRaid.debug then
        print(('[vl_airraid] NUI page alive (AudioContext: %s)'):format(tostring(data and data.audio or '?')))
    end
    cb({})
end)

-- The page now plays TWO different files, so both messages name the source
-- rather than assuming it was the siren. That assumption is what made a
-- wrong-sound problem invisible in the console.
RegisterNUICallback('audioError', function(data, cb)
    local src = data and data.src or VLAirRaid.audio.file
    print(('[vl_airraid] audio failed to load: "%s" -- %s. Check that "html/%s" exists and is listed in fxmanifest.lua files{}.')
        :format(tostring(src), tostring(data and data.error or 'unknown'), tostring(src)))
    cb({})
end)

RegisterNUICallback('audioLoaded', function(data, cb)
    if VLAirRaid.debug then
        print(('[vl_airraid] decoded "%s" (%.3fs)')
            :format(tostring(data and data.src or '?'), tonumber(data and data.seconds) or 0))
    end
    cb({})
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    stop()
end)
