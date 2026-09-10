Config = {}

Config.Coords = vector4(3086.93, 5462.88, 23.65, 114)
Config.InteractDistance = 1.5

-- Same indicator style as vl_jobs (electricity/cleaning/crates): a
-- persistent map blip with a GPS route line, plus an in-world floating
-- arrow marker so the point is findable without opening the map.
Config.Indicator = {
    blip = true,
    blipSprite = 402,
    blipColour = 5,      -- yellow
    blipName = 'Outfit Point',

    gpsRoute = true,
    routeColour = 5,      -- yellow

    marker = true,
    markerType = 21,       -- 21 = the floating downward arrow
    markerSize = vec3(0.35, 0.35, 0.25),
    markerBob = true,      -- gentle up/down float
    markerDrawDistance = 60.0,   -- only drawn within this range, in metres
}

-- component_id reference (illenium-appearance / GTA V ped components):
-- 1 mask, 3 arms/hands, 4 legs, 5 bags/parachute, 6 shoes, 7 scarf/chains,
-- 8 shirt (undershirt), 9 body armor, 10 decals, 11 jacket (torso2)
Config.Outfit = {
    components = {
        {component_id = 1, drawable = 211, texture = 21},  -- mask
        {component_id = 3, drawable = 74, texture = 0},    -- hands
        {component_id = 4, drawable = 259, texture = 9},   -- legs
        {component_id = 5, drawable = 0, texture = 0},     -- bags/parachute: nothing
        {component_id = 6, drawable = 153, texture = 1},   -- shoes
        {component_id = 7, drawable = 179, texture = 0},   -- scarf/chains
        {component_id = 8, drawable = 15, texture = 0},    -- shirt
        {component_id = 9, drawable = 124, texture = 2},   -- body armor
        {component_id = 10, drawable = 0, texture = 0},    -- decals: nothing
        {component_id = 11, drawable = 667, texture = 9},  -- jacket
    },
    -- prop_id reference: 0 hats/helmets, 1 glasses
    props = {
        {prop_id = 0, drawable = 104, texture = 22},  -- hat/helmet
        {prop_id = 1, drawable = 52, texture = 0},    -- glasses
    },
}
