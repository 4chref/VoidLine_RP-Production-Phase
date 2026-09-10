AdminPanel = { -- This should not need saying, but do not mess with these unless you know what you"re doing.
    PlayerBlips = {},
    PlayerBlipsOnline = {},
    NameTags = {},
    NamesThreadRunning = false,
    AdminDutyTags = {},
    ServerInformation = {
        StaffCount = 0,
    },
    Spectating = false,
    DisplayingRadar = false,
    DisplayingBlips = false,
    DisplayingNames = false,
    FastSpeed = false,
    SpectatingPlayer = nil,
    SpectatingID = nil,
    ShowBlips = false,
    isInvisible = false,
    isFrozen = false,
    SavedCoords = nil,
    CurrentLogs = nil,
    SuperJump = false,
    NoRagdoll = false,
    GodMode = false,
    InfiniteStamina = false,
    NoClip = false,
    NewNoClip = false,
    Settings = {DarkMode = false, SeeThrough = false, Notifications = true},
}
local ShowNames = false

local AdminDuty = {
    Active = false,
    OriginalModel = nil,
    OriginalCoords = nil,
    OriginalHeading = nil,
}

CreateThread(function()
    Wait(50)
    local DM = GetResourceKvpInt("919-admin:setting:darkmode")
    if DM == 1 then DM = true elseif DM == 0 then DM = false end
    local ST = GetResourceKvpInt("919-admin:setting:seethrough")
    if ST == 1 then ST = true elseif ST == 0 then ST = false end
    local NT = GetResourceKvpInt("919-admin:setting:notifications")
    if NT == 1 then NT = true elseif NT == 0 then NT = false end
    local theme = GetResourceKvpInt("919-admin:setting:theme")
    AdminPanel.Settings = {DarkMode = DM, SeeThrough = ST, Notifications = NT, Theme = theme}
    print("Loaded panel settings!")
end)

local curLocation = {}
local curRotation = 0
local curHeading = 0


-- Function to get the player's ped name (replace with your actual function)
function GetPlayerPedName()
    local playerPed = PlayerPedId()
    return GetEntityModel(playerPed)
end

-- Register the command to open the admin panel
RegisterCommand("adminpanel", function()
    TriggerServerEvent("919-admin:server:RequestPanel")
end, false)

-- Optional: Register a key mapping for the admin panel
RegisterKeyMapping("adminpanel", "Open Admin Panel", "keyboard", Config.AdminPanelKey)  -- Replace Config.AdminPanelKey with your key configuration




-- Function to notify the player
local function notifyPlayer(message)
    TriggerEvent('QBCore:Notify', message)
end

-- Register the *noclip command
RegisterCommand("*noclip", function()
    if not AdminDuty.Active then
        notifyPlayer("You must be on duty to use NoClip.")
        return
    end
    local playerPed = PlayerPedId() -- Get the player's ped
    if not playerPed or playerPed == -1 then
        notifyPlayer("Player ped is not set or invalid.")
        return
    end
    local pedModel = GetEntityModel(playerPed) -- Get the model hash of the player's ped
    if not pedModel then
        notifyPlayer("Failed to get the model of the player's ped.")
        return
    end
    TriggerServerEvent("919-admin:server:RequestNoClip")
end, false)

-- Register a key mapping for the *noclip command
RegisterKeyMapping("*noclip", Lang:t("commands.noclip").."(919ADMIN)", "keyboard", Config.NoClipKey)


-- Function to notify the player
local function notifyPlayer(message)
    TriggerEvent('QBCore:Notify', message)
end

-- Register the *showNames command
RegisterCommand("*showNames", function()
    if not AdminDuty.Active then
        notifyPlayer("You must be on duty to see names.")
        return
    end
    local playerPed = PlayerPedId() -- Get the player's ped
    if not playerPed or playerPed == -1 then
        notifyPlayer("Player ped is not set or invalid.")
        return
    end
    
    local pedModel = GetEntityModel(playerPed) -- Get the model hash of the player's ped
    if not pedModel then
        notifyPlayer("Failed to get the model of the player's ped.")
        return
    end



    -- If we reach here, the player's ped is Naruto
    if Config.EnableNames then
        if not Config.AllPlayersUseNames then
            Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
                AdminPanel.DisplayingNames = not AdminPanel.DisplayingNames
                if AdminPanel.DisplayingNames then
                    ShowNames = true
                    toggleNames()
                    -- TriggerServerEvent("919-admin:server:GetPlayersForBlips")
                else
                    ShowNames = false
                    toggleNames()
                    -- TriggerServerEvent("919-admin:server:GetPlayersForBlips")
                end
            end, "playernames")
        else
            AdminPanel.DisplayingNames = not AdminPanel.DisplayingNames
            if AdminPanel.DisplayingNames then
                ShowNames = true
                toggleNames()
                -- TriggerServerEvent("919-admin:server:GetPlayersForBlips")
            else
                ShowNames = false
                toggleNames()
                -- TriggerServerEvent("919-admin:server:GetPlayersForBlips")
            end
        end
    end
end, false)
RegisterKeyMapping("*showNames", Lang:t("commands.showNames").."(919ADMIN)", "keyboard", Config.ShowNamesKey)

if Config.EnableReportCommand then
    RegisterCommand(Config.ReportCommand, function()
        SendNUIMessage({
            action = "reportscreen",
            Translation = json.encode(Translations.html),
        })
        SetNuiFocus(true, true)
    end, false)
end

RegisterNetEvent("919-admin:client:ToggleNoClip", function()
    if Config.NoClipType == 2 then
        local x, y, z = table.unpack(GetEntityCoords(PlayerPedId(), false))
        curLocation = { x = x, y = y, z = z }
        curRotation = GetEntityRotation(playerPed, false)
        curHeading = GetEntityHeading(playerPed)
        AdminPanel.NoClip = not AdminPanel.NoClip
        NoClip(AdminPanel.NoClip)
    elseif Config.NoClipType == 1 then
        AdminPanel.NewNoClip = not AdminPanel.NewNoClip
        toggleFreecam(AdminPanel.NewNoClip, AdminPanel.isInvisible)
    elseif Config.NoClipType == 3 then
        AdminPanel.NewNoClip = not AdminPanel.NewNoClip
        ToggleNoClip(AdminPanel.NewNoClip)
    end
    if AdminPanel.NewNoClip or AdminPanel.NoClip then
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong>"..Lang:t("alerts.noclipEnabled"))
    else
        TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong>"..Lang:t("alerts.noclipDisabled"))
    end
    AdminDutyUpdateTag()
end)

-- Admin duty tags visible to all clients
RegisterNetEvent("919-admin:client:AdminDutyTag", function(targetId, show, text)
    local playerIdx = GetPlayerFromServerId(targetId)
    if playerIdx == -1 then
        return
    end
    local ped = GetPlayerPed(playerIdx)
    if not DoesEntityExist(ped) then
        return
    end

    local existing = AdminPanel.AdminDutyTags[targetId]

    if show then
        if not existing or not DoesEntityExist(existing.ped) then
            local tagHandle = CreateFakeMpGamerTag(ped, text or "", false, false, "", false)
            SetMpGamerTagAlpha(tagHandle, 0, 255)
            SetMpGamerTagVisibility(tagHandle, 0, true)
            SetMpGamerTagVisibility(tagHandle, 2, false)
            SetMpGamerTagVisibility(tagHandle, 4, false)
            SetMpGamerTagVisibility(tagHandle, 6, false)
            AdminPanel.AdminDutyTags[targetId] = { handle = tagHandle, ped = ped, text = text or "", show = true }
        else
            -- refresh visibility
            SetMpGamerTagVisibility(existing.handle, 0, true)
            SetMpGamerTagVisibility(existing.handle, 2, false)
            SetMpGamerTagVisibility(existing.handle, 4, false)
            SetMpGamerTagVisibility(existing.handle, 6, false)
            existing.text = text or existing.text or ""
            existing.show = true
        end
    else
        if existing and existing.handle then
            RemoveMpGamerTag(existing.handle)
        end
        AdminPanel.AdminDutyTags[targetId] = { show = false }
    end
end)

-- Keep admin tags alive / refreshed
CreateThread(function()
    while true do
        for targetId, data in pairs(AdminPanel.AdminDutyTags) do
            if data.show then
                local playerIdx = GetPlayerFromServerId(targetId)
                if playerIdx == -1 then
                    if data.handle then RemoveMpGamerTag(data.handle) end
                    AdminPanel.AdminDutyTags[targetId] = nil
                else
                    local ped = GetPlayerPed(playerIdx)
                    if not DoesEntityExist(ped) then
                        if data.handle then RemoveMpGamerTag(data.handle) end
                        AdminPanel.AdminDutyTags[targetId] = nil
                    else
                        if not data.handle or not DoesEntityExist(data.ped) or data.ped ~= ped then
                            if data.handle then RemoveMpGamerTag(data.handle) end
                            local tagHandle = CreateFakeMpGamerTag(ped, data.text or "", false, false, "", false)
                            SetMpGamerTagAlpha(tagHandle, 0, 255)
                            SetMpGamerTagVisibility(tagHandle, 0, true)
                            SetMpGamerTagVisibility(tagHandle, 2, false)
                            SetMpGamerTagVisibility(tagHandle, 4, false)
                            SetMpGamerTagVisibility(tagHandle, 6, false)
                            data.handle = tagHandle
                            data.ped = ped
                        else
                            SetMpGamerTagVisibility(data.handle, 0, true)
                            SetMpGamerTagVisibility(data.handle, 2, false)
                            SetMpGamerTagVisibility(data.handle, 4, false)
                            SetMpGamerTagVisibility(data.handle, 6, false)
                        end
                    end
                end
            else
                -- no-show: clean up if handle exists
                if data.handle then
                    RemoveMpGamerTag(data.handle)
                end
                if not data.text then
                    AdminPanel.AdminDutyTags[targetId] = nil
                end
            end
        end
        Wait(500)
    end
end)

-- Periodically sync own duty tag state
CreateThread(function()
    while true do
        if AdminDuty and AdminDuty.Active then
            AdminDutyUpdateTag()
        end
        Wait(5000)
    end
end)

