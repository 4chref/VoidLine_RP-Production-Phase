Config = {}

-- =============================================================================
-- vl_apocalypse -- configuration
--
-- Stops NPC-driven traffic and ambient aircraft, and removes the ones that are
-- already in the world.
--
-- WHY THIS EXISTS WHEN qbx_density ALREADY SETS EVERYTHING TO 0.0
-- ==============================================================
-- Because density multipliers do not cover what you were actually seeing.
--
--   * The five SetXDensityMultiplierThisFrame natives control ground traffic,
--     parked cars and pedestrians. They do NOT control aircraft. Ambient
--     helicopters and planes come from vehicle generators and scenario points
--     and ignore the traffic density entirely -- which is why the sky still had
--     a Maverick in it with every multiplier at zero.
--   * A density of 0.0 stops new spawns. It does not delete what already
--     exists, so anything that spawned before you arrived, or before the
--     resource started, just stays there.
--   * qbx_smallresources/qbx_ignore suppresses ten aircraft models -- SHAMAL,
--     LUXOR, JET, LAZER, TITAN and a few ground vehicles. It does not list
--     MAVERICK, POLMAV, FROGGER, BUZZARD, SWIFT, VOLATUS, CUBAN800, DODO,
--     MAMMATUS, VELUM or any of the other models the ambient air traffic
--     actually uses.
--
-- So this resource fills those three gaps and nothing else. It deliberately
-- does NOT set the density multipliers while qbx_density is running -- see
-- Config.Density.
--
-- HOW ENTITIES ARE JUDGED SAFE TO DELETE
-- ======================================
-- GetEntityPopulationType, not guesswork. The engine tags every entity with how
-- it came into the world, and the RANDOM_* types are exactly the ambient
-- population. A player's car is PERMANENT or MISSION and can never match, which
-- is what makes the sweep safe to run continuously. See Config.Cleanup.
-- =============================================================================


-- =============================================================================
-- 1. MAIN SWITCH
-- =============================================================================

-- Master switch. false = the resource loads, registers its command and does
-- nothing else.
Config.Enabled = true

-- ACE object required for /apocalypse. permissions.cfg already grants `admin`
-- to group.admin, so no server.cfg change is needed. The server console always
-- passes.
Config.Ace = 'admin'

-- Remember on/off across restarts, in apocalypse_state.json next to this file.
Config.Persist = true


-- =============================================================================
-- 2. CLEANUP -- removing what is already there
--
-- A sweep over GetGamePool('CVehicle'), deleting ambient vehicles. This is the
-- part that makes the world empty NOW rather than eventually.
--
-- SAFETY
-- ======
-- Nothing is deleted unless GetEntityPopulationType says it is ambient. The
-- engine's population types are:
--
--    0 UNKNOWN          6 PERMANENT   <- player and scripted vehicles
--    1 RANDOM_PERMANENT 7 MISSION     <- player and scripted vehicles
--    2 RANDOM_PARKED    8 REPLAY
--    3 RANDOM_PATROL    9 CACHE
--    4 RANDOM_SCENARIO 10 TOOL
--    5 RANDOM_AMBIENT
--
-- Only 1-5 are ever touched. On top of that, a vehicle is skipped if any player
-- is inside it, if it is a mission entity, if it is attached to something, or
-- if it is networked -- so a job vehicle, a garage spawn, another player's car
-- and a tow-truck load are all safe by four independent tests, not one.
-- =============================================================================

Config.Cleanup = {
    -- How often to sweep, in ms. This walks the vehicle pool, so it is the one
    -- recurring cost in this resource. 1000 is imperceptible; raise it to 2500
    -- if you want it cheaper, lower it only if vehicles are visibly lingering.
    IntervalMs = 1000,

    -- WHAT TO DELETE. All three are ambient-only regardless.

    -- Vehicles with a non-player ped at the wheel. This is the "cars driven by
    -- random NPCs" case directly.
    NpcDriven = true,

    -- Ambient helicopters and planes, moving or not, crewed or not. Vehicle
    -- classes 15 and 16. This is the "helicopter" case, and it has to be
    -- separate from NpcDriven because an ambient aircraft that has not spawned
    -- its pilot yet would otherwise slip through the sweep.
    Aircraft = true,

    -- Every remaining ambient vehicle, including empty parked ones.
    --
    -- OFF by default because it is a bigger change than what was asked for, and
    -- because an entirely carless street reads as a film set rather than an
    -- abandoned city -- a few dead vehicles at the kerb sell the look. Turn it
    -- on for a genuinely swept-clean world.
    AllAmbient = false,

    -- Delete the NPCs sitting in a vehicle that is being removed. Without this
    -- they are left standing in the road where the car used to be.
    -- Only ever applies to occupants of a vehicle already judged deletable.
    Occupants = true,

    -- Ceiling on deletions per sweep. Arriving somewhere dense can otherwise
    -- delete a hundred entities in one frame and cause a visible hitch; the
    -- leftovers are picked up by the next sweep a second later.
    MaxPerSweep = 24,

    -- Skip anything the network knows about. Ambient population is client-local
    -- in FiveM, so this only ever excludes scripted and player vehicles.
    --
    -- If you ever find ambient traffic surviving the sweep, this is the first
    -- thing to try turning off -- but understand that it removes one of the
    -- four guards protecting player vehicles, leaving the population-type test
    -- doing that job alone.
    SkipNetworked = true,
}


