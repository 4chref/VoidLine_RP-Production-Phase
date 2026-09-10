-- =============================================================================
-- combat_drone / client/audio.lua
--
-- The drone's alert siren, played AS A WORLD SOUND coming out of the drone.
--
-- WHY NUI AND NOT A GAME SOUND
-- PlaySoundFromEntity can only play sounds that exist in a loaded game audio
-- bank, and building a bank from an mp3 needs an .awc, which cannot be produced
-- at runtime. So the mp3 is played by the resource's NUI page (html/index.html)
-- and spatialised there with the Web Audio API. That gives real distance
-- attenuation and real stereo/HRTF panning, not a fake volume fade.
--
-- The page's audio listener never moves: it sits at the origin facing forward,
-- and this file streams each drone's position expressed relative to the
-- GAMEPLAY CAMERA (right / up / behind). That is mathematically identical to
-- moving the listener, and it means only three numbers per drone per update
-- have to cross the Lua->NUI boundary.
--
-- WHO PLAYS IT
-- Siren state is decided by whichever client currently controls the drone, but
-- everyone nearby has to hear it, so the state is relayed through the server
-- and every client renders the sound locally from its own copy of the entity.
-- Position updates are therefore purely local and cost no bandwidth at all.
-- =============================================================================

Audio = {}

-- Two separate states, because "the server says this drone is sounding" and
-- "this client can currently hear it" are genuinely different things: a drone
-- can stream out and back in while its siren stays on the whole time. Caching
-- one entity handle at start time would silently kill the sound the first time
-- the player walked away and returned.
local wanted = {}    -- netId -> true while the server says the siren is on
local playing = {}   -- netId -> true while a voice exists in the NUI page
local lastSent = {}  -- netId -> last siren state this client asked the server for

-- Camera basis, rebuilt once per position tick rather than per drone.
local function CameraBasis()
    local rot = GetGameplayCamRot(2)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)

    local cp = math.cos(pitch)
    local forward = vector3(-math.sin(yaw) * cp, math.cos(yaw) * cp, math.sin(pitch))
    local right = Utils.Normalize(Utils.Cross(forward, vector3(0.0, 0.0, 1.0)))
    local up = Utils.Cross(right, forward)

    return GetGameplayCamCoord(), forward, right, up
end

-- =============================================================================
-- NUI HEALTH
-- =============================================================================
-- A NUI page that failed to load makes SendNUIMessage a silent no-op, which
-- takes out the siren AND the countdown at once with nothing in the console.
-- The page announces itself on load so that failure is visible instead.

Audio.nuiReady = false
Audio.nuiState = 'no response from the NUI page'

RegisterNUICallback('ready', function(data, cb)
    Audio.nuiReady = true
    Audio.nuiState = ('alive (AudioContext: %s)'):format(tostring(data and data.audio or '?'))
    cb({})
end)

RegisterNUICallback('audioError', function(data, cb)
    local err = data and data.error or 'unknown'
    Audio.nuiState = ('alive, but the sound failed to load: %s'):format(err)
    print(('[combat_drone] alert sound could not be loaded: %s. Check that "%s" exists in html/ and is listed in fxmanifest files{}.')
        :format(err, tostring(Config.Alert.sound)))
    cb({})
end)

-- =============================================================================
-- LOCAL PLAYBACK
-- =============================================================================

-- Creates/destroys the actual voice in the NUI page. Driven by the position
-- thread below as the drone streams in and out, not by the network event.
local function SetVoice(netId, on)
    if on then
        if playing[netId] then return end
        playing[netId] = true
        SendNUIMessage({
            action = 'sound_start',
            id = tostring(netId),
            src = Config.Alert.sound,
            volume = Config.Alert.volume,
            loop = Config.Alert.loop,
            refDistance = Config.Alert.refDistance,
            maxDistance = Config.Alert.maxDistance,
            rolloff = Config.Alert.rolloff,
        })
    else
        if not playing[netId] then return end
        playing[netId] = nil
        SendNUIMessage({ action = 'sound_stop', id = tostring(netId), fade = Config.Alert.fadeOutMs })
    end