RegisterNetEvent("919-admin:client:OpenMenu")
-- VoidLine 2026-09-02: added `allowedActions` (a set of every permission
-- string the player's real role has, see server/main.lua's OpenPanel) so the
-- NUI can grey out/disable buttons the role doesn't have -- forwarded
-- straight through to script.js alongside the existing hasPerms/Role fields,
-- which keep working exactly as before.
AddEventHandler("919-admin:client:OpenMenu", function(playerList, ServerInformation, MaxPlayers, Version, hasPerms, Role, allowedActions)
    SendNUIMessage({
        action = "open",
        name = GetPlayerName(PlayerId()),
        playerlist = playerList,
        darkmode = AdminPanel.Settings.DarkMode,
        seethrough = AdminPanel.Settings.SeeThrough,
        Notifications = AdminPanel.Settings.Notifications,
        Theme = AdminPanel.Settings.Theme,
        serverData = ServerInformation,
        maxplayers = MaxPlayers,
        version = Version,
        hasPerms = hasPerms,
        Translation = json.encode(Translations.html),
        Framework = "Custom 919",
        Role = Role,
        allowedActions = allowedActions
    })
    SetNuiFocus(true,true)
end)


RegisterNetEvent("919-admin:client:RefreshMenu", function(playerList, silent)
    SendNUIMessage({
        action = "refresh",
        name = GetPlayerName(PlayerId()),
        playerlist = playerList,
        serverData = AdminPanel.ServerInformation,
    })
    if not silent then
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.playerListRefreshed"))
    end
end)

RegisterNetEvent("919-admin:client:ViewPlayer", function(online, playerData)
    if online then
        SendNUIMessage({
            action = "viewonlineplayer",
            playerid = playerData
        })
        DebugTrace("NUIMessage: viewonlineplayer")
    else
        SendNUIMessage({
            action = "viewofflineplayer",
            playerdata = playerData
        })
        DebugTrace("NUIMessage: viewofflineplayer")
    end
    DebugTrace("Received player data. Online: "..(online and "yes" or "no"))
end)

RegisterNetEvent("919-admin:client:ResetMenu", function()
    SendNUIMessage({
        action = "noperms"
    })
end)

RegisterNetEvent("919-admin:client:WarnPlayer", function(warnedBy, reason)
    SendNUIMessage({
        action = "showwarning",
        by = warnedBy,
        reason = reason
    })
    SetNuiFocus(true, true)
    FreezeEntityPosition(PlayerPedId(), true)
end)

RegisterNUICallback("GiveItem", function(data)
    TriggerServerEvent("919-admin:server:GiveItem", data.Id, data.Item, data.Amount)
end)

RegisterNUICallback("SpawnVehicle", function(data)
    TriggerServerEvent("919-admin:server:RequestVehicleSpawn", data.Vehicle)
end)

RegisterNUICallback("ReportReply", function(data)
    if data ~= nil then
        TriggerServerEvent("919-admin:server:ReportReply", data)
    end
end)

RegisterNUICallback("ExitWarn", function()
    SetNuiFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
end)

RegisterNetEvent("919-admin:client:ShowPanelAlert", function(type, text)
    if type == "success" then 
        PlaySoundFrontend(-1, "Confirm", "GTAO_Exec_SecuroServ_Warehouse_PC_Sounds", true)
    elseif type == "danger" or type == "warning" or type == "error" then
        PlaySoundFrontend(-1, "Cancel", "GTAO_Exec_SecuroServ_Warehouse_PC_Sounds", true)
    end
    SendNUIMessage({
        action = "showalert",
        type = type,
        text = text
    })
end)

RegisterNetEvent("919-admin:client:ShowReportAlert", function(title, text)
    PlaySoundFrontend(-1, "Cancel", "GTAO_Exec_SecuroServ_Warehouse_PC_Sounds", true)
    SendNUIMessage({
        action = "showreportalert",
        title = title,
        text = text
    })
end)

RegisterNetEvent("919-admin:client:ForceReloadResources", function()
    TriggerServerEvent("919-admin:server:RequestResourcePageInfo")
end)

