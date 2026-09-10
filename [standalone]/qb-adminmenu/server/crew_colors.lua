-- VoidLine: replicates each player's crew (gang) colour to every client via a
-- statebag, so ShowNames can colour their name (see the per-frame draw
-- thread in client/main.lua). GTA's native gamer-tag name text has no
-- arbitrary-RGB colour lever (only a fixed HUD_COLOUR index), so ShowNames
-- draws the name manually instead of relying on CreateFakeMpGamerTag for it.
--
-- Colours are stored in json/crew_colors.json, NOT inside the gang table
-- qbx_core writes to shared/gangs.lua. qbx_core's own file serializer
-- (server/groups.lua's convertGroupsToPlainText) only knows a fixed set of
-- Gang fields -- label/grades -- and silently drops anything else, including
-- `color`, every single time CreateGangs or RemoveGang commits the file.
-- Keeping colour here instead is what makes it survive a qbx_core restart.

local DEFAULT_COLOR = '#ffffff'

local CrewColors = json.decode(LoadResourceFile(GetCurrentResourceName(), 'json/crew_colors.json') or '{}') or {}

local function saveCrewColors()
    SaveResourceFile(GetCurrentResourceName(), 'json/crew_colors.json', json.encode(CrewColors), -1)
end

---@param crewName string
---@return string hex
function GetCrewColor(crewName)
    return CrewColors[crewName] or DEFAULT_COLOR
end

---@param crewName string
---@param hexColor string
function SetCrewColor(crewName, hexColor)
    CrewColors[crewName] = hexColor
    saveCrewColors()
end

---@param crewName string
function DeleteCrewColor(crewName)
    CrewColors[crewName] = nil
    saveCrewColors()
end

local function syncCrewColor(source)
    if not source or source <= 0 then return end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData or not Player.PlayerData.gang then return end

    local color = GetCrewColor(Player.PlayerData.gang.name)

    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        Entity(ped).state:set('vl_crewColor', color, true)
    end
end

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then
        syncCrewColor(Player.PlayerData.source)
    end
end)

RegisterNetEvent('QBCore:Server:OnGangUpdate', function(src)
    syncCrewColor(src)
end)

-- A crew's colour can change (editing an existing crew) without any player's
-- OWN crew assignment changing -- refresh everyone currently in that crew.
RegisterNetEvent('919-admin:server:CrewColorChanged', function(crewName)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.gang and Player.PlayerData.gang.name == crewName then
            syncCrewColor(src)
        end
    end
end)

-- Players already online when this resource (re)starts never fire
-- PlayerLoaded/OnGangUpdate again on their own -- sync them once here so a
-- qb-adminmenu restart doesn't leave everyone white until they rejoin.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        for _, playerId in ipairs(GetPlayers()) do
            syncCrewColor(tonumber(playerId))
        end
    end)
end)
