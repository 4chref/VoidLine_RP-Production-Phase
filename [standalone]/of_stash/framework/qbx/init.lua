local IS_SERVER = IsDuplicityVersion()

Bridge.register('framework', {
    name = 'qbx',
    priority = 30,
    detect = function() return Bridge.started('qbx_core') end,
    build = function()
        local core = exports.qbx_core
        local api = { name = 'qbx' }

        if IS_SERVER then
            local function player(src) return core:GetPlayer(src) end

            function api.getIdentifier(src)
                local p = player(src); return p and p.PlayerData.citizenid or nil
            end

            function api.getName(src)
                local p = player(src); if not p then return 'Unknown' end
                local ci = p.PlayerData.charinfo or {}
                return ('%s %s'):format(ci.firstname or '?', ci.lastname or '?')
            end

            function api.getSource(citizenid)
                local p = exports.qbx_core:GetPlayerByCitizenId(citizenid)
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
                local p = player(src)
                return p and p.PlayerData and p.PlayerData.group or nil
            end

            function api.isAdmin(src)
                local ok, res = pcall(function() return core:HasPermission(src, 'admin') end)
                return (ok and res) and true or false
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
            local function data() return core:GetPlayerData() end

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
