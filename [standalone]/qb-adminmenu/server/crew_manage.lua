-- VoidLine: Create/Delete Crew, exposed from the Crew (Gang) page. Uses
-- qbx_core's own CreateGangs/RemoveGang exports (server/groups.lua) with
-- commitToFile=true, so this writes straight into qbx_core/shared/gangs.lua
-- -- the officially supported way to manage gangs at runtime, not a manual
-- file edit.

local function isAuthorised(src)
    return AdminPanel.HasPermissionEx(src, 'gangpage')
end

---@param name string
---@return boolean ok
---@return string? reason
local function validateCrewName(name)
    if type(name) ~= 'string' or name == '' then
        return false, 'Crew name is required.'
    end
    if name:match('%s') then
        return false, 'Crew name cannot contain spaces.'
    end
    if name ~= name:lower() then
        return false, 'Crew name must be lower case.'
    end
    if not name:match('^[a-z0-9_]+$') then
        return false, 'Crew name can only contain a-z, 0-9 and underscores.'
    end
    return true
end

---@param hex string
---@return boolean
local function isValidHexColor(hex)
    return type(hex) == 'string' and hex:match('^#%x%x%x%x%x%x$') ~= nil
end

RegisterNetEvent('919-admin:server:CreateCustomCrew', function(data)
    local src = source
    if not isAuthorised(src) then return end

    local name = data and data.name
    local ok, reason = validateCrewName(name)
    if not ok then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger', '<strong>Error</strong> ' .. reason)
        return
    end

    local label = (data.label and data.label ~= '') and data.label or name
    local color = isValidHexColor(data.color) and data.color or '#ffffff'
    local gradeName = (data.gradeName and data.gradeName ~= '') and data.gradeName or 'Member'

    local gangs = exports.qbx_core:GetGangs()
    if gangs and gangs[name] then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger',
            ('<strong>Error</strong> Crew \'%s\' already exists.'):format(name))
        return
    end

    local gang = {
        label = label,
        grades = {
            [0] = { name = gradeName },
        },
    }

    -- No singular CreateGang export exists (only the plural CreateGangs),
    -- unlike CreateJob/RemoveJob which are both singular.
    exports.qbx_core:CreateGangs({ [name] = gang }, true)

    SetCrewColor(name, color)
    -- QBCore.Shared.Gangs (from exports['qb-core']:GetCoreObject(), a
    -- cross-resource export call) is a one-time snapshot taken when this
    -- resource started, not a live view of qbx_core's gangs table -- patch
    -- it directly or Compat.GetMasterGangList() stays stale until a restart.
    -- adminactions.lua's SetGang looks grades up by tostring(grade) (a
    -- string key), while qbx_core's own grades table uses integer keys --
    -- set both here so "Set Grade" doesn't report "Invalid grade" on a
    -- crew's starting rank.
    QBCore.Shared.Gangs[name] = {
        label = label,
        grades = {
            [0] = { name = gradeName },
            ['0'] = { name = gradeName },
        },
    }
    TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'success', '<strong>Success</strong> Crew created.')
    TriggerClientEvent('919-admin:client:ReceiveGangPageInfo', src, Compat.GetMasterGangList())
end)

RegisterNetEvent('919-admin:server:AddCrewGrade', function(data)
    local src = source
    if not isAuthorised(src) then return end

    local crewName = data and data.name
    local gradeName = data and data.gradeName
    if type(crewName) ~= 'string' or crewName == '' or type(gradeName) ~= 'string' or gradeName == '' then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger', '<strong>Error</strong> Rank name is required.')
        return
    end

    local gangs = exports.qbx_core:GetGangs()
    local gang = gangs and gangs[crewName]
    if not gang then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger', '<strong>Error</strong> Crew not found.')
        return
    end

    local nextGrade = 0
    for gradeIndex in pairs(gang.grades) do
        if gradeIndex >= nextGrade then nextGrade = gradeIndex + 1 end
    end

    local gradeData = { name = gradeName }
    if data.isboss then
        gradeData.isboss = true
        gradeData.bankAuth = true
    end

    -- No return value from this export -- gang existence was already
    -- checked above, so there's nothing meaningful left to fail on.
    exports.qbx_core:UpsertGangGrade(crewName, nextGrade, gradeData, true)

    -- Same QBCore.Shared.Gangs staleness as CreateCustomCrew -- patch it
    -- directly or the new rank won't show until a restart. Both key forms
    -- again, see the comment in CreateCustomCrew for why.
    if QBCore.Shared.Gangs[crewName] then
        QBCore.Shared.Gangs[crewName].grades[nextGrade] = gradeData
        QBCore.Shared.Gangs[crewName].grades[tostring(nextGrade)] = gradeData
    end

    TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'success', '<strong>Success</strong> Rank added.')
    TriggerClientEvent('919-admin:client:ReceiveGangPageInfo', src, Compat.GetMasterGangList())
end)

-- Crews other resources hardcode the name of and would break without.
local UNDELETABLE_CREWS = {
    none = 'every player needs a fallback crew.',
}

RegisterNetEvent('919-admin:server:DeleteCustomCrew', function(crewName)
    local src = source
    if not isAuthorised(src) then return end
    if type(crewName) ~= 'string' or crewName == '' then return end

    local blockedReason = UNDELETABLE_CREWS[crewName]
    if blockedReason then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger',
            ('<strong>Error</strong> \'%s\' cannot be deleted -- %s'):format(crewName, blockedReason))
        return
    end

    local success, message = exports.qbx_core:RemoveGang(crewName, true)
    if success then
        DeleteCrewColor(crewName)
        QBCore.Shared.Gangs[crewName] = nil
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'success', '<strong>Success</strong> Crew deleted.')
        TriggerClientEvent('919-admin:client:ReceiveGangPageInfo', src, Compat.GetMasterGangList())
    else
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger', '<strong>Error</strong> ' .. tostring(message))
    end
end)
