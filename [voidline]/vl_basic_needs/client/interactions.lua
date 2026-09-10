Interactions = {}

local inToiletAction = false
local inBedAction = false

local function drawHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- ============================================================
-- TOILET FLOW
-- ============================================================

RegisterNetEvent('basic_needs:client:startToilet', function(kind, duration)
    inToiletAction = true
    CreateThread(function()
        local ped = PlayerPedId()
        local dict = 'amb@world_human_urinate@male@idle_a'
        local anim = 'idle_c'
        local loaded = loadAnimDict(dict)

        local controlThread = true
        CreateThread(function()
            while controlThread do
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 24, true)
                Wait(0)
            end
        end)

        if loaded then
            TaskPlayAnim(ped, dict, anim, 3.0, -3.0, -1, 1, 0, false, false, false)
        end

        Wait(duration)

        if loaded then
            StopAnimTask(ped, dict, anim, 1.0)
            RemoveAnimDict(dict)
        end
        controlThread = false
        inToiletAction = false
    end)
end)

RegisterNetEvent('basic_needs:client:endToilet', function()
    inToiletAction = false
end)

-- ============================================================
-- BED FLOW
-- ============================================================

local sleepingInBed = false

local function startBedSleep()
    if sleepingInBed then return end
    sleepingInBed = true
    inBedAction = true
    TriggerServerEvent('basic_needs:server:useBedStart')

    CreateThread(function()
        local ped = PlayerPedId()
        local dict = 'anim@amb@sleep_veh@sleep_veh_getin_02@'
        local loaded = loadAnimDict(dict)

        local controlThread = true
        CreateThread(function()
            while controlThread do
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 38, true) -- INPUT_PICKUP / cancel key reserved

                if IsControlJustReleased(0, 73) then -- X = cancel sleep
                    controlThread = false
                end
                Wait(0)
            end
        end)

        if loaded then
            TaskPlayAnim(ped, dict, 'sleep_getin_low_front_ig', 3.0, -3.0, -1, 1, 0, false, false, false)
        end

        while sleepingInBed and controlThread do
            Wait(200)
        end

        ClearPedTasks(ped)
        if loaded then RemoveAnimDict(dict) end

        sleepingInBed = false
        inBedAction = false
        TriggerServerEvent('basic_needs:server:useBedStop')
    end)
end

RegisterNetEvent('basic_needs:client:endBed', function()
    sleepingInBed = false
end)

-- ============================================================
-- PROXIMITY THREAD (adaptive interval)
-- ============================================================

CreateThread(function()
    while true do
        local sleepTime = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local nearestPrompt = nil

        if not inToiletAction and not inBedAction and not SleepClient.IsFainted() and not PeeClient.IsActive() then
            for _, toilet in ipairs(Config.Toilets) do
                local dist = #(coords - toilet.coords)
                if dist < toilet.radius then
                    sleepTime = 0
                    if toilet.type == 'pee' then
                        nearestPrompt = { text = '[E] Pee', action = function() TriggerServerEvent('basic_needs:server:useToilet', 'pee') end }
                    elseif toilet.type == 'poop' then
                        nearestPrompt = { text = '[E] Use Toilet', action = function() TriggerServerEvent('basic_needs:server:useToilet', 'poop') end }
                    else
                        local needs = NeedsClient.Get()
                        if needs.pee >= needs.poop then
                            nearestPrompt = { text = '[E] Pee', action = function() TriggerServerEvent('basic_needs:server:useToilet', 'pee') end }
                        else
                            nearestPrompt = { text = '[E] Use Toilet', action = function() TriggerServerEvent('basic_needs:server:useToilet', 'poop') end }
                        end
                    end
                    break
                elseif dist < toilet.radius + 8.0 then
                    sleepTime = math.min(sleepTime, 300)
                end
            end

            if not nearestPrompt then
                for _, bed in ipairs(Config.Beds) do
                    local dist = #(coords - bed.coords)
                    if dist < 1.5 then
                        sleepTime = 0
                        nearestPrompt = { text = '[E] Sleep', action = startBedSleep }
                        break
                    elseif dist < 9.0 then
                        sleepTime = math.min(sleepTime, 300)
                    end
                end
            end
        end

        if nearestPrompt then
            drawHelpText(nearestPrompt.text)
            if IsControlJustReleased(0, 38) then -- E
                nearestPrompt.action()
            end
        end

        Wait(sleepTime)
    end
end)