RegisterNetEvent("919-admin:client:ReceiveJobPageInfo", function(JobPageInfo)
    DebugTrace("Received job page info")
    SendNUIMessage({
        action = "jobinfo",
        jobinfo = JobPageInfo,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveGangPageInfo", function(GangPageInfo)
    DebugTrace("Received gang page info")
    SendNUIMessage({
        action = "ganginfo",
        ganginfo = GangPageInfo,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveResourcePageInfo", function(ResourcePageInfo)
    DebugTrace("Received resource page info")
    SendNUIMessage({
        action = "resourceinfo",
        resourceinfo = ResourcePageInfo,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveBansInfo", function(BansInfo)
    DebugTrace("Received bans page info")
    SendNUIMessage({
        action = "bansinfo",
        bansinfo = BansInfo,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveReportsInfo", function(ReportsInfo)
    DebugTrace("Received reports page info")
    SendNUIMessage({
        action = "reportsinfo",
        reportsinfo = ReportsInfo,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveAdminChat", function(AdminChat)
    DebugTrace("Received admin chat")
    SendNUIMessage({
        action = "adminchat",
        adminchat = AdminChat,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveVehiclesInfo", function(VehiclesInfo)
    DebugTrace("Received vehicles page info")
    SendNUIMessage({
        action = "vehiclesinfo",
        vehiclesinfo = VehiclesInfo,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveLeaderboardInfo", function(money, vehicles)
    DebugTrace("Received leaderboard page info")
    SendNUIMessage({
        action = "leaderboardinfo",
        money = money,
        vehicles = vehicles,
    })
end)

RegisterNetEvent("919-admin:client:ReceiveItemsInfo", function(ItemsInfo)
    DebugTrace("Received items page info")
    SendNUIMessage({
        action = "itemsinfo",
        itemsinfo = ItemsInfo,
    })
end)


RegisterNetEvent("919-admin:client:ReceiveCharacters", function(players)
    DebugTrace("Received characters page info")
    SendNUIMessage({
        action = "characterslist",
        characters = players
    })
end)

RegisterNetEvent("919-admin:client:ReceiveCurrentLogs", function(currentLogs)
    AdminPanel.CurrentLogs = currentLogs
    SendNUIMessage({
        action = "logslist",
        logs = AdminPanel.CurrentLogs
    })
end)

RegisterNetEvent("919-admin:client:ToggleBlips", function()
    --COME BACK HERE
end)

RegisterNetEvent("919-admin:client:ViewWarnings", function(warnings)
    DebugTrace("[919-admin:client:ViewWarnings] Received warnings")
    SendNUIMessage({
        action = "viewwarnings",
        warnings = warnings,
    })
end)

RegisterNetEvent("919-admin:client:SetPedModel", function(model)
    if model then
        Citizen.CreateThread(function()
            model = GetHashKey(model)
            RequestModel(model)
            while not HasModelLoaded(model) do
                RequestModel(model)
                Citizen.Wait(0)
            end
            SetPlayerModel(PlayerId(), model)
            SetPedComponentVariation(PlayerPedId(), 0, 0, 0, 2)
        end)
    end
end)

RegisterNetEvent("919-admin:client:DeleteAllEntities", function(entityType)
    if entityType == 1 then
        for vehicle in EnumerateVehicles() do
            if (not IsPedAPlayer(GetPedInVehicleSeat(vehicle, -1))) then 
                SetVehicleHasBeenOwnedByPlayer(vehicle, false) 
                SetEntityAsMissionEntity(vehicle, false, false) 
                DeleteVehicle(vehicle)
                if (DoesEntityExist(vehicle)) then 
                    DeleteVehicle(vehicle) 
                end
            end
        end
    elseif entityType == 2 then
        for ped in EnumeratePeds() do
            if (not IsPedAPlayer(ped)) then 
                SetEntityAsMissionEntity(ped, false, false) 
                DeleteEntity(ped)
                if (DoesEntityExist(ped)) then 
                    DeleteEntity(ped) 
                end
            end
        end
    elseif entityType == 3 then
        for object in EnumerateObjects() do
            SetEntityAsMissionEntity(object, false, false) 
            DeleteEntity(object)
            if (DoesEntityExist(object)) then 
                DeleteEntity(object) 
            end
        end
    end
end)

RegisterNetEvent("919-admin:client:RequestSpectate", function(playerServerId, tgtCoords, name)
	local localPlayerPed = PlayerPedId()
    AdminPanel.SpectatingPlayer = name
    AdminPanel.SpectatingID = playerServerId
    if playerServerId == -1 then 
        AdminPanel.SpectatePlayer(-1,-1,"")
    else
        if ((not tgtCoords) or (tgtCoords.z == 0.0)) then tgtCoords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(playerServerId))) end
        if playerServerId == GetPlayerServerId(PlayerId()) then 
            if AdminPanel.SavedCoords then
                RequestCollisionAtCoord(AdminPanel.SavedCoords.x, AdminPanel.SavedCoords.y, AdminPanel.SavedCoords.z)
                Wait(500)
                SetEntityCoords(playerPed, AdminPanel.SavedCoords.x, AdminPanel.SavedCoords.y, AdminPanel.SavedCoords.z, 0, 0, 0, false)
                AdminPanel.SavedCoords = nil
            end
            AdminPanel.SpectatePlayer(GetPlayerPed(PlayerId()),GetPlayerFromServerId(PlayerId()),GetPlayerName(PlayerId()))
            return
        else
            if not AdminPanel.SavedCoords then
                AdminPanel.SavedCoords = GetEntityCoords(PlayerPedId())
            end
        end
        SetEntityCoords(localPlayerPed, tgtCoords.x, tgtCoords.y, tgtCoords.z - 10.0, 0, 0, 0, false)
        local adminPed = localPlayerPed
        local playerId = GetPlayerFromServerId(playerServerId)
        repeat
            Wait(200)
            playerId = GetPlayerFromServerId(playerServerId)
        until ((GetPlayerPed(playerId) > 0) and (playerId ~= -1))
        AdminPanel.SpectatePlayer(GetPlayerPed(playerId),playerId,GetPlayerName(playerId))
    end
end)

RegisterNetEvent("919-admin:client:RequestInventory", function(TargetId)
    Compat.OpenInventory(TargetId)
end)
  
RegisterNetEvent("919-admin:client:setLivery", function(livery)
    local Veh = GetVehiclePedIsIn(PlayerPedId())
    if Veh then
        SetVehicleLivery(Veh, livery)
    end
end)

RegisterNetEvent("919-admin:client:SetPosition", function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z)
end)

RegisterNetEvent("919-admin:client:Freeze", function()
    AdminPanel.isFrozen = not AdminPanel.isFrozen
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)

    if veh ~= 0 then
        FreezeEntityPosition(ped, AdminPanel.isFrozen)
        FreezeEntityPosition(veh, AdminPanel.isFrozen)
    else
        FreezeEntityPosition(ped, AdminPanel.isFrozen)
    end
end)

RegisterNetEvent("919-admin:client:SendReport", function(name, src, msg, subject)
    TriggerServerEvent("919-admin:server:SendReport", name, src, msg, subject)
end)

RegisterNetEvent("919-admin:client:SaveCar", function(senderId)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)

    if veh ~= nil and veh ~= 0 then
        local plate = QBCore.Functions.GetPlate(veh)
        local props = QBCore.Functions.GetVehicleProperties(veh)
        local hash = props.model
        local vehname = GetDisplayNameFromVehicleModel(hash):lower()
        if QBCore.Shared.Vehicles[vehname] ~= nil and next(QBCore.Shared.Vehicles[vehname]) ~= nil then
            TriggerServerEvent("919-admin:server:SaveCar", props, QBCore.Shared.Vehicles[vehname], `veh`, plate, senderId)
        else
            QBCore.Functions.Notify(Lang:t("notify.cantStoreVehicle"), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t("notify.notInVehicle"), "error")
    end
end)

RegisterNetEvent("919-admin:client:SetModel", function(skin)
    local ped = PlayerPedId()
    local model = GetHashKey(skin)

    SetEntityInvincible(ped, true)

    if IsModelInCdimage(model) and IsModelValid(model) then
        RequestModel(model)
        repeat Wait(0) until HasModelLoaded(model)
        SetPlayerModel(PlayerId(), model)

        if isPedAllowedRandom() then
            SetPedRandomComponentVariation(ped, true)
            SetPedDefaultComponentVariation(ped)
        end
        
		SetModelAsNoLongerNeeded(model)
	end
	SetEntityInvincible(ped, false)
end)

RegisterNetEvent("919-admin:client:MassDespawn", function ()
    for vehicle in EnumerateVehicles() do
        if (not IsPedAPlayer(GetPedInVehicleSeat(vehicle, -1))) then 
            SetVehicleHasBeenOwnedByPlayer(vehicle, false) 
            SetEntityAsMissionEntity(vehicle, false, false) 
            DeleteVehicle(vehicle)
            if (DoesEntityExist(vehicle)) then 
                DeleteVehicle(vehicle) 
            end
        end
    end
end)

RegisterNetEvent("919-admin:client:MassPedDespawn", function ()
    for ped in EnumeratePeds() do
        if (not IsPedAPlayer(ped)) then 
            SetEntityAsMissionEntity(ped, false, false) 
            DeleteEntity(ped)
            if (DoesEntityExist(ped)) then 
                DeleteEntity(ped) 
            end
        end
    end
end)

RegisterNetEvent("919-admin:client:MassObjDespawn", function ()
    for object in EnumerateObjects() do
        if (IsEntityAnObject(object)) then 
            SetEntityAsMissionEntity(object, false, false) 
            DeleteEntity(object)
            if (DoesEntityExist(object)) then 
                DeleteEntity(object) 
            end
        end
    end
end)

RegisterNetEvent("919-admin:client:MassEverythingDespawn", function ()
    for entity in EnumerateEntities() do
        if (IsEntityAPed(entity)) then 
            if not IsPedAPlayer(entity) then
                SetEntityAsMissionEntity(entity, false, false) 
                DeleteEntity(entity)
                if (DoesEntityExist(entity)) then 
                    DeleteEntity(entity) 
                end
            end
        else
            SetEntityAsMissionEntity(entity, false, false) 
            DeleteEntity(entity)
            if (DoesEntityExist(entity)) then 
                DeleteEntity(entity) 
            end
        end
    end
end)

RegisterNetEvent("919-admin:client:SetNuiFocus", function(focus, mouse)
    SetNuiFocus(focus, mouse)
end)

RegisterNetEvent("919-admin:client:ReceiveServerMetrics", function(serverMetrics)
    DebugTrace("Received server metrics")
    SendNUIMessage({
        action = "servermetrics",
        metrics = serverMetrics,
    })
end)

---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------

RegisterNUICallback("close", function()
    SetNuiFocus(false, false)
    TriggerServerEvent("919-admin:server:ClosePanel")
    DebugTrace("NUICallback: close")
end)

RegisterNUICallback("LoadJobInfo", function()
    TriggerServerEvent("919-admin:server:RequestJobPageInfo")
    DebugTrace("NUICallback: LoadJobInfo")
end)

RegisterNUICallback("LoadGangInfo", function()
    TriggerServerEvent("919-admin:server:RequestGangPageInfo")
    DebugTrace("NUICallback: LoadGangInfo")
end)

RegisterNUICallback("LoadResourcesInfo", function()
    TriggerServerEvent("919-admin:server:RequestResourcePageInfo")
    DebugTrace("NUICallback: LoadResourcesInfo")
end)

RegisterNUICallback("LoadServerMetrics", function()
    TriggerServerEvent("919-admin:server:RequestServerMetrics")
    DebugTrace("NUICallback: LoadServerMetrics")
end)

RegisterNUICallback("LoadBansInfo", function()
    TriggerServerEvent("919-admin:server:RequestBansInfo")
    DebugTrace("NUICallback: LoadBansInfo")
end)

RegisterNUICallback("LoadReportsInfo", function()
    TriggerServerEvent("919-admin:server:RequestReportsInfo")
    DebugTrace("NUICallback: LoadReportsInfo")
end)

RegisterNUICallback("LoadAdminChat", function()
    TriggerServerEvent("919-admin:server:RequestAdminChat")
    DebugTrace("NUICallback: LoadAdminChat")
end)

RegisterNUICallback("AdminChatSend", function(info)
    TriggerServerEvent("919-admin:server:AdminChatSend", info["message"])
    DebugTrace("NUICallback: AdminChatSend")
end)

RegisterNUICallback("LoadItemsInfo", function()
    TriggerServerEvent("919-admin:server:RequestItemsInfo")
    DebugTrace("NUICallback: LoadItemsInfo")
end)

RegisterNUICallback("LoadVehiclesInfo", function()
    TriggerServerEvent("919-admin:server:RequestVehiclesInfo")
    DebugTrace("NUICallback: LoadVehiclesInfo")
end)

RegisterNUICallback("LoadLeaderboardInfo", function()
    TriggerServerEvent("919-admin:server:RequestLeaderboardInfo")
    DebugTrace("NUICallback: LoadLeadeaderboardInfo")
end)

RegisterNUICallback("LoadLogs", function()
    TriggerServerEvent("919-admin:server:RequestCurrentLogs")
    DebugTrace("NUICallback: LoadLogs")
end)

RegisterNUICallback("LoadCharacters", function()
    TriggerServerEvent("919-admin:server:RequestCharacters")
    DebugTrace("NUICallback: LoadCharacters")
end)

RegisterNUICallback("RequestViewPlayer", function(player)
    TriggerServerEvent("919-admin:server:RequestViewPlayer", player)
    DebugTrace("NUICallback: RequestViewPlayer")
end)

RegisterNUICallback("SendReport", function(info)
    TriggerServerEvent("919-admin:server:SendReport", info["subject"], info["info"], info["type"])
    DebugTrace("NUICallback: SendReport")
end)

RegisterNUICallback("ResourceAction", function(info)
    local currentResource = info["resource"]
    if info["action"] == "start" or info["action"] == "stop" or info["action"] == "restart" then
        TriggerServerEvent("919-admin:server:ResourceAction", currentResource, info["action"])
    end
    DebugTrace("NUICallback: ResourceAction ["..info["action"].."]")
end)

RegisterNetEvent("919-admin:client:OpenSkinMenu1", function()
    if Config.ESXSkin == "AK" then
        exports["ak47_clothing"]:openOutfitMenu()
    else
        TriggerEvent("esx_skin:openRestrictedMenu", function(data, menu)
            menu.close()
    
            ESX.UI.Menu.Open("default", GetCurrentResourceName(), "shop_confirm", {
                title = "Validate this purchase!",
                align = "top-left",
                elements = {
                    {label = "No", value = "no"},
                    {label = "Yes", value = "yes"}
            }}, function(data, menu)
                menu.close()
    
                if data.current.value == "yes" then
                    ESX.TriggerServerCallback("esx_clotheshop:buyClothes", function(bought)
                        if bought then
                            TriggerEvent("skinchanger:getSkin", function(skin)
                                TriggerServerEvent("esx_skin:save", skin)
                            end)
    
                            hasPaid = true
    
                            ESX.TriggerServerCallback("esx_clotheshop:checkPropertyDataStore", function(foundStore)
                                if foundStore then
                                    ESX.UI.Menu.Open("default", GetCurrentResourceName(), "save_dressing", {
                                        title = "Save in dressing",
                                        align = "top-left",
                                        elements = {
                                            {label = "No",  value = "no"},
                                            {label = "Yes", value = "yes"}
                                    }}, function(data2, menu2)
                                        menu2.close()
    
                                        if data2.current.value == "yes" then
                                            ESX.UI.Menu.Open("dialog", GetCurrentResourceName(), "outfit_name", {
                                                title = "Outfit name"
                                            }, function(data3, menu3)
                                                menu3.close()
    
                                                TriggerEvent("skinchanger:getSkin", function(skin)
                                                    TriggerServerEvent("esx_clotheshop:saveOutfit", data3.value, skin)
                                                    ESX.ShowNotification("Saved outfit")
                                                end)
                                            end, function(data3, menu3)
                                                menu3.close()
                                            end)
                                        end
                                    end)
                                end
                            end)
    
                        else
                            ESX.TriggerServerCallback("esx_skin:getPlayerSkin", function(skin)
                                TriggerEvent("skinchanger:loadSkin", skin)
                            end)
    
                            ESX.ShowNotification("Not enough money!")
                        end
                    end)
                elseif data.current.value == "no" then
                    ESX.TriggerServerCallback("esx_skin:getPlayerSkin", function(skin)
                        TriggerEvent("skinchanger:loadSkin", skin)
                    end)
                end
    
                currentAction     = "shop_menu"
                currentActionMsg  = "Press the menu"
                currentActionData = {}
            end, function(data, menu)
                menu.close()
    
                currentAction     = "shop_menu"
                currentActionMsg  = "Press the menu"
                currentActionData = {}
            end)
    
        end, function(data, menu)
            menu.close()
    
            currentAction     = "shop_menu"
            currentActionMsg  = "Press the menu"
            currentActionData = {}
        end, {
            "tshirt_1", "tshirt_2",
            "torso_1", "torso_2",
            "decals_1", "decals_2",
            "arms",	"arms_2",
            "pants_1", "pants_2",
            "shoes_1", "shoes_2",
            "bags_1", "bags_2",
            "chain_1", "chain_2",
            "helmet_1", "helmet_2",
            "glasses_1", "glasses_2"
        })
    end
end)

RegisterNUICallback("Action", function(info)
    local currentPlayer = info["id"]
    if info["action"] == "uncuffSelf" then
        Compat.UncuffSelf()
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.uncuffed"))
    elseif info["action"] == "revive" then
        TriggerServerEvent("919-admin:server:RevivePlayer", currentPlayer)
    elseif info["action"] == "goto" then
        TriggerServerEvent("919-admin:server:GotoPlayer", currentPlayer)
    elseif info["action"] == "bring" then
        local target = GetPlayerPed(currentPlayer)
        local plyCoords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent("919-admin:server:BringPlayer", currentPlayer, plyCoords)
    elseif info["action"] == "sendtolegion" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, 215.75, -804.26, 30.81)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.senToLegion"))
    elseif info["action"] == "sendtopillbox" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, 299.01, -577.48, 43.26)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToPillbox"))
    elseif info["action"] == "sendtolsc" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, -366.58, -126.01, 38.69)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToCustoms"))
    elseif info["action"] == "sendtomrpd" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, 415.41, -993.4, 29.38)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToMRPD"))
    elseif info["action"] == "sendtosandy" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, 1963.56, 3735.19, 32.2)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToSandy"))
    elseif info["action"] == "sendtograpeseed" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, 1692.89, 4942.49, 42.32)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToGrapeseed"))
    elseif info["action"] == "sendtopaleto" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, 125.64, 6611.6, 31.86)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToPaleto"))
    elseif info["action"] == "sendtolsia" then
        TriggerServerEvent("919-admin:server:SetPosition", currentPlayer, -1021.81, -2701.25, 13.76)
        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.sentToLSA"))
    elseif info["action"] == "kill" then
        TriggerServerEvent("919-admin:server:KillPlayer", currentPlayer)
    elseif info["action"] == "cuff" then
        TriggerServerEvent("919-admin:server:CuffPlayer", currentPlayer)
    elseif info["action"] == "save" then
        TriggerServerEvent("919-admin:server:SavePlayer", currentPlayer)
    elseif info["action"] == "clothing" then
        TriggerServerEvent("919-admin:server:OpenSkinMenu", currentPlayer)
    elseif info["action"] == "sclothing" then
        SendNUIMessage({
            action = "close"
        })
        SetNuiFocus(false, false)
        TriggerServerEvent("919-admin:server:OpenSkinMenu", GetPlayerServerId(PlayerId()))
    elseif info["action"] == "feed" then
        TriggerServerEvent("919-admin:server:FeedPlayer", currentPlayer)
        Citizen.Wait(50)
        TriggerServerEvent("919-admin:server:RefreshMenu", true)
    elseif info["action"] == "stress" then
        TriggerServerEvent("919-admin:server:RelieveStress", currentPlayer)
        Citizen.Wait(50)
        TriggerServerEvent("919-admin:server:RefreshMenu", true)
    elseif info["action"] == "openinv" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            SendNUIMessage({
                action = "close"
            })
            SetNuiFocus(false, false)
            TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.openingPlayerInv"))
            TriggerEvent("919-admin:client:RequestInventory", currentPlayer)
        end, "openinventory")
    elseif info["action"] == "clearinv" then
        TriggerServerEvent("919-admin:server:ClearInventory", currentPlayer)
    elseif info["action"] == "screenshot" then
        TriggerServerEvent("919-admin:server:ScreenshotSubmit", currentPlayer)
    elseif info["action"] == "spectate" then
        TriggerServerEvent("919-admin:server:RequestSpectate", currentPlayer)
        SendNUIMessage({
            action = "close"
        })
        SetNuiFocus(false, false)
    elseif info["action"] == "freeze" then
        TriggerServerEvent("919-admin:server:Freeze", currentPlayer)
    elseif info["action"] == "revives" then
        TriggerServerEvent("919-admin:server:RevivePlayer", GetPlayerServerId(PlayerId()))
    elseif info["action"] == "sendback" then
        TriggerServerEvent("919-admin:server:SendPlayerBack", currentPlayer)
    elseif info["action"] == "goback" then
        TriggerServerEvent("919-admin:server:SendBackSelf")
    elseif info["action"] == "tpm" then
        if IsWaypointActive() then
            local WaypointHandle = GetFirstBlipInfoId(8)

            if DoesBlipExist(WaypointHandle) then
                local waypointCoords = GetBlipInfoIdCoord(WaypointHandle)

                for height = 1, 1000 do
                    SetPedCoordsKeepVehicle(PlayerPedId(), waypointCoords["x"], waypointCoords["y"], height + 0.0)

                    local foundGround, zPos = GetGroundZFor_3dCoord(waypointCoords["x"], waypointCoords["y"], height + 0.0)

                    if foundGround then
                        SetPedCoordsKeepVehicle(PlayerPedId(), waypointCoords["x"], waypointCoords["y"], height + 0.0)

                        break
                    end

                    Citizen.Wait(5)
                end
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.tpm"))
            else
                ESX.ShowNotification("Select Waypoint")
            end
        else
            TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.error").."</strong> "..Lang:t("alerts.noMarker"))
        end
    elseif info["action"] == "setpedmodel" then
        if info["model"] then
            TriggerServerEvent("919-admin:server:SetPedModel", currentPlayer, info["model"])
        end
    elseif info["action"] == "invisible" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if not AdminPanel.isInvisible then
                SetEntityVisible(PlayerPedId(), false, false)
                AdminPanel.isInvisible = true
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.invis"))
            else
                SetEntityVisible(PlayerPedId(), true, false)
                AdminPanel.isInvisible = false
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.vis"))
            end
        end, "invisibility")
    elseif info["action"] == "togradar" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.DisplayingRadar = not AdminPanel.DisplayingRadar
            if AdminPanel.DisplayingRadar then
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.radarOn"))
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.radarOff"))
            end
        end, "forceradar")
    elseif info["action"] == "togblips" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.DisplayingBlips = not AdminPanel.DisplayingBlips
            if AdminPanel.DisplayingBlips then
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.blipsOn"))
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.blipsOff"))
            end
        end, "playerblips")
    elseif info["action"] == "tognames" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.DisplayingNames = not AdminPanel.DisplayingNames
            if AdminPanel.DisplayingNames then
                ShowNames = true
                -- TriggerServerEvent("919-admin:server:GetPlayersForBlips")
                toggleNames()
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.NamesOn"))
            else
                ShowNames = false
                -- TriggerServerEvent("919-admin:server:GetPlayersForBlips")
                toggleNames()
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.NamesOff"))
            end
        end, "playernames") -- VoidLine 2026-09-02: was "playerblips" -- copy/paste bug meant "playernames" (present in Config.Permissions) was never actually checked anywhere
    elseif info["action"] == "togspeed" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.FastSpeed = not AdminPanel.FastSpeed
            if AdminPanel.FastSpeed then
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
                SetSwimMultiplierForPlayer(PlayerId(), 1.49)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.RunOn"))
            else
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
                SetSwimMultiplierForPlayer(PlayerId(), 1.0)
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.RunOff"))
            end
        end, "fastrun")
    elseif info["action"] == "god" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if not AdminPanel.GodMode then
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.GodOn"))
                godModeChange()
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.GodOff"))
                godModeChange()
            end
        end, "godmode")
    elseif info["action"] == "setmedriver" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                if IsVehicleSeatFree(vehicle,-1) then
                    SetPedIntoVehicle(PlayerPedId(),vehicle,-1)
                    TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.EnterVehicle"))
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong> "..Lang:t("alerts.VehicleFull"))
                end
            end
        end, "setmedriver")
    elseif info["action"] == "setmepass" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                if seat == nil then
                    seat = 0 
                elseif tonumber(seat) == 3 then
                    seat = 1
                elseif tonumber(seat) == 4 then
                    seat = 2
                end
                if IsVehicleSeatFree(vehicle,seat) then
                    SetPedIntoVehicle(PlayerPedId(),vehicle,seat)
                    TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong> "..Lang:t("alerts.EnterVehicle"))
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong> "..Lang:t("alerts.VehicleFull"))
                end
            end
        end, "setmepassenger")
    elseif info["action"] == "clearblood" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            ClearPedBloodDamage(PlayerPedId())
            TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.bloodCleared"))
        end, "clearblood")
    elseif info["action"] == "wetclothes" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            SetPedWetnessHeight(PlayerPedId(), 2.0)
            TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.clothesWet"))
        end, "wetclothes")
    elseif info["action"] == "dryclothes" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            ClearPedWetness(PlayerPedId())
            TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.clothesDry"))
        end, "dryclothes")
    elseif info["action"] == "deleteclosestveh" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local entity, distance = Compat.GetClosestVehicle()
            if entity then
                if distance < 10.0 then
                    AdminPanel.DeleteEntity(entity)
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.vehicleFar"))
                end
            end
        end, "deleteclosestvehicle")
    elseif info["action"] == "deleteclosestped" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local entity, distance = AdminPanel.GetClosestPedNotPlayer()
            if entity then
                if not IsPedAPlayer(entity) then
                    if distance < 10.0 then
                        AdminPanel.DeleteEntity(entity)
                    else
                        TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.pedFar"))
                    end
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.pedIsPlayer"))
                end
            end
        end, "deleteclosestped")
    elseif info["action"] == "deleteclosestobj" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local entity, distance = Compat.GetClosestObject()
            if entity then
                if distance < 10.0 then                
                    AdminPanel.DeleteEntity(entity)
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.objectFar"))
                end
            end
        end, "deleteclosestobject")
    elseif info["action"] == "repairv" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                SetVehicleUndriveable(vehicle, false)
                SetVehicleBodyHealth(vehicle, 1000)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleEngineHealth(vehicle, 1000)
                SetVehicleEngineOn(vehicle, true, true)
                SetVehicleFixed(vehicle)
                SetVehicleOnGroundProperly(vehicle)
                SetVehicleGravity(vehicle, true)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.repairedVehicle"))
            end
        end, "repairvehicle")
    elseif info["action"] == "wash" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                SetVehicleDirtLevel(vehicle, 0)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.washedVehicle"))
            end
        end, "washvehicle")
    elseif info["action"] == "hotwire" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = GetVehiclePedIsIn(PlayerPedId())
            if vehicle then
                exports["qb-vehiclekeys"]:SetVehicleKey(GetVehicleNumberPlateText(vehicle), true)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.hotwireVehicle"))
            end
        end, "hotwirevehicle")
    elseif info["action"] == "lockv" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                SetVehicleDoorsLocked(vehicle, 2)
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.lockedVehicle"))
            end
        end, "lockvehicle")
    elseif info["action"] == "unlockv" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                SetVehicleDoorsLocked(vehicle, 1)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.lockedVehicle"))
            end
        end, "unlockvehicle")
    elseif info["action"] == "spawnvehicle" then
        if info["model"] then
            SendNUIMessage({
                action = "close"
            })
            SetNuiFocus(false, false)
            TriggerServerEvent("919-admin:server:RequestVehicleSpawn", info["model"])
        end
    elseif info["action"] == "maxpupgrades" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle then
                SetVehicleModKit(vehicle, 0)
                SetVehicleMod(vehicle, 11, GetNumVehicleMods(vehicle, 11) - 1, false)
                SetVehicleMod(vehicle, 12, GetNumVehicleMods(vehicle, 12) - 1, false)
                SetVehicleMod(vehicle, 13, GetNumVehicleMods(vehicle, 13) - 1, false)
                SetVehicleMod(vehicle, 15, GetNumVehicleMods(vehicle, 15) - 2, false)
                SetVehicleMod(vehicle, 16, GetNumVehicleMods(vehicle, 16) - 1, false)
                ToggleVehicleMod(vehicle, 17, true)
                ToggleVehicleMod(vehicle, 18, true)
                ToggleVehicleMod(vehicle, 19, true)
                ToggleVehicleMod(vehicle, 21, true)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.vehicleMaxPerformance"))
                SendNUIMessage({
                    action = "close"
                })
                SetNuiFocus(false, false)
            end
        end, "maxperformanceupgrades")
    elseif info["action"] == "randvisualparts" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle, distance = Compat.GetClosestVehicle()
            if vehicle then
                if distance < 10.0 then
                    SetVehicleModKit(vehicle, 0)
                    for i=1, 47 do
                        SetVehicleMod(vehicle, i, math.random(1, 4), true)
                    end
                    SetVehicleMod(vehicle, 49, math.random(1, 4), true)
                    TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.vehicleRandomVisual"))
                    SendNUIMessage({
                        action = "close"
                    })
                    SetNuiFocus(false, false)
                    --PlaySoundFrontend(-1, "CONTINUE", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.vehicleFar"))
                end
            end
        end, "randomvisualparts")
    elseif info["action"] == "setlivery" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle, distance = Compat.GetClosestVehicle()
            if vehicle then
                if distance < 10.0 then
                    if info["livery"] then
                        SetVehicleModKit(vehicle, 0)
                        SetVehicleMod(vehicle, 48, tonumber(info["livery"]), true)
                        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.liverySet").." "..GetLabelText(GetLiveryName(vehicle, tonumber(info["livery"])))..".")
                        SendNUIMessage({
                            action = "close"
                        })
                        SetNuiFocus(false, false)
                    end
                else
                    TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.vehicleFar"))
                end
            end
        end, "setlivery")
    elseif info["action"] == "setcolor" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if info["primarycolor"] and info["secondarycolor"] then
                local PrimaryColor = info["primarycolor"]
                local SecondaryColor = info["secondarycolor"]
                local vehicle, distance = Compat.GetClosestVehicle()
                if vehicle then
                    if distance < 10.0 then
                        SetVehicleCustomPrimaryColour(vehicle, PrimaryColor.r, PrimaryColor.g, PrimaryColor.b)
                        SetVehicleCustomSecondaryColour(vehicle, SecondaryColor.r, SecondaryColor.g, SecondaryColor.b)
                        TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.colorSet"))
                        SendNUIMessage({
                            action = "close"
                        })
                        SetNuiFocus(false, false)
                    else
                        TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong>"..Lang:t("alerts.vehicleFar"))
                    end
                end
            end
        end, "setcolor")
    elseif info["action"] == "filltank" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local vehicle = Compat.GetClosestVehicle()
            if vehicle then
                exports[Config.FuelScript]:SetFuel(vehicle, 100)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.fuelSet"))
            end
        end, "fillgastank")
    elseif info["action"] == "kick" then       
        TriggerServerEvent("919-admin:server:KickPlayer", currentPlayer, info["reason"])
    elseif info["action"] == "warn" then       
        TriggerServerEvent("919-admin:server:WarnPlayer", currentPlayer, info["reason"], info["citizenid"])
    elseif info["action"] == "checkwarn" then
        TriggerServerEvent("919-admin:server:ViewWarnings", currentPlayer, info["citizenid"])
    elseif info["action"] == "ban" then       
        info["timeamt"] = info["timeamt"] * 60 * 60
        TriggerServerEvent("919-admin:server:BanPlayer", currentPlayer, info["timeamt"], info["reason"], info["citizenid"])
    elseif info["action"] == "givecash" or info["action"] == "removecash" or info["action"] == "givebank" or info["action"] == "removebank" then
        local cashAmount = tonumber(info["amount"])
        TriggerServerEvent("919-admin:server:MonetaryAction", currentPlayer, info["action"], cashAmount)
        Citizen.Wait(50)
        TriggerServerEvent("919-admin:server:RefreshMenu", true)
    elseif info["action"] == "settime" then
        TriggerServerEvent("919-admin:server:SetWeatherTime", info["timehour"], info["timeminute"])
    elseif info["action"] == "setjob" then
        TriggerServerEvent("919-admin:server:SetJob", currentPlayer, info["jobname"], info["jobgrade"])
        Citizen.Wait(50)
        TriggerServerEvent("919-admin:server:RefreshMenu", true)
    elseif info["action"] == "giveitem" then
        TriggerServerEvent("919-admin:server:GiveItem", currentPlayer, info["itemname"], info["itemamount"])
    elseif info["action"] == "setgang" then
        TriggerServerEvent("919-admin:server:SetGang", currentPlayer, info["gangname"], info["ganggrade"])
        Citizen.Wait(50)
        TriggerServerEvent("919-admin:server:RefreshMenu", true)
    elseif info["action"] == "loadipl" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if info["ipl"] ~= "" and info["ipl"] ~= nil then
                RequestIpl(info["ipl"])
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.iplReqested"))
            end
        end, "ipl")
    elseif info["action"] == "unloadipl" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if info["ipl"] ~= "" and info["ipl"] ~= nil then
                RemoveIpl(info["ipl"])
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.unloadIPL"))
            end
        end, "ipl")
    elseif info["action"] == "setViewDistance" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                SetEntityViewDistance(info)
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.distanceChanged"))
            end
        end, "setViewDistance")
    elseif info["action"] == "copyEntityInfo" then
        print("hi")
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            print(hasPermission)
            if hasPermission then
                print("noice")
                CopyToClipboard()
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.copied"))
            end
        end, "copyEntityInfo")
        print("no u")
    elseif info["action"] == "freeaimMode" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                ToggleEntityFreeView()
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.freeaimTog"))
            end
        end, "freeaimMode")
    elseif info["action"] == "displayVehicles" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                ToggleEntityVehicleView()
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.dispVeh"))
            end
        end, "displayVehicles")
    elseif info["action"] == "displayPeds" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                ToggleEntityPedView()
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.dispPeds"))
            end
        end, "displayPeds")
    elseif info["action"] == "displayObjects" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                ToggleEntityObjectView()
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.success").."</strong>"..Lang:t("alerts.dispEnt"))
            end
        end, "displayObjects")
    elseif info["action"] == "vec3" then
        -- VoidLine 2026-09-02: previously unguarded (Developer Actions group
        -- item with no permission check at all) -- now gated like its siblings.
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local Position = GetEntityCoords(PlayerPedId())
            local InVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
            if InVehicle then
                Position = GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false))
            end
            local string = "vector3("..string.format("%.2f", Position.x)..", "..string.format("%.2f", Position.y)..", "..string.format("%.2f", Position.z)..")"
            SendNUIMessage({
                action = "clipboard",
                string = string
            })
        end, "vec3")
    elseif info["action"] == "vec4" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local Position = GetEntityCoords(PlayerPedId())
            local Heading = GetEntityHeading(PlayerPedId())
            local InVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
            if InVehicle then
                Position = GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false))
                Heading = GetEntityHeading(GetVehiclePedIsIn(PlayerPedId(), false))
            end
            local string = "vector4("..string.format("%.2f", Position.x)..", "..string.format("%.2f", Position.y)..", "..string.format("%.2f", Position.z)..", "..math.floor(Heading)..")"
            SendNUIMessage({
                action = "clipboard",
                string = string
            })
        end, "vec4")
    elseif info["action"] == "heading" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            local Heading = GetEntityHeading(PlayerPedId())
            if InVehicle then
                Heading = GetEntityHeading(GetVehiclePedIsIn(PlayerPedId(), false))
            end
            local string = "heading: "..math.floor(Heading)
            SendNUIMessage({
                action = "clipboard",
                string = string
            })
        end, "heading")
    elseif info["action"] == "setweather" then
        if info["weather"] ~= "" and info["weather"] ~= nil then
            TriggerServerEvent("919-admin:server:SetWeather", info["weather"])
        end
    elseif info["action"] == "noclip" then
        TriggerServerEvent("919-admin:server:RequestNoClip")
    elseif info["action"] == "superjump" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.SuperJump = not AdminPanel.SuperJump
            if AdminPanel.SuperJump then
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.jumpOn"))
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>DISABLED:</strong> "..Lang:t("alerts.jumpOff"))
            end
        end, "superjump")
    elseif info["action"] == "noragdoll" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.NoRagdoll = not AdminPanel.NoRagdoll
            if AdminPanel.NoRagdoll then
                TriggerEvent("919-admin:client:ShowPanelAlert", "success",  "<strong>"..Lang:t("alerts.enabled").."</strong>  "..Lang:t("alerts.jumpOn"))
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger",  "<strong>"..Lang:t("alerts.disabled").."</strong>  "..Lang:t("alerts.jumpOff"))
            end
        end, "noragdoll")
    elseif info["action"] == "infinitestam" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            AdminPanel.InfiniteStamina = not AdminPanel.InfiniteStamina
            if AdminPanel.InfiniteStamina then
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.enabled").."</strong> "..Lang:t("alerts.infStamOn"))
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.disabled").."</strong> "..Lang:t("alerts.infStamOff"))
            end
        end, "infinitestam")
    elseif info["action"] == "settime" then
        TriggerServerEvent("919-admin:server:SetTime", info["time"], info["time"])
    elseif info["action"] == "reviveall" then
        TriggerServerEvent("919-admin:server:ReviveAll")
    elseif info["action"] == "messageall" then
        if info["message"] then
            if #info["message"] > 5 then
                TriggerServerEvent("919-admin:server:MessageAll", info["message"])
            else
                TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong> "..Lang:t("alerts.msgShort"))
            end
        else
            TriggerEvent("919-admin:client:ShowPanelAlert", "danger", "<strong>"..Lang:t("alerts.error").."</strong> "..Lang:t("alerts.noMessage"))
        end
    elseif info["action"] == "removejob" then
        TriggerServerEvent("919-admin:server:FireJob", currentPlayer)
    elseif info["action"] == "removegang" then
        TriggerServerEvent("919-admin:server:FireGang", currentPlayer)
    elseif info["action"] == "savecar" then
        TriggerServerEvent("919-admin:server:AddVehicleToGarage", currentPlayer)
    elseif info["action"] == "massdv" then
        TriggerServerEvent("919-admin:server:DeleteAllEntities", 1) -- Vehicles
    elseif info["action"] == "massdp" then
        TriggerServerEvent("919-admin:server:DeleteAllEntities", 2) -- Peds
    elseif info["action"] == "massdo" then
        TriggerServerEvent("919-admin:server:DeleteAllEntities", 3) -- Objects
    elseif info["action"] == "clearreports" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                TriggerServerEvent("919-admin:server:ClearJSON", "reports")
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.cleared").."</strong> "..Lang:t("alerts.reports"))
            end
        end, "clearreports")
    elseif info["action"] == "clearadminchat" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                TriggerServerEvent("919-admin:server:ClearJSON", "admin")
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.cleared").."</strong> "..Lang:t("alerts.adminchat"))
            end
        end, "clearadminchat")
    elseif info["action"] == "clearlogs" then
        Compat.TriggerCallback("919-admin:server:HasPermission", function(hasPermission)
            if hasPermission then
                TriggerServerEvent("919-admin:server:ClearJSON", "logs")
                TriggerEvent("919-admin:client:ShowPanelAlert", "success", "<strong>"..Lang:t("alerts.cleared").."</strong> "..Lang:t("alerts.logs"))
            end
        end, "clearlogs")
    end
    DebugTrace("NUICallback: Action ["..info["action"].."]")
