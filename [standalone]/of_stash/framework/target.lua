if IsDuplicityVersion() then return end

local function optionList(opts)
    if opts.options then return opts.options end
    return { { label = opts.label, icon = opts.icon, onSelect = opts.onSelect, distance = opts.distance } }
end

-- ox_target
Bridge.register('target', {
    name = 'ox_target',
    priority = 30,
    detect = function() return Bridge.started('ox_target') end,
    build = function()
        local api = { name = 'ox_target', hasTarget = true }

        local function toOx(id, opts)
            local out = {}
            for i, o in ipairs(optionList(opts)) do
                out[i] = {
                    name = ('%s_%d'):format(id, i),
                    icon = o.icon or 'fa-solid fa-box-archive',
                    label = o.label or T('prompt_open'),
                    distance = o.distance or 2.0,
                    onSelect = o.onSelect,
                    canInteract = o.canInteract,
                }
            end
            return out
        end

        function api.addZone(id, coords, opts)
            return exports.ox_target:addSphereZone({
                coords = vec3(coords.x, coords.y, coords.z),
                radius = opts.radius or 1.0,
                debug = Config.debug,
                options = toOx(id, opts),
            })
        end

        function api.addEntityZone(entity, opts)
            return exports.ox_target:addLocalEntity(entity, toOx(('of_stash_ent_%s'):format(entity), opts))
        end

        function api.removeZone(handle)
            if handle then exports.ox_target:removeZone(handle) end
        end

        function api.removeEntityZone(entity)
            if entity and DoesEntityExist(entity) then exports.ox_target:removeLocalEntity(entity) end
        end

        return api
    end,
})

-- qb-target
Bridge.register('target', {
    name = 'qb-target',
    priority = 20,
    detect = function() return Bridge.started('qb-target') end,
    build = function()
        local api = { name = 'qb-target', hasTarget = true }

        local function toQb(opts)
            local out = {}
            for i, o in ipairs(optionList(opts)) do
                out[i] = {
                    icon = o.icon or 'fas fa-box-archive',
                    label = o.label or T('prompt_open'),
                    action = o.onSelect,
                    canInteract = o.canInteract,
                    distance = o.distance or 2.0,
                }
            end
            return out
        end

        function api.addZone(id, coords, opts)
            exports['qb-target']:AddCircleZone(id, vec3(coords.x, coords.y, coords.z), opts.radius or 1.0, {
                name = id,
                debugPoly = Config.debug,
            }, {
                options = toQb(opts),
                distance = opts.distance or 2.0,
            })
            return id -- qb-target removes by zone name
        end

        function api.addEntityZone(entity, opts)
            exports['qb-target']:AddTargetEntity(entity, {
                options = toQb(opts),
                distance = opts.distance or 2.0,
            })
            return entity
        end

        function api.removeZone(handle)
            if handle then exports['qb-target']:RemoveZone(handle) end
        end

        function api.removeEntityZone(entity)
            if entity then exports['qb-target']:RemoveTargetEntity(entity) end
        end

        return api
    end,
})

Bridge.register('target', {
    name = 'marker',
    priority = -100,
    detect = function() return true end,
    build = function()
        local zones = {}
        local api = { name = 'marker', hasTarget = false, zones = zones }

        function api.addZone(id, coords, opts)
            zones[id] = { coords = coords, opts = opts }
            return id
        end

        function api.removeZone(handle)
            if handle then zones[handle] = nil end
        end

        -- no target resource
        function api.addEntityZone() return nil end
        function api.removeEntityZone() end

        return api
    end,
})
