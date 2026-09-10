
RegisterServerEvent('kq_lasers:dispatch:server:sendDispatch')
AddEventHandler('kq_lasers:dispatch:server:sendDispatch', function(coords, data)
    TriggerClientEvent('kq_lasers:dispatch:client:sendDispatch', -1, coords, data)
end)