end)

RegisterNUICallback("FirePlayerFromJob", function(citizenID)
    TriggerServerEvent("919-admin:server:FireJobByCitizenId", citizenID)
    DebugTrace("NUICallback: FirePlayerFromJob ["..citizenID.."]")
end)

RegisterNUICallback("FirePlayerFromGang", function(citizenID)
    TriggerServerEvent("919-admin:server:FireGangByCitizenId", citizenID)
    DebugTrace("NUICallback: FirePlayerFromGang ["..citizenID.."]")
end)

RegisterNUICallback("SetJobGrade", function(data)
    if data["citizenid"] ~= nil and data["grade"] ~= nil then
        TriggerServerEvent("919-admin:server:SetJobGradeByCitizenId", data["citizenid"], data["grade"])
        DebugTrace("NUICallback: SetJobGrade [".. data["citizenid"]..", "..data["grade"].."]")
    else
        DebugTrace("NUICallback: SetJobGrade [nil, nil]")
    end
end)

RegisterNUICallback("CreateCustomJob", function(data)
    TriggerServerEvent("919-admin:server:CreateCustomJob", data)
    DebugTrace("NUICallback: CreateCustomJob")
end)

RegisterNUICallback("CreateCustomCrew", function(data)
    TriggerServerEvent("919-admin:server:CreateCustomCrew", data)
    DebugTrace("NUICallback: CreateCustomCrew")
end)