-- =============================================================================
-- 3. SUPPRESSION -- stopping them spawning in the first place
--
-- Cheaper than deleting them a second later, so the sweep has less to do.
-- SetVehicleModelIsSuppressed persists once set; it is re-asserted on a slow
-- tick only because other resources can clear it.
-- =============================================================================

-- Ambient AIRCRAFT. This list is the actual gap: none of these except SHAMAL,
-- LUXOR, JET, LAZER and TITAN are suppressed anywhere else on this server.
--
-- MAVERICK and POLMAV are the two you were almost certainly watching -- they
-- are the helicopters GTA V flies over Los Santos by default.
--
-- Models not in this list are still caught by Config.Cleanup.Aircraft; the list
-- only needs to cover what commonly spawns, not every aircraft in the game.
Config.SuppressAircraft = {
    -- helicopters
    'maverick', 'polmav', 'frogger', 'frogger2', 'buzzard', 'buzzard2',
    'swift', 'swift2', 'supervolito', 'supervolito2', 'volatus', 'seasparrow',
    'havok', 'annihilator', 'cargobob', 'cargobob2', 'cargobob3', 'skylift',
    'valkyrie', 'savage',
    -- planes
    'shamal', 'luxor', 'luxor2', 'jet', 'lazer', 'titan', 'cuban800', 'dodo',
    'duster', 'mammatus', 'stunt', 'velum', 'velum2', 'vestra', 'nimbus',
    'miljet', 'besra', 'blimp', 'blimp2', 'cargoplane',
    -- airport ground vehicles, which read as traffic on the runway
    'airtug', 'ripley', 'crusader', 'rhino',
}

-- Emergency and service vehicles. Dispatch is already disabled by
-- qbx_smallresources/qbx_disableservices, but scenario-spawned ones are not
-- dispatch and come through anyway.
Config.SuppressEmergency = {
    'police', 'police2', 'police3', 'police4', 'policeb', 'policeold1',
    'policeold2', 'policet', 'sheriff', 'sheriff2', 'fbi', 'fbi2', 'riot',
    'pranger', 'ambulance', 'firetruk', 'lguard',
}

-- Scenario types that place a vehicle or put a ped into one. Disabling these
-- stops the world spawning parked-and-idling traffic at scenario points, which
-- density multipliers do not reach.
Config.DisableScenarioTypes = {
    'WORLD_VEHICLE_ATTRACTOR',
    'WORLD_VEHICLE_AMBULANCE',
    'WORLD_VEHICLE_BICYCLE_BMX',
    'WORLD_VEHICLE_BICYCLE_BMX_BALLAS',
    'WORLD_VEHICLE_BICYCLE_BMX_FAMILY',
    'WORLD_VEHICLE_BICYCLE_BMX_HARMONY',
    'WORLD_VEHICLE_BICYCLE_BMX_VAGOS',
    'WORLD_VEHICLE_BICYCLE_MOUNTAIN',
    'WORLD_VEHICLE_BICYCLE_ROAD',
    'WORLD_VEHICLE_BOAT_IDLE',
    'WORLD_VEHICLE_BOAT_IDLE_ALAMO',
    'WORLD_VEHICLE_BOAT_IDLE_MARQUIS',
    'WORLD_VEHICLE_BUSINESSMEN',
    'WORLD_VEHICLE_CLUCKIN_BELL_TRAILER',
    'WORLD_VEHICLE_CONSTRUCTION_PASSENGERS',
    'WORLD_VEHICLE_CONSTRUCTION_SOLO',
    'WORLD_VEHICLE_DRIVE_PASSENGERS',
    'WORLD_VEHICLE_DRIVE_SOLO',
    'WORLD_VEHICLE_EMPTY',
    'WORLD_VEHICLE_FIRE_TRUCK',
    'WORLD_VEHICLE_HELI_LIFEGUARD',
    'WORLD_VEHICLE_MARIACHI',
    'WORLD_VEHICLE_MECHANIC',
    'WORLD_VEHICLE_MILITARY_PLANES_BIG',
    'WORLD_VEHICLE_MILITARY_PLANES_SMALL',
    'WORLD_VEHICLE_PARK_PARALLEL',
    'WORLD_VEHICLE_PARK_PERPENDICULAR_NOSE_IN',
    'WORLD_VEHICLE_POLICE',
    'WORLD_VEHICLE_POLICE_BIKE',
    'WORLD_VEHICLE_POLICE_CAR',
    'WORLD_VEHICLE_POLICE_NEXT_TO_CAR',
    'WORLD_VEHICLE_QUARRY',
    'WORLD_VEHICLE_SALTON',
    'WORLD_VEHICLE_SALTON_DIRT_BIKE',
    'WORLD_VEHICLE_SECURITY_CAR',
    'WORLD_VEHICLE_STREETRACE',
    'WORLD_VEHICLE_TRACTOR',
    'WORLD_VEHICLE_TRACTOR_BEACH',
    'WORLD_VEHICLE_TRUCK_LOGS',
    'WORLD_VEHICLE_TRUCKS_TRAILERS',
}

