-- Author- 0RESMON
-- Github- https://github.com/0resmon
-- u: https://pastebin.com/raw/tqwZEEJS
-- LinkendIn- https://www.linkedin.com/in/0resmon-770305212/

-- VoidLine: see the matching comment in main/server.lua -- same race against
-- qbx_core's bridge/qb compat export, fixed the same way (retry instead of
-- a single blocking call at resource start).
if Config.Framework == "oldesx" then
    ESX = nil
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
elseif Config.Framework == "qb" then
    CreateThread(function()
        while not QBCore do
            local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok and obj then
                QBCore = obj
            else
                Wait(500)
            end
        end
    end)
elseif Config.Framework == "oldqb" then
    QBCore = nil
    TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
elseif Config.Framework == "esx" then
    ESX = exports['es_extended']:getSharedObject()
end
    
RegisterServerEvent('0r-weaponReality:takeWeaponFromGround')
AddEventHandler('0r-weaponReality:takeWeaponFromGround', function(pickup, weaponName)
    -- print("takeWeaponFromGround server")
    local src = source
    TriggerClientEvent('0r-weaponReality:Notification', src, "You picked up a weapon: "..weaponName)
    TriggerClientEvent('0r-weaponReality:DeleteOnClient', -1, pickup)
    if not Config then
        print("Config is not defined!")
        return
    end

    if not Config.Framework or not Config.Inventory then
        print("Framework or Inventory is not defined in Config!")
        return
    end

    local xPlayer
    if Config.Framework == "qb" or Config.Framework == "oldqb" then
        xPlayer = QBCore.Functions.GetPlayer(source)
    elseif Config.Framework == "oldesx" or Config.Framework == "esx" then
        xPlayer = ESX.GetPlayerFromId(source)
    else
        print("Unsupported framework in Config!")
        return
    end

    if not xPlayer then
        print("xPlayer is not defined!")
        return
    end

    if Config.Inventory == "qb-inventory" or Config.Inventory == "lj-inventory" then
        xPlayer.Functions.AddItem(weaponName, 1)
    elseif Config.Inventory == "ox-inventory" then
        exports['ox_inventory']:AddItem(src, weaponName, 1)
    elseif Config.Inventory == "qs-inventory" then
        exports['qs-inventory']:AddItem(src, weaponName, 1)
    elseif Config.Inventory == "esx-inventory" then
        xPlayer.addWeapon(weaponName, 1)
    else
        print("Unsupported inventory system in Config!")
        return
    end
end)


RegisterServerEvent('0r-weaponReality:weaponRemoveFromInventory', function(weaponName,victimID)
    local src = source
    if not Config then
        print("Config is not defined!")
        return
    end

    if not Config.Framework or not Config.Inventory then
        print("Framework or Inventory is not defined in Config!")
        return
    end


    if Config.Framework == "qb" or Config.Framework == "oldqb" then
        local xPlayer = QBCore.Functions.GetPlayer(victimID)
        if xPlayer then
            if Config.Inventory == "qb-inventory" then
                xPlayer.Functions.RemoveItem(weaponName, 1)
            elseif Config.Inventory == "ox-inventory" then
                exports['ox_inventory']:RemoveItem(src, weaponName, 1)
            elseif Config.Inventory == "lj-inventory" then
                xPlayer.Functions.RemoveItem(weaponName, 1)
            elseif Config.Inventory == "qs-inventory" then
                local itemNameLower = string.lower(weaponName)
                xPlayer.Functions.RemoveItem(itemNameLower, 1)
                -- exports['qs-inventory']:RemoveItem(src, weaponName, 1)
            end
        end
    elseif Config.Framework == "oldesx" or Config.Framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(victimID)
        if xPlayer then
            if Config.Inventory == "qb-inventory" then
                xPlayer.Functions.RemoveItem(weaponName, 1)
            elseif Config.Inventory == "ox-inventory" then
                exports['ox_inventory']:RemoveItem(src, weaponName, 1)
            elseif Config.Inventory == "lj-inventory" then
                xPlayer.Functions.RemoveItem(weaponName, 1)
            elseif Config.Inventory == "qs-inventory" then
                local itemNameLower = string.lower(weaponName)
                exports['qs-inventory']:RemoveItem(src, itemNameLower, 1)
                -- xPlayer.Functions.RemoveItem(weaponName, 1)
            elseif Config.Inventory == "esx-inventory" then
                xPlayer.removeWeapon(weaponName)
            end
        end
    end
end)