RegisterNUICallback("DeleteCustomCrew", function(data)
    if data and data.name then
        TriggerServerEvent("919-admin:server:DeleteCustomCrew", data.name)
    end
    DebugTrace("NUICallback: DeleteCustomCrew")
end)

RegisterNUICallback("AddCrewGrade", function(data)
    TriggerServerEvent("919-admin:server:AddCrewGrade", data)
    DebugTrace("NUICallback: AddCrewGrade")
end)

RegisterNUICallback("SetGangGrade", function(data)
    if data["citizenid"] ~= nil and data["grade"] ~= nil then
        TriggerServerEvent("919-admin:server:SetGangGradeByCitizenId", data["citizenid"], data["grade"])
        DebugTrace("NUICallback: SetGangGrade [".. data["citizenid"]..", "..data["grade"].."]")
    else
        DebugTrace("NUICallback: SetGangGrade [nil, nil]")
    end
end)

RegisterNUICallback("UnbanPlayer", function(data)
    if data["license"] ~= nil then
        TriggerServerEvent("919-admin:server:UnbanPlayer", data["license"])
    end
end)

RegisterNUICallback("DeleteReport", function(data)
    if data["id"] ~= nil then
        TriggerServerEvent("919-admin:server:DeleteReport", data["id"])
    end
end)

