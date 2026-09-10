Config = {}

-- ============================================================
-- GENERAL
-- ============================================================
Config.Debug = true

Config.Framework = 'qbox' -- 'standalone' or 'qbox'
Config.UseDatabase = true       -- requires oxmysql

Config.HudPosition = 'middle-right' -- 'bottom-right' | 'bottom-left' | 'top-right' | 'top-left' | 'middle-right' | 'middle-left'

-- interval (ms) at which the server ticks/decays needs and syncs to db
Config.TickInterval = 60000 -- 60s
-- interval (ms) at which the client polls server for HUD sync (adaptive, only sends on change server side)
Config.HudPollInterval = 5000

Config.Notify = function(msg, type)
    -- default fallback notification; override this if you use ox_lib / qb notifications
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({ description = msg, type = type or 'inform' })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- ============================================================
-- NEEDS
-- ============================================================
Config.Needs = {
    poop = { max = 100 },
    sleep = { max = 100, drainPerMinute = 1 },
    pee = { max = 100 }
}

-- ============================================================
-- FOOD / DRINK
-- ============================================================
-- Item names must match the item names used by your inventory (ox_inventory).
-- These match what qbx_consumables ships with on this server.
-- VoidLine: this list only covered a handful of items, several of which
-- (tosti, twerks_candy, snikkel_candy, kurkakola) don't even exist in this
-- server's ox_inventory/data/items.lua -- dead entries, left as-is in case
-- those items get added later. Meanwhile several REAL food/drink items that
-- players actually eat/drink (testburger, burger, canned_chicken_soup,
-- canned_tuna, mustard, sprunk, water, watermelon_punch) were missing
-- entirely, so eating/drinking them never raised poop/pee no matter how full
-- hunger/thirst already were -- not a fullness gate, just an incomplete
-- mapping. Added below 2026-08-30, using the same scale the original author
-- already used: sandwich (hunger 200000 -> poop 8) and water_bottle (thirst
-- 400000 -> pee 15) both work out to the same ratio, so new entries are
-- scaled the same way from each item's own hunger/thirst status value in
-- ox_inventory/data/items.lua.
Config.Food = {
    sandwich = 8,
    tosti = 8,
    twerks_candy = 4,
    snikkel_candy = 4,
    testburger = 8,             -- hunger 200000, same as sandwich
    burger = 8,                 -- hunger 200000, same as sandwich
    canned_chicken_soup = 16,   -- hunger 400000, double sandwich
    canned_tuna = 16,           -- hunger 400000, double sandwich
    mustard = 1                 -- hunger 25000, condiment-sized
}

Config.Drinks = {
    water_bottle = 15,
    kurkakola = 12,
    coffee = 10,
    beer = 6,
    whiskey = 5,
    vodka = 5,
    sprunk = 8,             -- thirst 200000, same ratio as water_bottle
    water = 8,              -- thirst 200000, same ratio as water_bottle
    watermelon_punch = 15,  -- thirst 400000, same as water_bottle
    mustard = 1             -- thirst 25000 too, condiment-sized
}

-- ============================================================
-- SLEEP
-- ============================================================
Config.Sleep = {
    drainPerMinute = 1,      -- exhaustion gained per minute awake
    criticalThreshold = 100,
    faintDuration = 180000,  -- 3 minutes
    wakeUpValue = 20,        -- sleep value restored to after fainting
    bedRestorePerSecond = 4, -- how fast sleeping in a bed restores rest

    -- Looping animation played for the whole faint so the ped stays down
    -- without relying on the engine's ragdoll timer (which always ends in
    -- its own get-up animation, however often it's refreshed).
    faintAnim = {
        dict = 'combat@damage@writhe',
        anim = 'writhe_loop'
    },

    -- Full-screen dark/blur overlay (web/sleep_overlay.html) shown for the
    -- whole faint. darkness is a 0-1 black opacity, blurPx a CSS blur radius.
    -- Layered on top of the native blur/desaturate/timecycle effects in
    -- client/sleep.lua for a much stronger "passed out" look than any one of
    -- them gives alone.
    faintOverlay = {
        darkness = 0.7,
        blurPx = 18
    }
}

-- ============================================================
-- POOP
-- ============================================================
Config.Poop = {
    walkingClipSet = 'move_m@drunk@moderatedrunk', -- fallback strained/uncomfortable clipset
}

-- Manual relief at 100% poop: unlike pee, this does NOT trigger automatically.
-- The player is notified and must press a key (G / control 47) themselves to
-- play the relief emote, wherever they happen to be standing.
Config.PoopRelief = {
    emoteName = 'shit', -- rpemotes emote key (was 'sittoilet2')
    key = 47,                 -- G by default
    duration = 8000,
    restoreAmount = 100       -- subtracted from poop when relief finishes
}

-- ============================================================
-- PEE
-- ============================================================
Config.PeeAnimation = {
    -- if the rpemotes resource is running, its 'pee' emote is used instead of
    -- the dict/anim below (rpemotes already ships a proper urination anim +
    -- particle effect). Set to false to always use the dict/anim pair here.
    useRpEmotes = true,
    rpEmoteName = 'pee',

    dict = 'amb@world_human_urinate@male@idle_a',
    anim = 'idle_c',
    fallbackDict = 'amb@world_human_urinate@male@idle_a',
    fallbackAnim = 'idle_c',
    duration = 8000
}

Config.PeeSettings = {
    waitForVehicleExit = true -- do not force-pee while player is driving; wait until they exit
}

-- ============================================================
-- TOILETS
-- ============================================================
Config.Toilets = {
    { coords = vector3(-262.0, -972.0, 31.2), radius = 2.0, type = 'both' },
    { coords = vector3(-1035.0, -3016.0, 13.8), radius = 2.0, type = 'both' },
}

Config.ToiletSettings = {
    peeDuration = 5000,
    poopDuration = 7000,
    peeRestore = 100, -- amount reduced from pee value (100 = fully empties)
    poopRestore = 100
}

-- ============================================================
-- BEDS
-- ============================================================
Config.Beds = {
    { coords = vector3(-1197.0, -1573.0, 4.6), heading = 210.0 },
}

-- ============================================================
-- WARNINGS
-- ============================================================
Config.Warnings = {
    poop = {
        [50] = 'You are starting to need the toilet.',
        [75] = 'You really need to use the toilet.',
        [100] = 'You desperately need to use a toilet!'
    },
    sleep = {
        [50] = 'You are starting to feel tired.',
        [75] = 'You are extremely tired.',
        [100] = 'You are completely exhausted!'
    },
    pee = {
        [50] = 'You should find a toilet soon.',
        [75] = 'You really need to pee.',
        [100] = 'You urgently need to pee!'
    }
}