end

-- Records whether this drone should be sounding on THIS client. Called from the
-- networked state event, never directly by the AI.
function Audio.SetLocalSiren(netId, on)
    if not Config.Alert.enabled then return end
    wanted[netId] = on or nil
    if not on then SetVoice(netId, false) end
end

function Audio.StopAll()
    wanted = {}
    playing = {}
    lastSent = {}
    SendNUIMessage({ action = 'sound_stop_all' })
end

-- Drop all bookkeeping for a drone that no longer exists. The requested-state
-- cache must be cleared here and NOT when the siren merely stops, or a drone
-- sitting quietly on patrol would re-request "off" on every decision tick and
-- turn an edge-triggered event into a 4Hz network spam.
function Audio.Forget(netId)
    wanted[netId] = nil
    SetVoice(netId, false)
    lastSent[netId] = nil
end

-- =============================================================================
-- AI SIDE: request a siren state (controlling client only)
-- =============================================================================

-- Idempotent: only produces network traffic when the state actually flips, so
-- the state machine can call this every decision tick without thinking about it.
function Audio.RequestSiren(drone, on)
    if not Config.Alert.enabled then return end
    local netId = drone.netId
    if not netId then return end

    -- Play it here directly as well as relaying it. The controlling client is
    -- normally the closest player -- very often the one being warned -- and the
    -- siren must not depend on a server round trip coming back. The relayed
    -- broadcast reaches this client too, but SetLocalSiren is idempotent.
    Audio.SetLocalSiren(netId, on)

    if lastSent[netId] == on then return end
    lastSent[netId] = on
    TriggerServerEvent('combat_drone:setSiren', netId, on)
end

-- =============================================================================
-- NETWORK
-- =============================================================================

RegisterNetEvent('combat_drone:sirenState', function(netId, on)
    -- Recorded even if the drone isn't streamed in on this client yet -- the
    -- position thread starts the voice the moment the entity appears.
    Audio.SetLocalSiren(netId, on)
end)

-- =============================================================================
-- POSITION STREAM
-- =============================================================================
-- One thread for every siren on this client. Runs at Config.Alert.updateInterval
-- (~15Hz); the NUI page eases between samples so the motion still sounds smooth.

CreateThread(function()
    while true do
        if next(wanted) == nil then
            Wait(250) -- nothing sounding: cost nothing
        else
            local camPos, fwd, right, up = CameraBasis()

            for netId in pairs(wanted) do
                -- Resolved fresh every tick rather than cached at start: a drone
                -- can stream out and back in while its siren stays on, and a
                -- stale handle would leave it permanently silent.
                local ent = nil
                if NetworkDoesNetworkIdExist(netId) and NetworkDoesEntityExistWithNetworkId(netId) then
                    ent = NetworkGetEntityFromNetworkId(netId)
                end

                -- The pilot ped is the networked entity, but the sound must come
                -- from the hull the player can actually see.
                if ent and DoesEntityExist(ent) and IsEntityAPed(ent) then
                    local veh = GetVehiclePedIsIn(ent, false)
                    if veh ~= 0 and DoesEntityExist(veh) then ent = veh end
                end

                if not ent or not DoesEntityExist(ent) then
                    SetVoice(netId, false) -- out of range: silent, but still wanted
                else
                    SetVoice(netId, true)
                    local rel = GetEntityCoords(ent) - camPos
                    SendNUIMessage({
                        action = 'sound_pos',
                        id = tostring(netId),
                        -- Web Audio listener space: +x right, +y up, -z forward.
                        x = Utils.Dot(rel, right),
                        y = Utils.Dot(rel, up),
                        z = -Utils.Dot(rel, fwd),
                    })
                end
            end

            Wait(Config.Alert.updateInterval)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SendNUIMessage({ action = 'reset' })
end)
