local IS_SERVER = IsDuplicityVersion()

local function keyOf(stash) return ('of_stash_%s'):format(stash.stash_key or stash.id) end

local function linden()
    return Bridge.started('linden_inventory') and exports.linden_inventory or nil
end

Bridge.register('inventory', {
    name = 'esx',
    priority = 15,
    detect = function()
        return Bridge.started('esx_inventory') or Bridge.started('linden_inventory')
    end,
    build = function()
        local api = { name = 'esx' }

        if IS_SERVER then
            function api.registerStash(stash)
                local inv = linden()
                if inv then
                    local ok, err = pcall(function()
                        inv:RegisterStash(keyOf(stash), stash.label,
                            stash.slots or Config.Stash.defaultSlots,
                            stash.max_weight or Config.Stash.defaultMaxWeight, false)
                    end)
                    if not ok then DEBUG_INT(('esx RegisterStash(%s): %s'):format(keyOf(stash), err)) end
                else
                    Hooks.run('EsxRegisterStash', stash, keyOf(stash))
                end
                return true
            end

            api.refreshStash = api.registerStash

            function api.clearStash(stash)
                local inv = linden()
                if inv then
                    pcall(function() inv:ClearInventory(keyOf(stash)) end)
                else
                    Hooks.run('EsxClearStash', stash, keyOf(stash))
                end
            end

            function api.removeItem(source, item, count)
                local inv = linden()
                if inv then
                    local ok, res = pcall(function() return inv:RemoveItem(source, item, count or 1) end)
                    return ok and res ~= false
                end
                local hooked = Hooks.run('EsxRemoveItem', source, item, count or 1)
                if hooked ~= nil then return hooked and true or false end

                local xPlayer = FW.name == 'esx' and exports['es_extended']:getSharedObject().GetPlayerFromId(source)
                if not xPlayer then return false end
                if xPlayer.getInventoryItem(item).count < (count or 1) then return false end
                xPlayer.removeInventoryItem(item, count or 1)
                return true
            end

            function api.addItem(source, item, count)
                local inv = linden()
                if inv then
                    local ok, res = pcall(function() return inv:AddItem(source, item, count or 1) end)
                    return ok and res ~= false
                end
                local hooked = Hooks.run('EsxAddItem', source, item, count or 1)
                if hooked ~= nil then return hooked and true or false end
                local xPlayer = FW.name == 'esx' and exports['es_extended']:getSharedObject().GetPlayerFromId(source)
                if not xPlayer then return false end
                xPlayer.addInventoryItem(item, count or 1)
                return true
            end

            function api.isStashEmpty(stash)
                local inv = linden()
                if not inv then
                    local hooked = Hooks.run('EsxIsStashEmpty', stash, keyOf(stash))
                    return hooked == nil and true or (hooked and true or false)
                end
                local ok, data = pcall(function() return inv:GetInventory(keyOf(stash)) end)
                if not ok or not data or not data.items then return true end
                for _ in pairs(data.items) do return false end
                return true
            end
        else
            function api.openStash(stash)
                local inv = linden()
                if inv then
                    return pcall(function() exports.linden_inventory:OpenInventory('stash', keyOf(stash)) end)
                end
                local handled = Hooks.run('EsxOpenStash', stash, keyOf(stash))
                if handled == nil then
                    TriggerEvent('esx_inventory:openStash', keyOf(stash))
                end
            end
        end

        return api
    end,
})
