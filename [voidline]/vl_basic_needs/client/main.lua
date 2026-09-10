CreateThread(function()
    while not Bridge.IsPlayerLoaded() do
        Wait(500)
    end
    NeedsClient.RequestSync()
end)

-- re-sync on resource start (e.g. resource restart while player already in)
AddEventHandler('onClientResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        while not Bridge.IsPlayerLoaded() do
            Wait(500)
        end
        NeedsClient.RequestSync()
    end)
end)

-- ============================================================
-- DEATH HANDLING
-- ============================================================

local wasDead = false
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped)
        if dead ~= wasDead then
            wasDead = dead
            TriggerServerEvent('basic_needs:server:setDead', dead)
            if dead then
                PoopClient.Remove()
                SleepClient.EndFaint()
            end
        end
    end
end)

-- ============================================================
-- CLIENT EXPORTS (convenience wrappers, forward to server)
-- ============================================================

exports('AddFood', function(amount)
    TriggerServerEvent('basic_needs:server:addFood', amount)
end)

exports('AddDrink', function(amount)
    TriggerServerEvent('basic_needs:server:addDrink', amount)
end)

exports('GetNeeds', function()
    return NeedsClient.Get()
end)

exports('IsFainted', function()
    return SleepClient.IsFainted()
end)

exports('GetFaintRemainingMs', function()
    return SleepClient.GetFaintRemainingMs()
end)
