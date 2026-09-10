VLJobs = {}

-- =============================================================================
-- THE FOREMAN
-- =============================================================================

VLJobs.foreman = {
    -- From /vec4, which already drops Z by 1.0, so the ped spawns at this Z
    -- with no further offset.
    coords = vec4(3119.45, 5425.9, 22.59, 58.92),

    -- Validated with IsModelInCdimage at spawn; falls back if not present on
    -- this build, and says so in F8.
    model = 's_m_y_construct_01',
    fallback = 's_m_m_doctor_01',   -- proven to exist on this server

    scenario = 'WORLD_HUMAN_CLIPBOARD',
    label = 'Ask about work',
    icon = 'fas fa-hard-hat',
    distance = 2.5,
}

-- Subtitle under the board's headline. The headline itself ("Bunker Work") is
-- set in web/index.html, since it is the page's own identity rather than
-- configuration.
VLJobs.menuSubtitle = "Foreman's board"

-- =============================================================================
-- WAYPOINT INDICATORS
-- =============================================================================
-- How the player is shown where to go. All three work together.

VLJobs.indicator = {
    blips = true,          -- map/minimap blips on every assigned point
    gpsRoute = true,       -- draws a GPS line to the NEAREST outstanding point
    routeColour = 5,       -- yellow

    marker = true,         -- in-world marker so it is findable without the map
    markerType = 21,       -- 21 = the floating downward arrow
    markerSize = vec3(0.35, 0.35, 0.25),
    markerBob = true,      -- gentle up/down float
    markerDrawDistance = 60.0,   -- only drawn within this range, in metres
}

-- =============================================================================
-- JOBS
-- =============================================================================
-- Every job shares the same engine: hand out a tool, assign N random points
-- from the list, play an animation at each, take the tool back when done.
-- Adding a job is just another entry here.


