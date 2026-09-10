local lastTrigger = 0

AddEventHandler('kq_lasers:dispatch:client:trigger', function(entity, data)
    local coords = GetEntityCoords(entity)
    PoliceDispatch(coords, data)
end)

function PoliceDispatch(eventCoords, data)
    if lastTrigger + ((Config.dispatch.globalCooldown or 30) * 1000) > GetGameTimer() then
        return
    end
    lastTrigger = GetGameTimer()

    local system = Config.dispatch.system
    local blipData = Config.dispatch.blip

    if system == 'default' then
        TriggerServerEvent('kq_lasers:dispatch:server:sendDispatch', eventCoords, data)
    elseif system == 'ps-dispatch' then
        exports['ps-dispatch']:CustomAlert({
            coords = eventCoords,
            message = data.title,
            dispatchCode = '10-62',
            description = data.message,
            radius = 0,
            sprite = blipData.sprite,
            color = blipData.color,
            scale = blipData.scale,
            length = 3,
            recipientList = data.jobs
        })
    elseif system == 'core-dispatch-old' then
        local hash, _ = GetStreetNameAtCoord(eventCoords.x, eventCoords.y, eventCoords.z)
        local street = GetStreetNameFromHashKey(hash)
        for _, job in ipairs(data.jobs) do
            TriggerServerEvent(
                'core_dispatch:addCall',
                '10-62',
                data.title,
                { { icon = 'fa-solid fa-user-police', info = street } },
                { eventCoords[1], eventCoords[2], eventCoords[3] },
                job,
                blipData.timeout * 1000,
                blipData.sprite,
                blipData.color
            )
        end
    elseif system == 'core-dispatch-new' then
        local hash, _ = GetStreetNameAtCoord(eventCoords.x, eventCoords.y, eventCoords.z)
        local street = GetStreetNameFromHashKey(hash)
        for _, job in ipairs(data.jobs) do
            exports['core_dispach']:addCall(
                '10-62',
                data.title,
                {
                    { icon = 'fa-map-signs', info = street }
                },
                { eventCoords[1], eventCoords[2], eventCoords[3] },
                job,
                blipData.timeout * 1000,
                blipData.sprite,
                blipData.color
            )
        end
    elseif system == 'cd-dispatch' then
        exports['cd_dispatch']:GetPlayerInfo()
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = data.jobs,
            coords = eventCoords,
            title = '10-62',
            message = data.title,
            flash = 0,
            unique_id = 'kq_smash_n_grab_' .. tostring(math.random(0000000, 9999999)),
            blip = {
                sprite = blipData.sprite,
                scale = blipData.scale,
                colour = blipData.color,
                flashes = blipData.showRadar,
                text = data.title,
                time = blipData.timeout * 1000,
                sound = 1,
            }
        })
    end
end

RegisterNetEvent('kq_lasers:dispatch:client:sendDispatch')
AddEventHandler('kq_lasers:dispatch:client:sendDispatch', function(coords, data)
    if not Contains(data.jobs, PLAYER_JOB) then
        return
    end

    CreatePoliceBlip(coords, Config.dispatch.blip.sprite, data)

    SendDispatchMessage(data.message, data.title, data)
    if Config.dispatch.blip.showRadar then
        CreatePoliceBlip(coords, 161, data, true)
    end
end)


function CreatePoliceBlip(coords, sprite, data, hiddenLegend)
    Citizen.CreateThread(function()
        local blipData = Config.dispatch.blip
        local blip = AddBlipForCoord(coords)

        SetBlipSprite(blip, sprite)
        SetBlipHighDetail(blip, true)
        SetBlipColour(blip, blipData.color)
        SetBlipAlpha(blip, 255)
        SetBlipScale(blip, blipData.scale)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(data.title)
        EndTextCommandSetBlipName(blip)
        SetBlipAsShortRange(blip, false)
        SetBlipHiddenOnLegend(blip, hiddenLegend or false)

        RealWait(Config.dispatch.blip.timeout * 1000)

        RemoveBlip(blip)
    end)
end

function SendDispatchMessage(message, subtitle)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)

    -- Set the notification icon, title and subtitle.
    local title = L('Dispatch')
    local iconType = 0
    local flash = false -- Flash doesn't seem to work no matter what.
    EndTextCommandThefeedPostMessagetext('CHAR_GANGAPP', 'CHAR_GANGAPP', flash, iconType, title, subtitle)

    -- Draw the notification
    local showInBrief = true
    local blink = false -- blink doesn't work when using icon notifications.
    EndTextCommandThefeedPostTicker(blink, showInBrief)
end