RegisterNUICallback("ClaimReport", function(data)
    if data["id"] ~= nil then
        TriggerServerEvent("919-admin:server:ClaimReport", data["id"])
    end
end)

RegisterNUICallback("DeleteCharacter", function(citizenId)
    if citizenId ~= nil then
        TriggerServerEvent("919-admin:server:DeleteCharacter", citizenId)
    end
end)

RegisterNUICallback("SaveSetting", function(data)
    if data["setting"] ~= nil and data["value"] ~= nil then
        if data["setting"] == "darkmode" then
            if data["value"] == 1 then
                AdminPanel.Settings.DarkMode = true
                SetResourceKvpInt("919-admin:setting:darkmode", 1)
            else
                AdminPanel.Settings.DarkMode = false
                SetResourceKvpInt("919-admin:setting:darkmode", 0)
            end
        elseif data["setting"] == "seethrough" then
            if data["value"] == 1 then
                AdminPanel.Settings.SeeThrough = true
                SetResourceKvpInt("919-admin:setting:seethrough", 1)
            else
                AdminPanel.Settings.SeeThrough = false
                SetResourceKvpInt("919-admin:setting:seethrough", 0)
            end
        elseif data["setting"] == "Notifications" then
            if data["value"] == 1 then
                AdminPanel.Settings.Notifications = true
                SetResourceKvpInt("919-admin:setting:notifications", 1)
            else
                AdminPanel.Settings.Notifications = false
                SetResourceKvpInt("919-admin:setting:notifications", 0)
            end
        elseif data["setting"] == "theme" then
            AdminPanel.Settings.Notifications = tonumber(data["value"])
            SetResourceKvpInt("919-admin:setting:theme", tonumber(data["value"]))
        end
        DebugTrace("NUICallback: SaveSetting [".. data["setting"]..", "..data["value"].."]")
    else
        DebugTrace("NUICallback: SaveSetting [nil, nil]")
    end
end)

RegisterNUICallback("Refresh", function()
    TriggerServerEvent("919-admin:server:RefreshMenu")
end)
---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------
function NoClip(on)
    if not on then
        local playerPed = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle( playerPed, false )
        ResetEntityAlpha(PlayerPedId())

        if ( inVehicle ) then
            local veh = GetVehiclePedIsUsing( playerPed )
            SetEntityInvincible( veh, false )
        else
            ClearPedTasksImmediately( playerPed )
        end

        SetUserRadioControlEnabled( true )
        SetPlayerInvincible( PlayerId(), false )
        SetEntityInvincible( target, false )
    else
        blockinput = true
        local playerPed = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(playerPed, false)
        SetEntityAlpha(PlayerPedId(), 127, false)
        if ( not inVehicle ) then
            LoadAnimDict("mp_sleep")
            loadedAnims = true
        end
    end
end

