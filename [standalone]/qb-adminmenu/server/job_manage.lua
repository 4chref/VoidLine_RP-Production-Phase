-- VoidLine: Create Job, exposed from the Jobs page. Uses qbx_core's own
-- CreateJob export (server/groups.lua) with commitToFile=true, so this
-- writes straight into qbx_core/shared/jobs.lua -- the officially supported
-- way to manage jobs at runtime, not a manual file edit. No colour here --
-- ShowNames colours by crew (gang) only, see server/crew_colors.lua.

local function isAuthorised(src)
    return AdminPanel.HasPermissionEx(src, 'jobpage')
end

---@param name string
---@return boolean ok
---@return string? reason
local function validateJobName(name)
    if type(name) ~= 'string' or name == '' then
        return false, 'Job name is required.'
    end
    if name:match('%s') then
        return false, 'Job name cannot contain spaces.'
    end
    if name ~= name:lower() then
        return false, 'Job name must be lower case.'
    end
    if not name:match('^[a-z0-9_]+$') then
        return false, 'Job name can only contain a-z, 0-9 and underscores.'
    end
    return true
end

RegisterNetEvent('919-admin:server:CreateCustomJob', function(data)
    local src = source
    if not isAuthorised(src) then return end

    local name = data and data.name
    local ok, reason = validateJobName(name)
    if not ok then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger', '<strong>Error</strong> ' .. reason)
        return
    end

    local gradeName = (data.gradeName and data.gradeName ~= '') and data.gradeName or 'Employee'

    local jobs = exports.qbx_core:GetJobs()
    if jobs and jobs[name] then
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger',
            ('<strong>Error</strong> Job \'%s\' already exists.'):format(name))
        return
    end

    local job = {
        label = name,
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = gradeName },
        },
    }

    local success, message = exports.qbx_core:CreateJob(name, job, true)
    if success then
        -- QBCore.Shared.Jobs (from exports['qb-core']:GetCoreObject(), a
        -- cross-resource export call) is a one-time snapshot taken when this
        -- resource started, not a live view of qbx_core's jobs table -- and
        -- adminactions.lua's SetJob validation and this panel's own job list
        -- both read from it, so patch it directly (both key forms -- see
        -- crew_manage.lua for why) or the new job won't show or be
        -- assignable until a restart.
        QBCore.Shared.Jobs[name] = {
            label = name,
            defaultDuty = true,
            offDutyPay = false,
            grades = {
                [0] = { name = gradeName },
                ['0'] = { name = gradeName },
            },
        }
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'success', '<strong>Success</strong> Job created.')
        TriggerClientEvent('919-admin:client:ReceiveJobPageInfo', src, Compat.GetMasterEmployeeList())
    else
        TriggerClientEvent('919-admin:client:ShowPanelAlert', src, 'danger', '<strong>Error</strong> ' .. tostring(message))
    end
end)
