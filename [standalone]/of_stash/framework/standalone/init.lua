-- Standalone framework adapter. No framework core: identity is the player's license, there is
-- no job/gang registry, and money operations defer to config/hooks.lua (a server without a
-- framework still usually has *some* economy). This is the lowest-priority fallback and always
-- detects true, so resolution only lands here when nothing else matched.
local IS_SERVER = IsDuplicityVersion()

Bridge.register('framework', {
    name = 'standalone',
    priority = -100,
    detect = function() return true end,
    build = function()
        local api = { name = 'standalone' }

        if IS_SERVER then
            function api.getIdentifier(src)
                for _, id in ipairs(GetPlayerIdentifiers(src)) do
                    if id:sub(1, 8) == 'license:' then return id end
                end
                return nil
            end

            function api.getName(src) return GetPlayerName(src) or 'Unknown' end

            function api.getSource(identifier)
                for _, pid in ipairs(GetPlayers()) do
                    local src = tonumber(pid)
                    if src and api.getIdentifier(src) == identifier then return src end
                end
                return nil
            end

            function api.getJob() return nil end
            function api.getGang() return nil end
            function api.getGroup(src) return IsPlayerAceAllowed(src, 'of_stash.admin') and 'admin' or 'user' end
            function api.isAdmin(src) return IsPlayerAceAllowed(src, 'of_stash.admin') end

            -- Economy: no framework, so route through hooks. Owners can wire these to any system.
            -- nil = "balance unknown" — Server.charge then trusts removeMoney's hook instead.
            function api.getMoney() return nil end
            function api.removeMoney(src, account, amount)
                local res = Hooks.run('StandaloneRemoveMoney', src, account, amount)
                if res == nil then return true end -- no hook wired: don't block purchases in dev
                return res and true or false
            end
            function api.addMoney(src, account, amount)
                Hooks.run('StandaloneAddMoney', src, account, amount)
                return true
            end
        else
            function api.getIdentifier() return nil end -- server-authoritative in standalone
            function api.getJob() return nil end
            function api.getGang() return nil end
        end

        return api
    end,
})
