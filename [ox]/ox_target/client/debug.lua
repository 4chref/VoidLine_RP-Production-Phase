AddEventHandler('qb-target:debug', function(data)
    if data.entity and GetEntityType(data.entity) > 0 then
        data.archetype = GetEntityArchetypeName(data.entity)
        data.model = GetEntityModel(data.entity)
    end

	print(json.encode(data, {indent=true}))
end)

if GetConvarInt('qb-target:debug', 0) ~= 1 then return end

local qb_target = exports['qb-target']
local drawZones = true

qb_target:addBoxZone({
    coords = vec3(442.5363, -1017.666, 28.85637),
    size = vec3(3, 3, 3),
    rotation = 45,
    debug = drawZones,
    drawSprite = true,
    options = {
        {
            name = 'debug_box',
            event = 'qb-target:debug',
            icon = 'fa-solid fa-cube',
            label = locale('debug_box'),
        }
    }
})

qb_target:addSphereZone({
    coords = vec3(440.5363, -1015.666, 28.85637),
    radius = 3,
    debug = drawZones,
    drawSprite = true,
    options = {
        {
            name = 'debug_sphere',
            event = 'qb-target:debug',
            icon = 'fa-solid fa-circle',
            label = locale('debug_sphere'),
        }
    }
})

qb_target:addModel(`police`, {
    {
        name = 'debug_model',
        event = 'qb_target:debug',
        icon = 'fa-solid fa-handcuffs',
        label = locale('debug_police_car'),
    }
})

qb_target:addGlobalPed({
    {
        name = 'debug_ped',
        event = 'qb_target:debug',
        icon = 'fa-solid fa-male',
        label = locale('debug_ped'),
    }
})

qb_target:addGlobalVehicle({
    {
        name = 'debug_vehicle',
        event = 'qb_target:debug',
        icon = 'fa-solid fa-car',
        label = locale('debug_vehicle'),
    }
})

qb_target:addGlobalObject({
    {
        name = 'debug_object',
        event = 'qb_target:debug',
        icon = 'fa-solid fa-bong',
        label = locale('debug_object'),
    }
})

qb_target:addGlobalOption({
    {
        name = 'debug_global',
        icon = 'fa-solid fa-globe',
        label = locale('debug_global'),
        openMenu = 'debug_global'
    }
})

qb_target:addGlobalOption({
    {
        name = 'debug_global2',
        event = 'qb_target:debug',
        icon = 'fa-solid fa-globe',
        label = locale('debug_global') .. ' 2',
        menuName = 'debug_global'
    }
})