-- Icon shown on the board. An ox_inventory item image name (without .png) --
-- the page loads it from nui://ox_inventory/web/images/, so anything already in
-- that folder works and nothing new has to be shipped.
--
-- Separate from `tool` on purpose: `crates` hands out no tool but still needs a
-- picture, and a job could reasonably want to advertise itself with something
-- other than the thing it lends you.
VLJobs.jobs = {

    -- ---------------------------------------------------------------------
    electricity = {
        enabled = true,
        label = 'Electrical repairs',
        description = 'Fix the bunker wiring. Tool provided.',
        menuIcon = 'fas fa-bolt',
        menuImage = 'screwdriverset',

        tool = 'screwdriverset',       -- exists in ox_inventory already
        pointsPerJob = 4,

        actionLabel = 'Repair wiring',
        actionIcon = 'fas fa-screwdriver',
        progressLabel = 'Repairing wiring',
        blipName = 'Wiring fault',
        blipSprite = 402,              -- wrench
        blipColour = 5,

        durationMs = 6000,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
        prop = nil,

        interactDistance = 1.8,

        -- NOTE: you never specified a payout, so this is a placeholder.
        reward = { item = 'core', amount = 250 },

        points = {
            vec4(3104.76, 5445.17, 22.59, 31.96),
            vec4(3098.34, 5448.33, 22.59, 112.08),
            vec4(3090.28, 5461.38, 22.59, 127.58),
            vec4(3090.17, 5461.54, 18.59, 164.0),
            vec4(3098.16, 5463.95, 26.99, 12.2),
            vec4(3101.53, 5442.17, 26.99, 150.43),
            vec4(3091.47, 5442.55, 26.19, 72.86),
            vec4(3087.72, 5449.11, 26.19, 153.86),
            vec4(3089.73, 5467.54, 30.8, 22.96),
        },
    },

    -- ---------------------------------------------------------------------
    cleaning = {
        enabled = true,
        label = 'Cleaning duty',
        description = 'Scrub down the bunker. Mop provided.',
        menuIcon = 'fas fa-broom',
        menuImage = 'cleaningkit',

        -- `cleaningkit` already exists in ox_inventory, so no new item and no
        -- missing icon. Swap this for a dedicated 'mop' item if you add one
        -- along with its web/images PNG.
        tool = 'cleaningkit',
        pointsPerJob = 4,

        actionLabel = 'Clean this area',
        actionIcon = 'fas fa-broom',
        progressLabel = 'Cleaning',
        blipName = 'Dirty area',
        blipSprite = 318,              -- bucket/cleaning
        blipColour = 3,                -- light blue

        durationMs = 7000,
        -- Janitor mopping idle. If it ever fails to load the progress bar still
        -- runs, it just plays no animation.
        anim = { dict = 'amb@world_human_janitor@male@idle_a', clip = 'idle_a' },
        prop = { model = `prop_tool_broom`, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0), bone = 28422 },

        interactDistance = 1.8,

        reward = { item = 'core', amount = 200 },

        points = {
            vec4(3108.73, 5434.86, 22.59, 188.78),
            vec4(3099.95, 5463.08, 26.99, 304.65),
            vec4(3102.97, 5441.91, 26.99, 203.95),
            vec4(3100.29, 5439.97, 26.99, 203.1),
            vec4(3094.4,  5439.5,  26.99, 55.55),
            vec4(3105.9,  5447.09, 27.59, 229.21),
            vec4(3111.19, 5452.51, 27.59, 305.57),
            vec4(3103.02, 5458.85, 27.59, 37.9),
            vec4(3082.4,  5459.45, 30.8,  168.62),
            vec4(3084.66, 5455.31, 30.8,  75.2),
            vec4(3091.26, 5444.13, 30.8,  121.79),
            vec4(3107.35, 5452.89, 30.8,  300.44),
        },
    },

    -- ---------------------------------------------------------------------
    -- Haul job: one pickup, several drop-offs, repeated until the quota is met.
    -- Structurally different from the two above, hence type = 'haul'.
    crates = {
        enabled = true,
        type = 'haul',
        label = 'Move crates to storage',
        description = 'Carry crates to the storage and laundry room.',
        menuIcon = 'fas fa-box',
        menuImage = 'largewood_box',

        tool = nil,          -- nothing to hand out; the crate itself is the prop
        cratesPerJob = 4,    -- how many round trips

        pickup = vec4(3120.83, 5428.19, 22.59, 246.44),

        -- The player may drop at any of these; the marker points at whichever
        -- is nearest. Fewer drop-offs than crates on purpose -- they reuse them.
        dropoffs = {
            vec4(3095.4,  5467.1,  26.99, 307.34),
            vec4(3098.26, 5468.58, 26.99, 299.12),
            vec4(3100.47, 5471.81, 26.99, 298.69),
        },

        pickupLabel = 'Pick up a crate',
        pickupIcon = 'fas fa-box-open',
        dropLabel = 'Set the crate down',
        dropIcon = 'fas fa-warehouse',

        pickupProgress = 'Lifting the crate',
        dropProgress = 'Setting it down',
        pickupMs = 2500,
        dropMs = 2000,

        blipNamePickup = 'Crate pallet',
        blipNameDrop = 'Storage room',
        blipSpritePickup = 478,   -- crate
        blipSpriteDrop = 473,     -- warehouse
        blipColour = 47,          -- orange

        interactDistance = 2.0,

        -- A different crate each trip, cycled in order so all four differ.
        -- These are the SMALL props: prop_cardbordbox_01a..04a are full moving
        -- boxes, big enough that they intersect the player's chest no matter
        -- how the offset is tuned.
        -- Each is checked with IsModelInCdimage before use; anything invalid on
        -- this build falls back rather than spawning nothing.
        -- Cycled in order, so each trip in a 4-crate shift is a different prop.
        -- These are DLC props (Cayo Perico and later); if any turn out to be
        -- absent on your build, /cratemodels reports it and the fallback is used.
        boxModels = {
            'h4_prop_h4_crate_cloth_01a',
            'm23_1_prop_m31_crate_medical',
            'm23_1_prop_m31_crate_jewellery',
            'm26_1_int_01_storage_crate_003',
        },
        boxFallback = 'h4_prop_h4_crate_cloth_01a',

        -- Auditioning list for /cratemodels and /cratenext. Includes the fifth
        -- crate, which the 4-trip cycle above never reaches -- swap it into
        -- boxModels if you prefer it to one of those.
        boxCandidates = {
            'h4_prop_h4_crate_cloth_01a',
            'm23_1_prop_m31_crate_medical',
            'm23_1_prop_m31_crate_jewellery',
            'm26_1_int_01_storage_crate_003',
            'ng_proc_crate_03a',
        },

        -- Carry pose held while walking with the crate.
        carryAnim = { dict = 'anim@heists@box_carry@', clip = 'idle' },

        -- Attachment. SKEL_R_Hand (60309) with these values is the standard
        -- pairing for the box_carry animation -- it seats the prop in front of
        -- the chest at hand height instead of inside the torso.
        carryBone = 60309,
        carryOffset = vec3(0.025, 0.08, 0.255),
        carryRot = vec3(-145.0, 290.0, 0.0),

        -- Per-model overrides, for props whose origin sits somewhere different.
        -- Anything not listed uses the values above. Dial these in live with
        -- /crateadjust (see below) and paste the numbers it prints here.
        boxOffsets = {
            -- ['hei_prop_heist_box'] = { offset = vec3(0.025, 0.08, 0.24), rot = vec3(-145.0, 290.0, 0.0) },
        },

        reward = { item = 'core', amount = 300 },
    },
}

-- =============================================================================
-- GENERAL
-- =============================================================================

VLJobs.oneJobAtATime = true
VLJobs.clearOnDisconnect = true