Citizen.CreateThread( function()
    local rotationSpeed = 2.5
    local forward = 1.8

    local speeds = { 0.1, 0.2, 0.5, 1.0, 2.0, 7.0, 15.0 }

    local moveUpKey = 44      -- Q
    local moveDownKey = 46    -- E
    local moveForwardKey = 32 -- W
    local moveBackKey = 33    -- S
    local rotateLeftKey = 34  -- A
    local rotateRightKey = 35 -- D
    local changeSpeedKey = 21 -- LSHIFT

    function updateForward()
        forward = speeds[ travelSpeed ]
    end

    function handleMovement(xVect,yVect)
        if IsControlJustPressed(1, changeSpeedKey) or IsDisabledControlJustPressed(1, changeSpeedKey) then
            travelSpeed = travelSpeed + 1
            if travelSpeed > getTableLength(speeds) then
                travelSpeed = 1
            end
            updateForward();
        end

        if IsControlPressed(1, moveUpKey) or IsDisabledControlPressed(1, moveUpKey) then curLocation.z = curLocation.z + forward / 2 ;
        elseif IsControlPressed(1, moveDownKey) or IsDisabledControlPressed(1, moveDownKey) then curLocation.z = curLocation.z - forward / 2 ; end

        if IsControlPressed(1, moveForwardKey) or IsDisabledControlPressed(1, moveForwardKey) then
            curLocation.x = curLocation.x + xVect
            curLocation.y = curLocation.y + yVect
        elseif IsControlPressed(1, moveBackKey) or IsDisabledControlPressed(1, moveBackKey) then
            curLocation.x = curLocation.x - xVect
            curLocation.y = curLocation.y - yVect
        end

        if IsControlPressed(1, rotateLeftKey) or IsDisabledControlPressed(1, rotateLeftKey) then
            curHeading = curHeading + rotationSpeed
        elseif IsControlPressed(1, rotateRightKey) or IsDisabledControlPressed(1, rotateRightKey) then
            curHeading = curHeading - rotationSpeed
        end
    end

     while true do
        Citizen.Wait(3)
        if AdminPanel.NoClip then
            local playerPed = PlayerPedId()
            if IsEntityDead( playerPed ) then
                AdminPanel.NoClip = false
                Citizen.Wait( 100 )
            else
                target = playerPed
                drawTxt("~r~NO CLIP ACTIVE ~s~[SPEED: ~y~"..speeds[travelSpeed].."~s~] - ~r~"..Config.NoClipKey.."~s~ TO STOP", 4, true, 0.50, 0.92, 0.6, 255, 255, 255, 255)
                local inVehicle = IsPedInAnyVehicle(playerPed, true)
                if inVehicle then
                    target = GetVehiclePedIsUsing(playerPed)
                end
                SetEntityVelocity(playerPed, 0.0, 0.0, 0.0)
                SetEntityRotation(playerPed, 0, 0, 0, 0, false)
                SetUserRadioControlEnabled(false)
                SetPlayerInvincible(PlayerId(), true)
                SetEntityInvincible(target, true)
                if not inVehicle then
                    TaskPlayAnim(playerPed, "mp_sleep", "bind_pose_180", 8.0, 0.0, -1, 9, 0, 0, 0, 0 )
                end
                local xVect = forward * math.sin(degToRad(curHeading)) * -1.0
                local yVect = forward * math.cos(degToRad(curHeading))
                handleMovement(xVect, yVect)
                SetEntityCoordsNoOffset(target, curLocation.x, curLocation.y, curLocation.z, true, true, true)
                SetEntityHeading(target, curHeading - rotationSpeed)
            end
        else
            Citizen.Wait(100)
        end
     end
end)

-- VoidLine: this used to run every 3ms UNCONDITIONALLY forever, for every
-- connected player (not just admins) -- SetPedCanRagdoll every ~300
-- times/second regardless of whether any of these features were even
-- active. That's a real, constant background FPS cost, not something tied
-- to opening the admin panel. Now backs off to Wait(250) when none of the
-- four flags are set (the common case for almost everyone almost all the
-- time), same pattern the NoClip thread right above already used correctly.
Citizen.CreateThread(function()
    while true do
        if AdminPanel.DisplayingRadar or AdminPanel.InfiniteStamina or AdminPanel.SuperJump or AdminPanel.NoRagdoll then
            Citizen.Wait(3)

            if AdminPanel.DisplayingRadar then
                DisplayRadar(true)
            end

            if AdminPanel.InfiniteStamina then
                RestorePlayerStamina(PlayerId(), 1.0)
            end

            if AdminPanel.SuperJump then
                SetSuperJumpThisFrame(PlayerId())
            end

            SetPedCanRagdoll(PlayerPedId(), not AdminPanel.NoRagdoll)
        else
            Citizen.Wait(250)
        end
    end
end)

-- VoidLine: same issue as the ragdoll thread above -- Wait(5) unconditionally
-- forever for every player, even though the body only ever does anything
-- while actively spectating (rare). Backs off to Wait(250) otherwise.
Citizen.CreateThread(function()
    while true do
        if AdminPanel.Spectating then
            Citizen.Wait(5)
            drawTxt("NOW SPECTATING "..AdminPanel.SpectatingPlayer.." [ID: "..AdminPanel.SpectatingID.."] - ~r~BACKSPACE~s~ TO STOP", 4, true, 0.47, 0.88, 0.6, 255, 255, 255, 255)
            drawTxt("[~y~LEFT ARROW~s~] Spectate Previous Player - [~y~RIGHT ARROW~s~] Spectate Next Player", 4, true, 0.47, 0.92, 0.6, 255, 255, 255, 255)
            if IsControlJustReleased(0, 177) then
                AdminPanel.SpectatePlayer(-1, -1, "")
            end
            if IsControlJustReleased(0, 174) then
                TriggerServerEvent("919-admin:server:requestPrevSpectate")
            end
            if IsControlJustReleased(0, 175) then
                TriggerServerEvent("919-admin:server:requestNextSpectate")
            end
        else
            Citizen.Wait(250)
        end
    end
end)

AdminPanel.SpectatePlayer = function(targetPed, target, name)
	local playerPed = PlayerPedId() -- yourself
	enable = true
	if (target == PlayerId() or target == -1) then 
		enable = false
	end
	if (enable) then
		if targetPed == playerPed then
			Wait(500)
			targetPed = GetPlayerPed(target)
		end
		local targetx,targety,targetz = table.unpack(GetEntityCoords(targetPed, false))

		RequestCollisionAtCoord(targetx,targety,targetz)
		NetworkSetInSpectatorMode(true, targetPed)
        SetEntityInvincible(playerPed,true)
		SetEntityVisible(playerPed,false)
        SetEntityCollision(playerPed, false, false)
        AdminPanel.Spectating = true
	else
		if AdminPanel.SavedCoords then
			RequestCollisionAtCoord(AdminPanel.SavedCoords.x, AdminPanel.SavedCoords.y, AdminPanel.SavedCoords.z)
			Wait(500)
			SetEntityCoords(playerPed, AdminPanel.SavedCoords.x, AdminPanel.SavedCoords.y, AdminPanel.SavedCoords.z, 0, 0, 0, false)
			AdminPanel.SavedCoords = nil
		end
		NetworkSetInSpectatorMode(false, targetPed)
        SetEntityInvincible(playerPed,false)
		SetEntityVisible(playerPed,true)
        SetEntityCollision(playerPed, true, true)
        if QBCore then
		    QBCore.Functions.Notify("Stopped spectating.", "success")
        else
            ESX.ShowNotification("Stopped spectating.")
        end
        AdminPanel.Spectating = false
	end
end

Citizen.CreateThread(function()
    while true do
        if AdminPanel.DisplayingBlips then
            local Players = {}
            Compat.TriggerCallback("919-admin:server:GetPlayerPositions", function(p)
                Players = p
                for k,v in ipairs(AdminPanel.PlayerBlips) do
                    if AdminPanel.PlayerBlipsOnline[k] == nil or AdminPanel.PlayerBlipsOnline[k] == true then
                        AdminPanel.PlayerBlipsOnline[k] = false
                    end
                end
                for k, v in ipairs(Players) do
                    local playerCoords = v.pos
                    if AdminPanel.PlayerBlips[k] == nil then
                        AdminPanel.PlayerBlips[k] = AddBlipForCoord(playerCoords.x, playerCoords.y, playerCoords.z)
                        SetBlipSprite(AdminPanel.PlayerBlips[k], 1)
                        SetBlipColour(AdminPanel.PlayerBlips[k], 0)
                        SetBlipScale(AdminPanel.PlayerBlips[k], 0.75)
                        SetBlipCategory(AdminPanel.PlayerBlips[k], 7)
                        SetBlipDisplay(AdminPanel.PlayerBlips[k], 6)
                        SetBlipShrink(AdminPanel.PlayerBlips[k], true)
                        SetBlipAsShortRange(AdminPanel.PlayerBlips[k], true)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString("[ "..v.id.." ] "..v.name)
                        EndTextCommandSetBlipName(AdminPanel.PlayerBlips[k])
                    else
                        SetBlipCoords(AdminPanel.PlayerBlips[k], playerCoords.x, playerCoords.y, playerCoords.z);
                    end
                    AdminPanel.PlayerBlipsOnline[k] = true
                end
                for k,v in ipairs(AdminPanel.PlayerBlips) do
                    if AdminPanel.PlayerBlipsOnline[k] == false then
                        RemoveBlip(AdminPanel.PlayerBlips[k])
                        AdminPanel.PlayerBlips[k] = nil
                        AdminPanel.PlayerBlipsOnline[k] = nil
                    end
                end
            end)
            Citizen.Wait(1000)
        else
            for k,v in ipairs(AdminPanel.PlayerBlips) do
                if DoesBlipExist(AdminPanel.PlayerBlips[k]) then
                    RemoveBlip(AdminPanel.PlayerBlips[k])
                    AdminPanel.PlayerBlips[k] = nil
                    AdminPanel.PlayerBlipsOnline[k] = nil
                end
            end
            Citizen.Wait(10000)
        end
    end
end)

function getPlayerName(id)
    local playerName = nil
    Compat.TriggerCallback("919-Admin:GetPlayerName", function(name)
        playerName = name
    end, id)
    while playerName == nil do
        Wait(10)
    end
    return playerName
end

