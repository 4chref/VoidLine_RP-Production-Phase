-- QBCore framework integration for qb-target
local QBCore = exports['qb-core']:GetCoreObject()
local utils = require 'client.utils'
local playerItems = utils.getItems()
local playerGroups = {}

local function setPlayerData(PlayerData)
    table.wipe(playerGroups)

    if PlayerData.job then
        playerGroups['job'] = PlayerData.job
    end

    if PlayerData.gang then
        playerGroups['gang'] = PlayerData.gang
    end

    -- Populate items from QBCore inventory
    if PlayerData.items and not utils.hasExport('ox_inventory.Items') then
        table.wipe(playerItems)
        for _, item in pairs(PlayerData.items) do
            if item and item.name and item.amount and item.amount > 0 then
                playerItems[item.name] = item.amount
            end
        end
    end
end

-- Load initial player data if already loaded
if QBCore.Functions.GetPlayerData and QBCore.Functions.GetPlayerData() and QBCore.Functions.GetPlayerData().job then
    setPlayerData(QBCore.Functions.GetPlayerData())
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setPlayerData(QBCore.Functions.GetPlayerData())
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    local PlayerData = QBCore.Functions.GetPlayerData()
    PlayerData.job = JobInfo
    setPlayerData(PlayerData)
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    table.wipe(playerGroups)
    if not utils.hasExport('ox_inventory.Items') then
        table.wipe(playerItems)
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData')
AddEventHandler('QBCore:Player:SetPlayerData', function(PlayerData)
    setPlayerData(PlayerData)
end)

-- Track item changes if not using ox_inventory
if not utils.hasExport('ox_inventory.Items') then
    AddEventHandler('QBCore:Client:ItemBox', function(item, type)
        -- Refresh items on any inventory change
        local pd = QBCore.Functions.GetPlayerData()
        if pd and pd.items then
            table.wipe(playerItems)
            for _, v in pairs(pd.items) do
                if v and v.name and v.amount and v.amount > 0 then
                    playerItems[v.name] = v.amount
                end
            end
        end
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function utils.hasPlayerGotGroup(filter)
    local _type = type(filter)

    if _type == 'string' then
        -- Check job name
        if playerGroups.job and playerGroups.job.name == filter then
            return true
        end
        -- Check gang name
        if playerGroups.gang and playerGroups.gang.name == filter then
            return true
        end
    elseif _type == 'table' then
        local tabletype = table.type(filter)

        if tabletype == 'hash' then
            -- { ['police'] = 0, ['ambulance'] = 2 } — name = minGrade
            for name, grade in pairs(filter) do
                if playerGroups.job and playerGroups.job.name == name and playerGroups.job.grade.level >= grade then
                    return true
                end
                if playerGroups.gang and playerGroups.gang.name == name and playerGroups.gang.grade.level >= grade then
                    return true
                end
            end
        elseif tabletype == 'array' then
            -- { 'police', 'ambulance' }
            for i = 1, #filter do
                local name = filter[i]
                if playerGroups.job and playerGroups.job.name == name then
                    return true
                end
                if playerGroups.gang and playerGroups.gang.name == name then
                    return true
                end
            end
        end
    end

    return false
end
