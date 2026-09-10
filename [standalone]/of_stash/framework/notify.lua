local IS_SERVER = IsDuplicityVersion()
local DEFAULT_DURATION = 3500

Notify = { send = function() end } -- replaced once the core resolves the adapter

local function clientShow(message, kind, duration)
    if Bridge.started('ox_lib') then
        exports.ox_lib:notify({ description = message, type = kind or 'inform', duration = duration or DEFAULT_DURATION })
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

Bridge.register('notify', {
    name = 'ox_lib',
    priority = 30,
    detect = function() return Bridge.started('ox_lib') end,
    build = function() return { name = 'ox_lib' } end,
})

Bridge.register('notify', {
    name = 'native',
    priority = -100,
    detect = function() return true end,
    build = function() return { name = 'native' } end,
})

if IS_SERVER then
    function Notify.send(source, message, kind, duration)
        TriggerClientEvent('of_stash:client:notify', source, message, kind, duration)
    end
else
    function Notify.send(message, kind, duration)
        clientShow(message, kind, duration)
    end

    RegisterNetEvent('of_stash:client:notify', function(message, kind, duration)
        clientShow(message, kind, duration)
    end)
end
