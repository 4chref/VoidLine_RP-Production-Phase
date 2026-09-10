local IS_SERVER = IsDuplicityVersion()

local function keyOf(stash) return ('of_stash_%s'):format(stash.stash_key or stash.id) end

Bridge.register('inventory', {
    name = 'ox',
    priority = 30,
    detect = function() return Bridge.started('ox_inventory') end,
    build = function()
        local api = { name = 'ox' }

        if IS_SERVER then
            -- Register (or re-register) a stash with ox_inventory. owner=false → a single shared
            -- container; access is enforced by of_stash before we ever call openStash.
            function api.registerStash(stash)
                local slots = stash.slots or Config.Stash.defaultSlots
                local weight = stash.max_weight or Config.Stash.defaultMaxWeight
                local coords = stash.coords and vec3(stash.coords.x, stash.coords.y, stash.coords.z) or nil
                exports.ox_inventory:RegisterStash(keyOf(stash), stash.label, slots, weight, false, nil, coords)
                return true
            end

            api.refreshStash = api.registerStash

            -- Best-effort wipe of a deleted stash's contents. Guarded: the stash may never have
            -- been instantiated by ox (nobody opened it), in which case there's nothing to clear.
            function api.clearStash(stash)
                local ok, err = pcall(function()
                    exports.ox_inventory:ClearInventory(keyOf(stash))
                end)
                if not ok then DEBUG_INT(('clearStash(%s): %s'):format(keyOf(stash), err)) end
            end

            -- ── Item operations (used by deployable boxes) ───────────────────
            function api.removeItem(source, item, count)
                return exports.ox_inventory:RemoveItem(source, item, count or 1) and true or false
            end

            function api.addItem(source, item, count)
                local ok = exports.ox_inventory:AddItem(source, item, count or 1)
                return ok and true or false
            end

            --- True when the stash holds no items (nil when ox has never instantiated it, which
            --- also means empty).
            function api.isStashEmpty(stash)
                local ok, inv = pcall(function() return exports.ox_inventory:GetInventory(keyOf(stash)) end)
                if not ok or not inv or not inv.items then return true end
                for _ in pairs(inv.items) do return false end
                return true
            end
        else
            function api.openStash(stash)
                exports.ox_inventory:openInventory('stash', keyOf(stash))
            end
        end

        return api
    end,
})
