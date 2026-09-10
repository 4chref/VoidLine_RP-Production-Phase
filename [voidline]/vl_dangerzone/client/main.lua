-- Tracks which zones the local player is currently inside, so the alert only
-- fires once on entry rather than every tick while they linger in the radius.
local inside = {}

local function triggerAlert(zone)
    SendNUIMessage({
        action = 'showZoneAlert',
        name = zone.name,
        dangerType = zone.dangerType,
        sound = zone.sound,
        volume = zone.volume or 0.6,
        displayTime = Config.DisplayTime,
    })
end

CreateThread(function()
    while true do
        Wait(Config.CheckInterval)

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for i, zone in ipairs(Config.Zones) do
            local dist = #(coords - zone.coords)

            if dist <= zone.radius then
                if not inside[i] then
                    inside[i] = true
                    triggerAlert(zone)
                end
            else
                inside[i] = false
            end
        end
    end
end)

-- Debug visualization: a flat disc the size of the radius plus a marker at
-- the center, so you can walk up and see exactly where the zone edge is
-- while tweaking `coords`/`radius` in config.lua. Runs every frame like any
-- DrawMarker loop needs to, but only while Config.DebugMarkers is on and
-- only for zones within render distance.
CreateThread(function()
    while Config.DebugMarkers do
        Wait(0)

        local coords = GetEntityCoords(PlayerPedId())

        for _, zone in ipairs(Config.Zones) do
            local dist = #(coords - zone.coords)

            -- Radius is up to 1km, so the draw-distance check has to cover that
            -- plus headroom, or the disc pops in/out right as you cross the edge.
            if dist < zone.radius + 500.0 then
                -- Center pin: tall red cylinder, visible over long distances.
                DrawMarker(
                    1,
                    zone.coords.x, zone.coords.y, zone.coords.z,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    3.0, 3.0, 100.0,
                    255, 0, 0, 180,
                    false, false, 2, false, nil, nil, false
                )

                -- Radius disc, flattened to the ground but given enough height
                -- (5m) to actually catch light and stay visible from a distance
                -- instead of disappearing edge-on like a paper-thin plane.
                DrawMarker(
                    1,
                    zone.coords.x, zone.coords.y, zone.coords.z,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    zone.radius * 2.0, zone.radius * 2.0, 5.0,
                    255, 0, 0, 90,
                    false, false, 2, false, nil, nil, false
                )
            end
        end
    end
end)
