RegisterNetEvent('horse_rental:requestHorse', function()
    local src = source
    TriggerClientEvent('horse_rental:spawnHorse', src)
end)