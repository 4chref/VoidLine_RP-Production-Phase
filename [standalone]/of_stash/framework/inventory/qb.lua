local IS_SERVER = IsDuplicityVersion()

local function keyOf(stash) return ('of_stash_%s'):format(stash.stash_key or stash.id) end

local function qb() return exports['qb-inventory'] end
local function has(fn)
    local ok, res = pcall(function() return qb()[fn] ~= nil end)
    return ok and res
end

Bridge.register('inventory', {
    name = 'qb',
    priority = 20,
    detect = function() return Bridge.started('qb-inventory') end,
    build = function()
        local api = { name = 'qb' }

        if IS_SERVER then
            api.serverOpen = has('OpenInventory') -- modern API: the server opens it

            function api.registerStash(stash)
                if not has('CreateInventory') then return true end -- legacy: created lazily on open
                local ok, err = pcall(function()
                    qb():CreateInventory(keyOf(stash), {
                        label = stash.label,
                        maxweight = stash.max_weight or Config.Stash.defaultMaxWeight,
                        slots = stash.slots or Config.Stash.defaultSlots,
                    })
                end)
                if not ok then DEBUG_INT(('qb CreateInventory(%s): %s'):format(keyOf(stash), err)) end
                return true
            end

            api.refreshStash = api.registerStash

            function api.openFor(source, stash)
                local ok, err = pcall(function()
                    qb():OpenInventory(source, keyOf(stash), {
                        maxweight = stash.max_weight or Config.Stash.defaultMaxWeight,
                        slots = stash.slots or Config.Stash.defaultSlots,
                    })
                end)
                if not ok then ERROR_INT(('qb OpenInventory(%s): %s'):format(keyOf(stash), err)) end
            end

            function api.clearStash(stash)
                if not has('ClearInventory') then return end
                local ok, err = pcall(function() qb():ClearInventory(keyOf(stash)) end)
                if not ok then DEBUG_INT(('qb ClearInventory(%s): %s'):format(keyOf(stash), err)) end
            end

            function api.removeItem(source, item, count)
                if not has('RemoveItem') then return false end
                local ok, res = pcall(function() return qb():RemoveItem(source, item, count or 1, nil, 'of_stash') end)
                return ok and res and true or false
            end

            function api.addItem(source, item, count)
                if not has('AddItem') then return false end
                local ok, res = pcall(function() return qb():AddItem(source, item, count or 1, nil, nil, 'of_stash') end)
                return ok and res and true or false
            end

            function api.isStashEmpty(stash)
                if not has('GetInventory') then return true end
                local ok, inv = pcall(function() return qb():GetInventory(keyOf(stash)) end)
                if not ok or not inv or not inv.items then return true end
                for _, slot in pairs(inv.items) do
                    if slot then return false end
                end
                return true
            end
        else
            function api.openStash(stash)
                local slots = stash.slots or Config.Stash.defaultSlots
                local weight = stash.max_weight or Config.Stash.defaultMaxWeight
                TriggerServerEvent('inventory:server:OpenInventory', 'stash', keyOf(stash), { maxweight = weight, slots = slots })
                TriggerEvent('inventory:client:SetCurrentStash', keyOf(stash))
            end
        end

        return api
    end,
})
