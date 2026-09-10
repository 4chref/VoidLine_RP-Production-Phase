

-- VoidLine: exports['qb-core']:GetCoreObject() used to run synchronously at
-- the top of this file. On a Qbox server that export is served by
-- qbx_core's bridge/qb compat layer (registered via an internal
-- __cfx_export_qb-core_GetCoreObject handler), not by a resource literally
-- named qb-core -- and that handler isn't guaranteed to be registered yet
-- the instant this resource starts, even with `ensure qbx_core` earlier in
-- server.cfg. A failed/nil call here at boot meant QBCore stayed nil and
-- (since this ran at the top level, outside any function) the file kept
-- executing, but every event handler below silently got a nil QBCore --
-- exactly what "works after I restart the resource" looks like, since by
-- restart time qbx_core's bridge is already fully up. Retrying instead of
-- calling once removes the race entirely.
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

AddEventHandler('onResourceStart', function(resourceName)
  if (GetCurrentResourceName() ~= resourceName) then
    return
  end
  local resourceName = GetCurrentResourceName()
  local msg = "^3" ..  Config.Framework .. "^7"
  print("^4[" .. resourceName .. "]" .. "^2[INFO]^7 " .. "Script started. ^6[FRAMEWORK:]^7 " .. msg)
  if Config.WeaponAnimation == "always" then
    TriggerClientEvent('0r-weaponReality:weaponAnimation', -1, "xd")
  end
end)
RegisterServerEvent('0r-weaponReality:weaponThrown')
AddEventHandler('0r-weaponReality:weaponThrown', function(pickupHash, finalCoords, weaponName, weaponThrewAwayHash)
    local src = source
    -- print("Weapon thrown: " .. weaponName .. " (" .. pickupHash .. ") at " .. finalCoords.x .. ", " .. finalCoords.y .. ", " .. finalCoords.z)
    TriggerClientEvent('0r-weaponReality:createOnClient', -1, pickupHash, finalCoords, weaponName, weaponThrewAwayHash)
end)