-- Scenario GROUPS, which are collections of points rather than a behaviour.
-- These four are the ones proven in use on this server (they are the same set
-- qbx_ignore disables) -- an unrecognised group name is simply ignored by the
-- engine, so extending this list is safe.
Config.DisableScenarioGroups = {
    'LSA_Planes',
    'SANDY_PLANES',
    'GRAPESEED_PLANES',
    'ng_planes',
    'AIRPORT_PLANES',
}

-- One-off world flags. All persistent natives -- set once, re-asserted on the
-- slow tick only in case another resource turns them back on.
Config.World = {
    RandomBoats = false,        -- SetRandomBoats
    RandomTrains = false,       -- SetRandomTrains
    GarbageTrucks = false,      -- SetGarbageTrucks
    RandomCops = false,         -- SetCreateRandomCops + the two variants
    DistantSirens = false,      -- DistantCopCarSirens
    FarDrawVehicles = false,    -- SetFarDrawVehicles, distant traffic on hills

    -- Parked-car generators. -1 restores the game default; 0 means none.
    NumberOfParkedVehicles = 0,

    -- Low priority generators are the ones that fill car parks and driveways.
    LowPriorityGenerators = false,

    -- Population BUDGETS, 0-3. These are a hard cap on how much the engine will
    -- ever spend on ambient population, independent of the density multipliers,
    -- and unlike the multipliers they persist rather than needing a per-frame
    -- call. 0 is the minimum.
    --
    -- Set either to nil to leave the engine's own budget alone.
    VehicleBudget = 0,
    PedBudget = 0,
}

-- How often (ms) to re-assert everything in section 3. Suppression persists on
-- its own, so this exists only to undo another resource clearing it. There is
-- no reason to make it fast.
Config.ReassertMs = 30000


-- =============================================================================
-- 4. DENSITY MULTIPLIERS
--
-- The five SetXDensityMultiplierThisFrame natives must be called EVERY FRAME,
-- which means a Wait(0) loop -- the only per-frame cost in this resource.
--
-- qbx_density already runs exactly that loop with every value at 0.0, so
-- running a second one here would be pure waste. 'auto' checks whether
-- qbx_density is actually started and only takes over if it is not.
--
--   'auto'    run the loop only if qbx_density is missing or stopped (default)
--   'always'  always run it, even alongside qbx_density
--   'never'   never run it, even if nothing else is
-- =============================================================================

Config.Density = {
    Mode = 'auto',

    -- Only used when the loop actually runs. 0.0 - 1.0, where 1.0 is GTA Online
    -- population rates.
    Parked = 0.0,
    Vehicle = 0.0,
    RandomVehicles = 0.0,
    Peds = 0.0,
    Scenario = 0.0,
}


-- =============================================================================
-- 5. SERVER-SIDE POPULATION SWITCH
--
-- SetRoutingBucketPopulationEnabled(bucket, false) turns off ambient population
-- for a whole routing bucket, server side, with no client loop at all.
--
-- OFF BY DEFAULT, and honestly: it is a bigger, blunter hammer than everything
-- above, and its exact interaction with client-local ambient spawning is not
-- something that was verified here. The client-side path above is proven and
-- sufficient on its own.
--
-- Turn this on only if ambient traffic still leaks through after everything
-- else, and watch for side effects on anything that relies on population
-- entities in that bucket.
-- =============================================================================

Config.RoutingBuckets = {
    Enabled = false,
    -- Which buckets to disable population in. 0 is the default bucket every
    -- player starts in.
    Buckets = { 0 },
}


-- =============================================================================
-- 6. DEBUG
-- =============================================================================

Config.Debug = {
    -- Console output on state changes and a summary of what each sweep removed.
    Enabled = false,
}
