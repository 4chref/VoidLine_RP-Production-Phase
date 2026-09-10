PoopClient = {}

local clipsetApplied = false
local clipsetLoaded = false
local poopCritical = false
local reliefActive = false

local function loadClipsetSafely(clipset)
    if HasAnimSetLoaded(clipset) then return true end
    RequestAnimSet(clipset)
    local timeout = GetGameTimer() + 5000
    while not HasAnimSetLoaded(clipset) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimSetLoaded(clipset)
end

function PoopClient.Apply()
    if clipsetApplied then return end
    local ped = PlayerPedId()
    local clipset = Config.Poop.walkingClipSet

    if loadClipsetSafely(clipset) then
        clipsetLoaded = true
        SetPedMovementClipset(ped, clipset, 0.5)
        clipsetApplied = true
    end
end

function PoopClient.Remove()
    if not clipsetApplied then return end
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 0.5)
    if clipsetLoaded then
        RemoveAnimSet(Config.Poop.walkingClipSet)
        clipsetLoaded = false
    end
    clipsetApplied = false
end

local function disableMovementControlsThisFrame()
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 45, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 143, true)
end

--- Started by pressing Config.PoopRelief.key while poop is critical (see the
--- key-detection thread below), then plays through to completion on its own
--- -- no further input needed once triggered. Plays the rpemotes emote
--- configured in Config.PoopRelief.emoteName wherever the player is standing.
local function startPoopRelief()
    if reliefActive then return end
    reliefActive = true

    if Config.Debug then
        print('[basic_needs] poop relief auto-started')
    end

    local controlThread = true
    CreateThread(function()
        while controlThread do
            disableMovementControlsThisFrame()
            Wait(0)
        end
    end)

    local usingEmote = GetResourceState('rpemotes') == 'started'
    if usingEmote then
        exports['rpemotes']:EmoteCommandStart(Config.PoopRelief.emoteName)
    end

    Wait(Config.PoopRelief.duration)

    if usingEmote then
        local ok, isPlaying = pcall(function() return exports['rpemotes']:IsPlayerInAnim() end)
        if ok and isPlaying then
            pcall(function() exports['rpemotes']:EmoteCancel() end)
        end
    end

    controlThread = false
    reliefActive = false
    TriggerServerEvent('basic_needs:server:poopReliefDone')
end

RegisterNetEvent('basic_needs:client:setPoopEffect', function(active)
    if IsEntityDead(PlayerPedId()) then return end
    poopCritical = active

    if active then
        PoopClient.Apply()
        Config.Notify('You urgently need to poop! Find a place and press G to relieve yourself.', 'error')
    else
        PoopClient.Remove()
    end
end)

--- Server confirms the request (see poopReliefRequest below) and fires this
--- back; the emote then plays through automatically with no further input.
RegisterNetEvent('basic_needs:client:startPoop', function()
    if reliefActive then return end
    if IsEntityDead(PlayerPedId()) then
        TriggerServerEvent('basic_needs:server:poopReliefDone')
        return
    end
    CreateThread(startPoopRelief)
end)

-- Listens for the relief key only while poop is critical; adaptive wait so
-- this costs nothing the rest of the time. Sends a request to the server
-- (Needs.TriggerPoop validates poop is actually >= 100) rather than starting
-- the emote locally, so a modified client can't fake the trigger.
CreateThread(function()
    while true do
        local sleepTime = 500

        if poopCritical and not reliefActive then
            sleepTime = 0
            local ped = PlayerPedId()
            local busy = IsEntityDead(ped)
                or IsPedInAnyVehicle(ped, false)
                or SleepClient.IsFainted()
                or PeeClient.IsActive()

            if not busy and IsControlJustReleased(0, Config.PoopRelief.key) then
                TriggerServerEvent('basic_needs:server:poopReliefRequest')
            end
        end

        Wait(sleepTime)
    end
end)

function PoopClient.IsActive()
    return reliefActive
end

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    PoopClient.Remove()
end)
