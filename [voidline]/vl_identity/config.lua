VLConfig = {}

-- Unique identity number range (inclusive).
--
-- CAPACITY: this range is the hard ceiling on how many characters can ever
-- exist. 100-999 is 900 identities for the lifetime of the server -- once they
-- are all taken, generateUniqueId() returns nil and character creation stops.
-- Characters created before this range changed keep their old 4-digit numbers;
-- they are simply outside the pool and are never reissued.
VLConfig.IdMin = 100
VLConfig.IdMax = 999

-- Text on the character intake screen.
VLConfig.IntakeText = {
    eyebrow  = 'VOIDLINE :: SURFACE REGISTRATION',
    heading  = 'Identify yourself',
    subtitle = 'Bunker 07-A intake. What is recorded here cannot be changed.',
}

-- Arrival card -- the one-shot title screen shown the moment a brand new
-- character spawns into the world.
--
-- Built on af-expeditions' zone-discovery treatment (gradient from the right,
-- copy stacked against that edge, discovery sting underneath) because the
-- player will meet that exact language every time they walk into an expedition.
-- Re-using it here says "you have arrived somewhere" in a grammar they become
-- fluent in within their first hour.
--
-- Passive: no NUI focus, no button. It plays over live gameplay and dismisses
-- itself, so the player is never locked out of a world they can already see.
VLConfig.ArrivalText = {
    eyebrow = 'WELCOME SURVIVOR',

    -- NOTE: there is no `title` key. The headline is the player's identity
    -- number, passed in at runtime -- this splash replaced the separate
    -- blocking reveal screen that used to announce it, so the number has to
    -- come from the character, not from config.
    desc    = 'The bunker doors are shut behind you. Whatever you make of this place is yours alone.',

    -- Staggered in one at a time after the panel settles; the gap is derived
    -- from VLConfig.Arrival.duration below, so a longer card lets them breathe
    -- and a shorter one tightens them up without editing anything here. Keep
    -- them short and uppercase -- they are set in the mono face at small size,
    -- and anything that wraps breaks the rhythm. The LAST line is accented in
    -- olive, so make it the one that hands control back to the player.
    lines = {
        'IDENTITY REGISTERED',
        'SUPPLIES ISSUED',
        'NO FURTHER ASSISTANCE AVAILABLE',
    },
}

VLConfig.Arrival = {
    -- TOTAL time on screen, in ms -- first frame of the fade-in to the last
    -- frame of the fade-out. Not "time before it starts leaving": that is what
    -- this used to mean, and it made the card outlive its own setting by a
    -- fade while only a fraction of it was actually readable.
    --
    -- The hold is derived as duration - (fade * 2), and the line stagger is
    -- derived from the hold, so everything scales off this one number. Nothing
    -- in web/app.js or web/style.css needs touching to change the pacing.
    duration = 7000,

    -- How long the fade-in and the fade-out each take, in ms. Applied to the
    -- CSS transition as a variable AND used to schedule the timers, so the two
    -- cannot drift apart.
    --
    -- Counted twice against `duration`, so it must stay well under half of it;
    -- app.js floors the readable hold at 600ms if it ever does not.
    fade = 900,

    -- Played straight out of af-expeditions rather than copied in: nui:// can
    -- read any file another resource lists in its files{} block, and that one
    -- publishes `web/build/**` wholesale. One copy of a paid script's asset on
    -- disk instead of two, and it cannot drift if af-expeditions updates.
    --
    -- Set to false for no sound. If af-expeditions is ever removed the fetch
    -- simply fails and the screen runs silently -- nothing errors.
    sound  = 'nui://af-expeditions/web/build/sounds/expedition_discovered.mp3',
    volume = 0.6,
}

-- Height selection (centimeters). Stored on the character as metadata.height.
-- Note: GTA V cannot visually scale freemode peds, so this is a persisted
-- roleplay stat rather than a physical model change.
VLConfig.Height = {
    min = 140,
    max = 210,
    default = 175,
}