function toggleNames()
    if AdminPanel.NamesThreadRunning then return end
    AdminPanel.NamesThreadRunning = true
    CreateThread(function()
        while true do
            if ShowNames then
                local nearbyPlayers = GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 1000.0)
                local seen = {}
                for _, playerIdx in pairs(nearbyPlayers) do
                    local playerId = GetPlayerServerId(playerIdx)
                    local playerPed = GetPlayerPed(playerIdx)
                    if DoesEntityExist(playerPed) then
                        local tagEntry = AdminPanel.NameTags[playerId]

                        local playerName = "ID: "..playerId.." | "..getPlayerName(playerId).." ("..GetPlayerName(playerIdx)..")"

                        if not tagEntry or not DoesEntityExist(tagEntry.ped) then
                            local tagHandle = CreateFakeMpGamerTag(playerPed, playerName, false, false, "", false)
                            AdminPanel.NameTags[playerId] = { tag = tagHandle, ped = playerPed }
                            tagEntry = AdminPanel.NameTags[playerId]
                            SetMpGamerTagAlpha(tagEntry.tag, 0, 255)
                            SetMpGamerTagAlpha(tagEntry.tag, 2, 255)
                            SetMpGamerTagAlpha(tagEntry.tag, 4, 255)
                            SetMpGamerTagAlpha(tagEntry.tag, 6, 255)
                            SetMpGamerTagHealthBarColour(tagEntry.tag, 25)
                        end

                        -- Kept current every cycle so the per-frame draw
                        -- thread below always has an up to date name/ped.
                        tagEntry.text = playerName
                        tagEntry.playerIdx = playerIdx

                        -- VoidLine: component 0 (the name text) is hidden here
                        -- rather than shown -- GTA's native gamer-tag name has
                        -- no arbitrary-RGB colour lever, only a fixed
                        -- HUD_COLOUR index, so the coloured name is drawn
                        -- manually instead (see the per-frame thread below).
                        -- Everything else (health/voice/invincible icons)
                        -- stays on the native tag as before.
                        SetMpGamerTagVisibility(tagEntry.tag, 0, false)
                        -- VoidLine: native health bar (component 2) hidden too --
                        -- a custom one is drawn attached directly under the name
                        -- in the per-frame thread below, sized to the name's own
                        -- text width instead of the native tag's fixed width.
                        SetMpGamerTagVisibility(tagEntry.tag, 2, false)
                        -- VoidLine: native talk icon (component 4) hidden too --
                        -- a custom one is drawn to the left of the name in the
                        -- per-frame thread below instead of floating above it.
                        SetMpGamerTagVisibility(tagEntry.tag, 4, false)
                        if GetPlayerInvincible(playerIdx) then
                            SetMpGamerTagVisibility(tagEntry.tag, 6, true)
                        else
                            SetMpGamerTagVisibility(tagEntry.tag, 6, false)
                        end

                        seen[playerId] = true
                    end
                end

                -- Clean up tags for players no longer nearby or disconnected
                for storedId, data in pairs(AdminPanel.NameTags) do
                    if not seen[storedId] or not DoesEntityExist(data.ped) then
                        if data.tag then
                            RemoveMpGamerTag(data.tag)
                        end
                        AdminPanel.NameTags[storedId] = nil
                    end
                end
            else
                -- Names toggled off: clear all tags to avoid stale entries
                for storedId, data in pairs(AdminPanel.NameTags) do
                    if data.tag then
                        SetMpGamerTagVisibility(data.tag, 0, false)
                        SetMpGamerTagVisibility(data.tag, 2, false)
                        SetMpGamerTagVisibility(data.tag, 4, false)
                        SetMpGamerTagVisibility(data.tag, 6, false)
                        RemoveMpGamerTag(data.tag)
                    end
                end
                AdminPanel.NameTags = {}
            end

            Wait(1000)
        end
    end)
end

-- VoidLine: per-frame coloured-name draw for ShowNames. DrawText commands
-- are not persistent like a gamer tag -- they render for exactly one frame
-- and must be reissued every tick to stay visible, hence the separate fast
-- (Wait(0)) thread rather than folding this into toggleNames' Wait(1000)
-- maintenance loop above.
local function hexToRgb(hex)
    if type(hex) ~= 'string' then return 255, 255, 255 end
    local r, g, b = hex:match('^#(%x%x)(%x%x)(%x%x)$')
    if not r then return 255, 255, 255 end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

CreateThread(function()
    RequestStreamedTextureDict('mpinbox', false)
end)

local function drawColoredName3D(ped, text, hexColor, playerIdx)
    local bone = GetPedBoneIndex(ped, 0x796e) -- SKEL_Head
    local coords = bone and bone ~= -1 and GetWorldPositionOfEntityBone(ped, bone) or GetEntityCoords(ped)
    coords = coords + vector3(0.0, 0.0, 0.35)

    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    local r, g, b = hexToRgb(hexColor)
    SetTextScale(0.45, 0.45)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 200)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)

    -- VoidLine: GetTextScreenWidth turned out unreliable here (bars were
    -- coming out zero-width and invisible), so width is estimated from
    -- character count instead -- simple and consistent every frame.
    local textWidth = math.max(0.03, #text * 0.0037)

    -- Custom mic icon to the left of the name -- replaces the native
    -- gamer-tag talk icon (component 4), which floated above the name
    -- instead of sitting next to it.
    if playerIdx and NetworkIsPlayerTalking(playerIdx) and HasStreamedTextureDictLoaded('mpinbox') then
        local iconSize = 0.014
        DrawSprite('mpinbox', 'mic_2', (x - textWidth / 2) - (iconSize / 2) - 0.006, y + 0.007, iconSize, iconSize, 0, 255, 255, 255, 255)
    end

    -- Armour bar (blue), stacked directly under the full width of the name
    -- text. VoidLine 2026-09-02: the health bar that used to be drawn right
    -- below this was removed per request -- name + armour only now.
    local barHeight = 0.004
    local nextY = y + 0.030

    local armourRatio = math.max(0.0, math.min(1.0, GetPedArmour(ped) / 100.0))
    if armourRatio > 0 then
        DrawRect(x, nextY, textWidth, barHeight, 20, 20, 20, 180)
        local fillWidth = textWidth * armourRatio
        DrawRect((x - textWidth / 2) + fillWidth / 2, nextY, fillWidth, barHeight, 60, 160, 255, 220)
    end
end

CreateThread(function()
    while true do
        if ShowNames then
            for _, tagEntry in pairs(AdminPanel.NameTags) do
                if tagEntry.ped and DoesEntityExist(tagEntry.ped) and tagEntry.text then
                    local color = (Entity(tagEntry.ped).state and Entity(tagEntry.ped).state.vl_crewColor) or '#ffffff'
                    drawColoredName3D(tagEntry.ped, tagEntry.text, color, tagEntry.playerIdx)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Admin Duty

-- Admin Duty moved to top

function AdminDutyUpdateTag()
    local show = false -- Set to false to entirely remove the overhead tag
    local name = GetPlayerName(PlayerId()) or "ADMIN"
    local tagText = "" -- Empty tag
    TriggerServerEvent("919-admin:server:AdminDutyTag", show, tagText)
end

local function AdminDutyRequestModel(model)
    if not model then return false end
    RequestModel(model)
    local timeoutAt = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeoutAt then
            return false
        end
        Wait(0)
        RequestModel(model)
    end
    return true
end

local function AdminDutyRestorePosition()
    if not AdminDuty.OriginalCoords then return end
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, AdminDuty.OriginalCoords.x, AdminDuty.OriginalCoords.y, AdminDuty.OriginalCoords.z, false, false, false)
    if AdminDuty.OriginalHeading then
        SetEntityHeading(ped, AdminDuty.OriginalHeading)
    end
end

local function AdminDutyRestoreAppearance()
    if GetResourceState('sn_appearance') == 'started' then
        TriggerEvent('sn_appearance:client:loadPlayerClothing')
        ExecuteCommand('reloadskin')
        return true
    end
    if GetResourceState('qb-clothing') == 'started' then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        TriggerServerEvent('qb-clothing:loadPlayerSkin')
        return true
    end
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:reloadSkin')
        return true
    end
    return false
end

RegisterNetEvent('custom_onduty:setOnDutyPed', function(pedModel)
    local playerPed = PlayerPedId()
    print("[919ADMIN DEBUG] setOnDutyPed called with model: " .. tostring(pedModel))
    if not AdminDuty.Active then
        AdminDuty.Active = true
        AdminDuty.OriginalModel = GetEntityModel(playerPed)
        AdminDuty.OriginalCoords = GetEntityCoords(playerPed)
        AdminDuty.OriginalHeading = GetEntityHeading(playerPed)
    end

    local model = GetHashKey(pedModel)
    print("[919ADMIN DEBUG] Requesting model: " .. tostring(model))
    if not AdminDutyRequestModel(model) then
        print("[919ADMIN DEBUG] Failed to load model: " .. tostring(pedModel))
        TriggerEvent('QBCore:Notify', 'Failed to load duty ped model.', 'error')
        return
    end
    print("[919ADMIN DEBUG] Model loaded, setting player model...")
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    AdminDutyRestorePosition()
    AdminDutyUpdateTag()
    print("[919ADMIN DEBUG] Ped change complete.")
end)

RegisterNetEvent('custom_onduty:resetPed', function()
    if AdminDuty.OriginalModel then
        if AdminDutyRequestModel(AdminDuty.OriginalModel) then
            SetPlayerModel(PlayerId(), AdminDuty.OriginalModel)
            SetModelAsNoLongerNeeded(AdminDuty.OriginalModel)
            -- AdminDutyRestorePosition()
        end
    end
    
    Wait(500) -- Wait a bit for model to change
    AdminDutyRestoreAppearance()

    AdminDutyUpdateTag()
    TriggerServerEvent("919-admin:server:AdminDutyTag", false, "")
    AdminDuty.Active = false
    AdminDuty.OriginalModel = nil
    AdminDuty.OriginalCoords = nil
    AdminDuty.OriginalHeading = nil
end)

RegisterNetEvent('919-admin:client:ToggleDuty', function()
    print('[919ADMIN] ToggleDuty event received (Main)')
    -- Attempt to toggle based on logic, fallback to dutyon if variable unavailable
    if AdminDuty and AdminDuty.Active then
        ExecuteCommand('dutyoff')
    else
        ExecuteCommand('dutyon')
    end
end)

-- Removed duplicate QBCore:Command:SpawnVehicle handler.
-- qb-core already handles /car natively via its own client handler.
-- Having a second handler here caused two cars to spawn on every /car command.
