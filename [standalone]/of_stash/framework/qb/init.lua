local IS_SERVER = IsDuplicityVersion()

Bridge.register('framework', {
    name = 'qb',
    priority = 20,
    detect = function() return Bridge.started('qb-core') end,
    build = function()
        local core = exports['qb-core']:GetCoreObject()
        local api = { name = 'qb' }

        if IS_SERVER then
            local function player(src) return core.Functions.GetPlayer(src) end

            function api.getIdentifier(src)
                local p = player(src); return p and p.PlayerData.citizenid or nil
            end

            function api.getName(src)
                local p = player(src); if not p then return 'Unknown' end
                local ci = p.PlayerData.charinfo or {}
                return ('%s %s'):format(ci.firstname or '?', ci.lastname or '?')
            end

            function api.getSource(citizenid)
                local p = core.Functions.GetPlayerByCitizenId(citizenid)
                return p and p.PlayerData.source or nil
            end

            function api.getJob(src)
                local p = player(src); if not p then return nil end
                local job = p.PlayerData.job or {}
                return job.name, (job.grade and job.grade.level) or 0
            end

            function api.getGang(src)
                local p = player(src); if not p then return nil end
                local gang = p.PlayerData.gang or {}
                return gang.name, (gang.grade and gang.grade.level) or 0
            end

            function api.getGroup(src)
                -- qb returns a permission string or table depending on version; normalise to string.
                local perm = core.Functions.GetPermission and core.Functions.GetPermission(src)
                if type(perm) == 'table' then return perm[1] end
                return perm
            end

            function api.isAdmin(src)
                if core.Functions.HasPermission then
                    return core.Functions.HasPermission(src, 'admin') or core.Functions.HasPermission(src, 'god')
                end
                return IsPlayerAceAllowed(src, 'command')
            end

            function api.getMoney(src, account)
                local p = player(src); if not p then return 0 end
                return p.PlayerData.money[account] or 0
            end

            function api.removeMoney(src, account, amount, reason)
                local p = player(src); if not p then return false end
                return p.Functions.RemoveMoney(account, amount, reason or 'of_stash') and true or false
            end

            function api.addMoney(src, account, amount, reason)
                local p = player(src); if not p then return false end
                return p.Functions.AddMoney(account, amount, reason or 'of_stash') and true or false
            end
        else
            local function data() return core.Functions.GetPlayerData() end

            function api.getIdentifier()
                local d = data(); return d and d.citizenid or nil
            end

            function api.getJob()
                local job = (data() or {}).job or {}
                return job.name, (job.grade and job.grade.level) or 0
            end

            function api.getGang()
                local gang = (data() or {}).gang or {}
                return gang.name, (gang.grade and gang.grade.level) or 0
            end
        end

        return api
    end,
})
