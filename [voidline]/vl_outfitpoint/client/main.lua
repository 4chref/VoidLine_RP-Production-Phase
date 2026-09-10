-- -----------------------------------------------------------------------------
-- Indicators: blip, GPS route, in-world marker -- same style as vl_jobs
-- (electricity/cleaning/crates), adapted for this single fixed point.
-- -----------------------------------------------------------------------------

CreateThread(function()
    local ind = Config.Indicator
    if not ind.blip then return end

    local blip = AddBlipForCoord(Config.Coords.x, Config.Coords.y, Config.Coords.z)
    SetBlipSprite(blip, ind.blipSprite or 402)
    SetBlipColour(blip, ind.blipColour or 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(ind.blipName or 'Outfit Point')
    EndTextCommandSetBlipName(blip)

    if ind.gpsRoute then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, ind.routeColour or 5)
    end
end)

CreateThread(function()
    local ind = Config.Indicator
    while true do
        local sleep = 500

        if ind.marker then
            local pos = GetEntityCoords(PlayerPedId())
            local p = Config.Coords
            local d = #(pos - vec3(p.x, p.y, p.z))

            if d <= (ind.markerDrawDistance or 60.0) then
                sleep = 0
                local bob = ind.markerBob and (math.sin(GetGameTimer() / 400.0) * 0.12) or 0.0
                DrawMarker(
                    ind.markerType or 21,
                    p.x, p.y, p.z + 1.0 + bob,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    ind.markerSize.x, ind.markerSize.y, ind.markerSize.z,
                    240, 190, 60, 160,
                    false, true, 2, false, nil, nil, false
                )
            end
        end

        Wait(sleep)
    end
end)

local function wearOutfit()
    local ped = PlayerPedId()

    for i = 1, #Config.Outfit.components do
        local c = Config.Outfit.components[i]
        exports['illenium-appearance']:setPedComponent(ped, {
            component_id = c.component_id,
            drawable = c.drawable,
            texture = c.texture,
        })
    end

    for i = 1, #Config.Outfit.props do
        local p = Config.Outfit.props[i]
        exports['illenium-appearance']:setPedProp(ped, {
            prop_id = p.prop_id,
            drawable = p.drawable,
            texture = p.texture,
        })
    end

    local appearance = exports['illenium-appearance']:getPedAppearance(ped)
    if appearance then
        TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
    end

    exports.qbx_core:Notify('You changed into the outfit.', 'success')
end

CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = vec3(Config.Coords.x, Config.Coords.y, Config.Coords.z),
        size = vec3(1.5, 1.5, 2.2),
        rotation = Config.Coords.w,
        debug = false,
        options = {
            {
                name = 'vl_outfitpoint_wear',
                icon = 'fa-solid fa-shirt',
                label = 'Wear Outfit',
                distance = Config.InteractDistance,
                onSelect = wearOutfit,
            },
        },
    })
end)
