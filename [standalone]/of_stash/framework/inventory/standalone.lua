local IS_SERVER = IsDuplicityVersion()

local function keyOf(stash) return ('of_stash_%s'):format(stash.stash_key or stash.id) end

Bridge.register('inventory', {
    name = 'standalone',
    priority = -100,
    detect = function() return true end,
    build = function()
        local api = { name = 'standalone' }

        if IS_SERVER then
            function api.registerStash(stash) Hooks.run('StandaloneRegisterStash', stash, keyOf(stash)); return true end
            function api.refreshStash(stash) Hooks.run('StandaloneRegisterStash', stash, keyOf(stash)); return true end
            function api.clearStash(stash) Hooks.run('StandaloneClearStash', stash, keyOf(stash)) end

            function api.removeItem(source, item, count)
                local res = Hooks.run('StandaloneRemoveItem', source, item, count or 1)
                return res ~= nil and res and true or false
            end

            function api.addItem(source, item, count)
                local res = Hooks.run('StandaloneAddItem', source, item, count or 1)
                return res ~= nil and res and true or false
            end

            function api.isStashEmpty(stash)
                local res = Hooks.run('StandaloneIsStashEmpty', stash, keyOf(stash))
                return res == nil and true or (res and true or false)
            end
        else
            function api.openStash(stash)
                local handled = Hooks.run('StandaloneOpenStash', stash, keyOf(stash))
                if handled == nil then
                    print(('^3[of_stash]^0 No inventory adapter is wired. Set Config.Inventory or Hooks.StandaloneOpenStash to open stash "%s".'):format(keyOf(stash)))
                end
            end
        end

        return api
    end,
})
