local isOpen = false

local function closeArmory()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openArmory()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', items = Config.Items })
end

RegisterNUICallback('close', function(_, cb)
    closeArmory()
    cb('ok')
end)

RegisterNUICallback('take', function(data, cb)
    lib.callback('vl_armory:server:take', false, function(success)
        cb(success or false)
    end, data.name)
end)

CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = vec3(Config.Coords.x, Config.Coords.y, Config.Coords.z),
        size = vec3(1.5, 1.5, 2.2),
        rotation = Config.Coords.w,
        debug = false,
        options = {
            {
                name = 'vl_armory_open',
                icon = 'fa-solid fa-gun',
                label = 'Open Armory',
                distance = Config.InteractDistance,
                onSelect = openArmory,
            },
        },
    })
end)