-- Predefined spawn positions. Headings are computed at runtime so every
-- spawned player faces the center of the spawn area.
VLConfig.SpawnPoints = {
    vec3(3108.75, 5418.63, 22.59),
    vec3(3107.58, 5422.21, 22.59),
    vec3(3105.58, 5425.49, 22.59),
    vec3(3104.56, 5428.97, 22.59),
    vec3(3102.02, 5432.16, 22.59),
    vec3(3099.89, 5435.59, 22.59),
    vec3(3111.59, 5442.65, 22.59),
    vec3(3113.42, 5439.09, 22.59),
    vec3(3115.18, 5435.93, 22.59),
    vec3(3116.94, 5432.44, 22.59),
    vec3(3118.84, 5429.24, 22.59),
    vec3(3120.79, 5425.88, 22.59),
}

-- A spawn point counts as occupied when a player ped is within this range of it
VLConfig.SpawnOccupiedRadius = 2.5

-- How long (seconds) an allocated spawn point stays reserved for the player it
-- was handed to (covers the window between allocation and the player actually
-- streaming in on other clients)
VLConfig.SpawnReservationSeconds = 60

-- Fallback when every point is occupied: the least crowded point is used with a
-- random offset of up to this many meters
VLConfig.SpawnFallbackOffset = 2.0

-- Items given once, right after character creation (the ID card is issued
-- separately with its photo/ID/sex metadata)
-- Weight budget: ox_inventory gives a player 30000g by default. water is 500g
-- each and sandwich 200g, so this kit is 7000g. core is weightless on
-- purpose (see items.lua) -- give it a weight and 1000 of them will not fit.
VLConfig.StarterItems = {
    { name = 'core', amount = 1000 },
    { name = 'water', amount = 10 },
    { name = 'sandwich', amount = 10 },
}

-- How long the ID card stays on screen when used (milliseconds)
VLConfig.CardDisplayMs = 8000

-- Distance within which the closest player is also shown the card
VLConfig.CardShowDistance = 2.5

-- Applied before the creator opens and enforced again after saving -- this is
-- the outfit every character actually spawns wearing right after creation.
-- VoidLine: male changed 2026-08-30 from the original bare/underwear/barefoot
-- loadout to the server's starter clothing-pack outfit (drawable IDs from that
-- pack, not vanilla GTA V clothing). Female still uses the original naked
-- loadout below -- pending the matching numbers for the female pack.
VLConfig.NakedAppearance = {
    male = {
        model = 'mp_m_freemode_01',
        components = {
            {component_id = 1, drawable = 0, texture = 0},    -- mask: nothing
            {component_id = 3, drawable = 74, texture = 0},   -- arms/hands
            {component_id = 4, drawable = 257, texture = 3},  -- legs
            {component_id = 5, drawable = 0, texture = 0},    -- bags/parachute: nothing
            {component_id = 6, drawable = 153, texture = 1},  -- shoes
            {component_id = 7, drawable = 0, texture = 0},    -- scarf/chains: nothing
            {component_id = 8, drawable = 15, texture = 0},   -- shirt (undershirt)
            {component_id = 9, drawable = 0, texture = 0},    -- body armor: nothing
            {component_id = 10, drawable = 0, texture = 0},   -- decals: none
            {component_id = 11, drawable = 15, texture = 0},  -- jacket (torso2)
        },
    },
    female = {
        model = 'mp_f_freemode_01',
        components = {
            {component_id = 1, drawable = 0, texture = 0},
            {component_id = 3, drawable = 15, texture = 0},
            {component_id = 4, drawable = 15, texture = 3},  -- legs: underwear
            {component_id = 5, drawable = 0, texture = 0},
            {component_id = 6, drawable = 35, texture = 0},  -- shoes: barefoot
            {component_id = 7, drawable = 0, texture = 0},
            {component_id = 8, drawable = 14, texture = 0},  -- undershirt: none
            {component_id = 9, drawable = 0, texture = 0},
            {component_id = 10, drawable = 0, texture = 0},
            {component_id = 11, drawable = 15, texture = 3}, -- jacket/torso2: bare
        },
    },
}
