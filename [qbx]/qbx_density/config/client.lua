return {
    -- Density of various things in the world
    -- Minimum value is 0.0, maximum value is 1.0
    -- Value of 1.0 represents GTA Online populate rates
    -- Value of 0.0 removes all of that type
    --
    -- VoidLine: everything is 0.0 -- the world is meant to be empty. vl_apocalypse
    -- reinforces this and also clears entities that are already spawned. Raising
    -- these values here will fight that resource, so change it there instead.
    parked = 0.0, -- Density of parked vehicles
    vehicle = 0.0, -- Density of vehicles
    randomvehicles = 0.0, -- Density of random vehicles
    peds = 0.0, -- Density of random peds (civilians, etc.)
    scenario = 0.0, -- Density of scenario peds (bikers, gangsters, etc.)
}
