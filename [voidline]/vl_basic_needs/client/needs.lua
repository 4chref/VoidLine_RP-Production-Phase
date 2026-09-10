NeedsClient = {}

local currentNeeds = { poop = 0, sleep = 0, pee = 0 }
local hudReady = false

local function sendHudPosition()
    SendNUIMessage({
        action = 'setPosition',
        position = Config.HudPosition
    })
end

RegisterNUICallback('ready', function(_, cb)
    hudReady = true
    sendHudPosition()
    SendNUIMessage({ action = 'update', needs = currentNeeds })
    cb('ok')
end)

RegisterNetEvent('basic_needs:client:updateHud', function(needs)
    if not needs then return end
    currentNeeds = needs
    SendNUIMessage({
        action = 'update',
        needs = needs
    })
end)

RegisterNetEvent('basic_needs:client:notify', function(msg, kind)
    Config.Notify(msg, kind)
end)

function NeedsClient.Get()
    return currentNeeds
end

function NeedsClient.RequestSync()
    TriggerServerEvent('basic_needs:server:playerReady')
end
