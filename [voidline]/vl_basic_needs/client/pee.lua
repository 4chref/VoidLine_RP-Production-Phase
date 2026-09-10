PeeClient = {}

local peeActive = false

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

local function loadDictSafely(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function rpEmotesAvailable()
    return Config.PeeAnimation.useRpEmotes and GetResourceState('rpemotes') == 'started'
end

local function runPeeSequenceViaRpEmotes()
    if Config.Debug then
        print('[basic_needs] pee sequence: using rpemotes emote "' .. Config.PeeAnimation.rpEmoteName .. '"')
    end

    -- rpemotes' "pee" emote plays its loop animation immediately, but its
    -- particle/stream effect only fires while control 47 (G) is held down.
    -- Since this whole sequence is meant to be fully automatic, spoof that
    -- key as held for the duration instead of requiring the player to press it.
    local controlThread = true
    CreateThread(function()
        while controlThread do
            disableMovementControlsThisFrame()
            SetControlNormal(0, 47, 1.0)
            Wait(0)
        end
    end)

    exports['rpemotes']:EmoteCommandStart(Config.PeeAnimation.rpEmoteName)
    Wait(Config.PeeAnimation.duration)

    local ok, isStillPlaying = pcall(function() return exports['rpemotes']:IsPlayerInAnim() end)
    if ok and isStillPlaying then
        pcall(function() exports['rpemotes']:EmoteCancel() end)
    end

    controlThread = false
    peeActive = false
    TriggerServerEvent('basic_needs:server:peeAnimDone')
end

local function runPeeSequenceViaOwnAnim()
    local ped = PlayerPedId()

    local dict, anim = Config.PeeAnimation.dict, Config.PeeAnimation.anim
    local loaded = loadDictSafely(dict)
    if Config.Debug then
        print(('[basic_needs] pee anim primary dict=%s loaded=%s'):format(dict, tostring(loaded)))
    end
    if not loaded then
        dict, anim = Config.PeeAnimation.fallbackDict, Config.PeeAnimation.fallbackAnim
        loaded = loadDictSafely(dict)
        if Config.Debug then
            print(('[basic_needs] pee anim fallback dict=%s loaded=%s'):format(dict, tostring(loaded)))
        end
    end

    local controlThread = true
    CreateThread(function()
        while controlThread do
            disableMovementControlsThisFrame()
            Wait(0)
        end
    end)

    if loaded then
        ClearPedTasksImmediately(ped)
        TaskPlayAnim(ped, dict, anim, 3.0, -3.0, -1, 1, 0, false, false, false)
        if Config.Debug then
            print(('[basic_needs] pee anim started dict=%s anim=%s'):format(dict, anim))
        end
    elseif Config.Debug then
        print('[basic_needs] pee sequence: both dicts failed to load, playing lock-only')
    end

    Wait(Config.PeeAnimation.duration)

    if loaded then
        StopAnimTask(ped, dict, anim, 1.0)
        RemoveAnimDict(dict)
    end

    controlThread = false
    peeActive = false
    TriggerServerEvent('basic_needs:server:peeAnimDone')
end

local function runPeeSequence()
    peeActive = true
    local ped = PlayerPedId()

    -- wait until out of a vehicle if configured
    if Config.PeeSettings.waitForVehicleExit then
        while IsPedInAnyVehicle(ped, false) do
            Wait(500)
            ped = PlayerPedId()
            if IsEntityDead(ped) then
                peeActive = false
                TriggerServerEvent('basic_needs:server:peeAnimDone')
                return
            end
        end
    end

    if rpEmotesAvailable() then
        runPeeSequenceViaRpEmotes()
    else
        runPeeSequenceViaOwnAnim()
    end
end

RegisterNetEvent('basic_needs:client:startPee', function()
    if peeActive then return end
    if IsEntityDead(PlayerPedId()) then return end
    CreateThread(runPeeSequence)
end)

function PeeClient.IsActive()
    return peeActive
end

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    peeActive = false
end)
