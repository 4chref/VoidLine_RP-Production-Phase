-- Compatibility shim: registers old-style qb-target PascalCase exports under the
-- 'qb-target' resource name so that scripts calling
--   exports['qb-target']:AddTargetModel / AddBoxZone / AddGlobalPlayer / AddTargetEntity / etc.
-- continue to work against this ox_target-based resource.

local function exportHandler(exportName, func)
    AddEventHandler(('__cfx_export_qb-target_%s'):format(exportName), function(setCB)
        setCB(func)
    end)
end

---Convert old qtarget/qb-target option table format to ox_target option format.
---Accepts both:
---  { options = { ... }, distance = n }  (outer wrapper style)
---  { { label=, action=, ... }, ... }    (plain array style)
---@param raw table
---@return table
local function convert(raw)
    local distance = raw.distance
    local options   = raw.options or raw   -- unwrap outer wrapper if present

    -- People may pass options as a hashmap (or mixed, even)
    for k, v in pairs(options) do
        if type(k) ~= 'number' then
            table.insert(options, v)
        end
    end

    for id, v in pairs(options) do
        if type(id) ~= 'number' then
            options[id] = nil
            goto continue
        end

        v.onSelect  = v.action or v.onSelect
        v.distance  = v.distance or distance
        v.name      = v.name or v.label
        v.groups    = v.job or v.groups
        v.items     = v.item or v.required_item or v.items

        if v.event and v.type and v.type ~= 'client' then
            if v.type == 'server' then
                v.serverEvent = v.event
            elseif v.type == 'command' then
                v.command = v.event
            end
            v.event = nil
            v.type  = nil
        end

        v.action         = nil
        v.job            = nil
        v.item           = nil
        v.required_item  = nil

        ::continue::
    end

    return options
end

local api = require 'client.api'

-- ─── Zone-based targets ───────────────────────────────────────────────────────

exportHandler('AddBoxZone', function(name, center, length, width, options, targetoptions)
    if not options.minZ then options.minZ = -100 end
    if not options.maxZ then options.maxZ = 800  end

    local z = center.z
    if not options.useZ then
        z      = z + math.abs(options.maxZ - options.minZ) / 2
        center = vec3(center.x, center.y, z)
    end

    return api.addBoxZone({
        name     = name,
        coords   = center,
        size     = vec3(width, length,
            (options.useZ or not options.maxZ) and center.z
                or math.abs(options.maxZ - options.minZ)),
        debug    = options.debugPoly,
        rotation = options.heading,
        options  = convert(targetoptions),
    })
end)

exportHandler('AddPolyZone', function(name, points, options, targetoptions)
    local thickness = math.abs(options.maxZ - options.minZ)
    local newPoints = table.create(#points, 0)

    for i = 1, #points do
        local p     = points[i]
        newPoints[i] = vec3(p.x, p.y, options.maxZ - (thickness / 2))
    end

    return api.addPolyZone({
        name      = name,
        points    = newPoints,
        thickness = thickness,
        debug     = options.debugPoly,
        options   = convert(targetoptions),
    })
end)

exportHandler('AddCircleZone', function(name, center, radius, options, targetoptions)
    return api.addSphereZone({
        name    = name,
        coords  = center,
        radius  = radius,
        debug   = options.debugPoly,
        options = convert(targetoptions),
    })
end)

exportHandler('RemoveZone', function(id)
    api.removeZone(id, true)
end)

-- ─── Entity targets ───────────────────────────────────────────────────────────

exportHandler('AddTargetEntity', function(entities, options)
    if type(entities) ~= 'table' then entities = { entities } end
    options = convert(options)

    for i = 1, #entities do
        local entity = entities[i]
        if NetworkGetEntityIsNetworked(entity) then
            api.addEntity(NetworkGetNetworkIdFromEntity(entity), options)
        else
            api.addLocalEntity(entity, options)
        end
    end
end)

exportHandler('RemoveTargetEntity', function(entities, labels)
    if type(entities) ~= 'table' then entities = { entities } end

    for i = 1, #entities do
        local entity = entities[i]
        if NetworkGetEntityIsNetworked(entity) then
            api.removeEntity(NetworkGetNetworkIdFromEntity(entity), labels)
        else
            api.removeLocalEntity(entity, labels)
        end
    end
end)

-- ─── Model targets ────────────────────────────────────────────────────────────

exportHandler('AddTargetModel', function(models, options)
    api.addModel(models, convert(options))
end)

exportHandler('RemoveTargetModel', function(models, labels)
    api.removeModel(models, labels)
end)

-- ─── Bone targets ─────────────────────────────────────────────────────────────

exportHandler('AddTargetBone', function(bones, options)
    if type(bones) ~= 'table' then bones = { bones } end
    options = convert(options)

    for _, v in pairs(options) do
        v.bones = bones
    end

    api.addGlobalVehicle(options)
end)

exportHandler('RemoveTargetBone', function(bones, labels)
    api.removeGlobalVehicle(labels)
end)

-- ─── Global player/vehicle/ped/object ────────────────────────────────────────

exportHandler('AddGlobalPlayer', function(options)
    api.addGlobalPlayer(convert(options))
end)

exportHandler('RemoveGlobalPlayer', function(labels)
    api.removeGlobalPlayer(labels)
end)

exportHandler('AddGlobalVehicle', function(options)
    api.addGlobalVehicle(convert(options))
end)

exportHandler('RemoveGlobalVehicle', function(labels)
    api.removeGlobalVehicle(labels)
end)

exportHandler('AddGlobalPed', function(options)
    api.addGlobalPed(convert(options))
end)

exportHandler('RemoveGlobalPed', function(labels)
    api.removeGlobalPed(labels)
end)

exportHandler('AddGlobalObject', function(options)
    api.addGlobalObject(convert(options))
end)

exportHandler('RemoveGlobalObject', function(labels)
    api.removeGlobalObject(labels)
end)

-- Legacy single-word aliases (used by some older scripts)
exportHandler('Player',        function(options) api.addGlobalPlayer(convert(options))  end)
exportHandler('RemovePlayer',  function(labels)  api.removeGlobalPlayer(labels)         end)
exportHandler('Vehicle',       function(options) api.addGlobalVehicle(convert(options)) end)
exportHandler('RemoveVehicle', function(labels)  api.removeGlobalVehicle(labels)        end)
exportHandler('Ped',           function(options) api.addGlobalPed(convert(options))     end)
exportHandler('RemovePed',     function(labels)  api.removeGlobalPed(labels)            end)
exportHandler('Object',        function(options) api.addGlobalObject(convert(options))  end)
exportHandler('RemoveObject',  function(labels)  api.removeGlobalObject(labels)         end)

-- ─── Misc ─────────────────────────────────────────────────────────────────────

-- AllowTargeting(true) = enable, AllowTargeting(false) = disable
exportHandler('AllowTargeting', function(bool)
    api.disableTargeting(not bool)
end)
