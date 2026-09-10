-- VoidLine: this server runs qbx_core, not legacy qb-core, so
-- exports['qb-core']:GetCoreObject() (the original bridge) does not exist
-- and would error. qbx_core still fires the legacy QBCore:* events for
-- compatibility, so we hook those directly instead of GetCoreObject().
if Config.qbSettings.enabled then
    local function updateJob()
        local playerData = exports.qbx_core:GetPlayerData()
        PLAYER_JOB = playerData and playerData.job and playerData.job.name or nil
    end

    updateJob()

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', updateJob)

    RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
        PLAYER_JOB = val and val.job and val.job.name or PLAYER_JOB
    end)
end
