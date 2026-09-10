local IS_SERVER = IsDuplicityVersion()

Bridge.register('framework', {
    name = 'esx',
    priority = 20,
    detect = function() return Bridge.started('es_extended') end,
    build = function()
        local esx = exports['es_extended']:getSharedObject()
        local api = { name = 'esx' }

        if IS_SERVER then
            local function xplayer(src) return esx.GetPlayerFromId(src) end

            function api.getIdentifier(src)
                local x = xplayer(src); return x and x.identifier or nil
            end

            function api.getName(src)
                local x = xplayer(src); return x and x.getName() or 'Unknown'
            end

            function api.getSource(identifier)
                local x = esx.GetPlayerFromIdentifier(identifier)
                return x and x.source or nil
            end

            function api.getJob(src)
                local x = xplayer(src); if not x then return nil end
                local job = x.getJob() or {}
                return job.name, job.grade or 0
            end

            function api.getGang() return nil end -- ESX has no gangs

            function api.getGroup(src)
                local x = xplayer(src); return x and x.getGroup() or nil
            end

            function api.isAdmin(src)
                local x = xplayer(src)
                local group = x and x.getGroup()
                return group == 'admin' or group == 'superadmin'
            end

            function api.getMoney(src, account)
                local x = xplayer(src); if not x then return 0 end
                if account == 'cash' then return x.getMoney() end
                local acc = x.getAccount(account)
                return acc and acc.money or 0
            end

            function api.removeMoney(src, account, amount, reason)
                local x = xplayer(src); if not x then return false end
                if account == 'cash' then
                    if x.getMoney() < amount then return false end
                    x.removeMoney(amount, reason or 'of_stash'); return true
                end
                local acc = x.getAccount(account)
                if not acc or acc.money < amount then return false end
                x.removeAccountMoney(account, amount, reason or 'of_stash'); return true
            end

            function api.addMoney(src, account, amount, reason)
                local x = xplayer(src); if not x then return false end
                if account == 'cash' then x.addMoney(amount, reason or 'of_stash')
                else x.addAccountMoney(account, amount, reason or 'of_stash') end
                return true
            end
        else
            function api.getIdentifier()
                local d = esx.GetPlayerData() or {}
                return d.identifier
            end

            function api.getJob()
                local job = (esx.GetPlayerData() or {}).job or {}
                return job.name, job.grade or 0
            end

            function api.getGang() return nil end
        end

        return api
    end,
})
