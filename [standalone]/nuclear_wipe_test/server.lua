local active = false

local function debugPrint(msg)
    if Config.Debug then
        print(('[nuclear_wipe] %s'):format(msg))
    end
end

RegisterCommand(Config.Command, function(source)
    if active then
        if source ~= 0 then
            TriggerClientEvent('nuclear_wipe:notify', source, 'A nuclear event is already running.')
        end
        return
    end

    active = true
    debugPrint(('Nuclear wipe started by %s'):format(source))
    TriggerClientEvent('nuclear_wipe:start', -1)
end, false)

RegisterCommand(Config.ResetCommand, function(source)
    active = false
    debugPrint(('Nuclear wipe reset by %s'):format(source))
    TriggerClientEvent('nuclear_wipe:reset', -1)
end, false)

RegisterNetEvent('nuclear_wipe:finished', function()
    active = false
    debugPrint('Nuclear event finished.')
end)
