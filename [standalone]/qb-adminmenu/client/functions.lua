function LoadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(5)
    end
end

function getTableLength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

function getEntity(player)
    local result, entity = GetEntityPlayerIsFreeAimingAt(player)
    return entity
end

function bulletCoords()
    local result, coord = GetPedLastWeaponImpactCoord(PlayerPedId())
    return coord
end

function getGroundZ(x, y, z)
    local result, groundZ = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 0.0, Citizen.ReturnResultAnyway())
    return groundZ
end

AdminPanel.DeleteEntity = function(entity)    
    NetworkRequestControlOfEntity(entity)
    
    local timeout = 2000
    while timeout > 0 and not NetworkHasControlOfEntity(entity) do
        Wait(100)
        timeout = timeout - 100
    end

    SetEntityAsMissionEntity(entity, true, true)
    
    local timeout = 2000
    while timeout > 0 and not IsEntityAMissionEntity(entity) do
        Wait(100)
        timeout = timeout - 100
    end

    Citizen.InvokeNative( 0xEA386986E786A54F, Citizen.PointerValueIntInitialized( entity ) )
    
    if ( DoesEntityExist( entity ) ) then 
        DeleteEntity(entity)
        if ( DoesEntityExist( entity ) ) then 
            TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>ERROR:</strong> Entity could not be deleted.")
            return false
        else 
            TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>SUCCESS:</strong> Entity deleted.")
        end
    else 
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>SUCCESS:</strong> Entity deleted.")
    end
end

local lastMsg = GetGameTimer()
AdminPanel.SendCooldownNotification = function(msg, type)
    local newMsg = GetGameTimer()
    if newMsg - lastMsg > 1000 then
        if QBCore then
            QBCore.Functions.Notify(msg, type)
        else
            ESX.ShowNotification(msg)
        end
        lastMsg = GetGameTimer()
    end
end

AdminPanel.GetPeds = function(ignoreList)
    local pedPool = GetGamePool("CPed")
    local ignoreList = ignoreList or {}
    local peds = {}
    for i = 1, #pedPool, 1 do
        local found = false
        for j = 1, #ignoreList, 1 do
            if ignoreList[j] == pedPool[i] then
                found = true
            end
        end
        if not found then
            peds[#peds + 1] = pedPool[i]
        end
    end
    return peds
end

drawTxt = function(text,font,centre,x,y,scale,r,g,b,a)
	SetTextFont(font)
	SetTextProportional(0)
	SetTextScale(scale, scale)
	SetTextColour(r, g, b, a)
	SetTextDropShadow(0, 0, 0, 0,255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(centre)
	SetTextEntry("STRING")
	AddTextComponentString(text)
	DrawText(x , y)	
end


loadedAnims = false
travelSpeed = 4

function degToRad( degs )
    return degs * 3.141592653589793 / 180
end

AdminPanel.GetClosestPedNotPlayer = function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local ignoreList = ignoreList or {}
    local peds = AdminPanel.GetPeds(ignoreList)
    local closestDistance = -1
    local closestPed = -1
    for i = 1, #peds, 1 do
        local pedCoords = GetEntityCoords(peds[i])
        local distance = #(pedCoords - coords)

        if closestDistance == -1 or closestDistance > distance and peds[i] ~= PlayerPedId() then
            closestPed = peds[i]
            closestDistance = distance
        end
    end
    return closestPed, closestDistance
end

AdminPanel.GetClosestPlayer = function(coords)
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == "table" and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    if QBCore then
        local closestPlayers = QBCore.Functions.GetPlayersFromCoords(coords)
        local closestDistance = -1
        local closestPlayer = -1
        for i = 1, #closestPlayers, 1 do
            if closestPlayers[i] ~= PlayerId() and closestPlayers[i] ~= -1 then
                local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
                local distance = #(pos - coords)

                if closestDistance == -1 or closestDistance > distance then
                    closestPlayer = closestPlayers[i]
                    closestDistance = distance
                end
            end
        end
    else
        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
        if closestPlayer == -1 or closestDistance > 3.0 then
            return
        end
    end
    return closestPlayer, closestDistance
end

function godModeChange()
    AdminPanel.GodMode = not AdminPanel.GodMode
    if AdminPanel.GodMode then
        while AdminPanel.GodMode do
            Wait(0)
            SetPlayerInvincible(PlayerId(), true)
        end
        SetPlayerInvincible(PlayerId(), false)
    end
end

GetPlayers = function()
    local players = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if DoesEntityExist(ped) then
            table.insert(players, player)
        end
    end
    return players
end

GetPlayersFromCoords = function(coords, distance)
    local players = GetPlayers()
    local closePlayers = {}

    if coords == nil then
		coords = GetEntityCoords(PlayerPedId())
    end
    if distance == nil then
        distance = 5.0
    end
    for _, player in pairs(players) do
		local target = GetPlayerPed(player)
		local targetCoords = GetEntityCoords(target)
		local targetdistance = GetDistanceBetweenCoords(targetCoords, coords.x, coords.y, coords.z, true)
		if targetdistance <= distance then
			table.insert(closePlayers, player)
		end
    end
    
    return closePlayers
end