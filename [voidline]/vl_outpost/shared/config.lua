-- =============================================================================
-- vl_outpost
--
-- Every NPC and interaction point at the outpost, in one resource.
--
-- CURRENCY. The only currency on this server is the `core` ITEM (see
-- ox_inventory/data/items.lua: "The only currency anyone still honours"), not
-- cash. Every price below is a count of `core`, and server/main.lua takes it
-- with ox_inventory:RemoveItem rather than qbx_core's RemoveMoney.
--
-- Worth knowing: vl_campshop and vl_dailygoods DISPLAY "core" in their UI but
-- actually charge money.cash. They are wrong, not this. Flagged separately.
-- =============================================================================

Config = {}

Config.Currency = 'core'
Config.CurrencyLabel = 'core'

Config.InteractDistance = 2.0

-- Peds are spawned this far below the given Z. Coordinates read in game sit at
-- the player's centre rather than their feet.
Config.PedZOffset = 1.0

-- =============================================================================
-- SHOPS
-- =============================================================================
-- Each entry is one NPC (or, where `ped = false`, a plain location marker).
-- `kind` selects the behaviour in client/main.lua:
--   'shop'      buy items for core
--   'repair'    weapon repair, priced by durability
--   'exchange'  hand artifacts IN for core
--   'stash'     personal storage
--   'clothing'  opens illenium-appearance
--   'elevator'  teleport between two fixed points
--   'garage'    retrieve an owned vehicle, or buy one from the dealer list
--   'heli'      buy (retrievable later) or rent (temporary) a single vehicle model

Config.Shops = {

    -- -------------------------------------------------------------------------
    gunsmith = {
        kind    = 'repair',
        label   = 'Gunsmith',
        coords  = vector4(2630.8933, 3659.2227, 101.4447, 30.2055),
        ped     = 'mp_m_waremech_01',
        scenario = 'WORLD_HUMAN_WELDING',
        icon    = 'fa-solid fa-screwdriver-wrench',

        -- Price scales with how broken the weapon is:
        --   full durability -> minPrice (nothing to do)
        --   zero durability -> maxPrice
        -- A weapon above `freeAbove` percent is refused as not worth repairing,
        -- so nobody pays 400 to top up a 99% gun by accident.
        minPrice  = 400,
        maxPrice  = 2000,
        freeAbove = 95.0,
    },

    -- -------------------------------------------------------------------------
    supplies = {
        kind   = 'shop',
        label  = 'Supplies',
        coords = vector4(2606.3748, 3681.7378, 101.5720, 213.4205),
        ped    = 'a_m_m_farmer_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-briefcase-medical',

        categories = {
            { id = 'supplies', label = 'Supplies', items = {
                { name = 'bandage', label = 'Bandage', price = 200 },
                { name = 'radio',   label = 'Radio',   price = 200 },
                { name = 'pager',   label = 'Pager',   price = 200 },
                { name = 'gps',     label = 'GPS',     price = 200 },
            }},
        },
    },

    -- -------------------------------------------------------------------------
    artifacts = {
        kind   = 'exchange',
        label  = 'Artifact Broker',
        coords = vector4(2614.4893, 3684.0037, 101.5721, 177.0497),
        ped    = 'a_m_y_business_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        icon   = 'fa-solid fa-gem',

        -- EMPTY ON PURPOSE. No artifact items exist in ox_inventory yet, and
        -- inventing names would mean a shop that trades things nobody can find.
        -- Add entries as you register the items; the broker reads this list and
        -- needs no code change:
        --   { name = 'artifact_shard', label = 'Shard', price = 750 },
        -- `price` is what the player RECEIVES in core for handing one in.
        categories = {
            { id = 'artifacts', label = 'Artifacts', items = {} },
        },
    },

    -- -------------------------------------------------------------------------
    stash = {
        kind   = 'stash',
        label  = 'Outpost Stash',
        coords = vector4(2600.8181, 3676.4209, 101.6336, 236.4521),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_GUARD_STAND',
        icon   = 'fa-solid fa-box-archive',

        -- Read as "15 x 100": 1500 slots, 3000 kg. ox_inventory takes weight in
        -- GRAMS, hence the multiplication rather than a bare 3000.
        slots  = 15 * 100,
        weight = 3000 * 1000,

        -- One-off cost to open an account. I picked this number -- you did not
        -- give one. 0 makes the stash free to everyone.
        price  = 5000,
    },

    -- -------------------------------------------------------------------------
    -- Replaced the parachute stand. Buy a rustheli outright (retrievable
    -- later, same idea as the garage's dealer) or rent one -- cheaper, but
    -- temporary: a rented heli is never saved to the player's vehicles, so
    -- once it's gone it's gone, no re-retrieving it.
    heli = {
        kind   = 'heli',
        label  = 'Heli Dealer',
        coords = vector4(2602.89, 3683.28, 145.37, 342.0),
        ped    = 'a_m_y_skater_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-helicopter',

        model = 'rustheli',
        buyPrice = 45000,
        rentPrice = 3000,

        garageName = 'vl_outpost_heli',
        spawnPoint = vector4(2599.81, 3689.31, 145.37, 302.0),
        spawnRadius = 4.0,
    },

    -- -------------------------------------------------------------------------
    pets = {
        kind   = 'shop',
        label  = 'Pets',
        coords = vector4(2629.8635, 3678.2378, 107.4358, 63.3315),
        ped    = 'a_m_y_hipster_01',
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        icon   = 'fa-solid fa-paw',

        -- PLACEHOLDERS. These three are registered by this resource's SQL-free
        -- item block (see README) purely so the shop is demonstrably working --
        -- replace the names and prices with your real pet items.
        categories = {
            { id = 'pets', label = 'Pets', items = {
                { name = 'pet_food',   label = 'Pet Food',   price = 200 },
                { name = 'pet_collar', label = 'Pet Collar', price = 500 },
                { name = 'pet_toy',    label = 'Pet Toy',    price = 300 },
            }},
        },
    },

    -- -------------------------------------------------------------------------
    -- Merged in from vl_campshop 2026-09-02. Same shape as the shops above, so
    -- it needed no code -- only its coordinates, ped and item list.
    camp = {
        kind   = 'shop',
        label  = 'Camp Shop',
        coords = vector4(2598.06, 3662.46, 101.58, 286),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-campground',

        defaultPrice = 200,

        categories = {
            { id = 'deployables', label = 'Deployables', items = {
                { name = 'tent_01', label = 'Tent (Small)' },
                { name = 'tent_02', label = 'Tent (Medium)' },
                { name = 'tent_03', label = 'Tent (Large)' },
                { name = 'campfire' },
                { name = 'water_catcher', label = 'Water Catcher' },
                { name = 'camp_stash',    label = 'Camp Stash' },
                { name = 'camp_chair',    label = 'Camp Chair' },
                { name = 'camp_table',    label = 'Camp Table' },
                { name = 'camp_bed',      label = 'Camp Bed' },
                { name = 'barbed_wire',   label = 'Barbed Wire' },
                { name = 'palisade' },
                { name = 'gate' },
            }},
            { id = 'ingredients', label = 'Ingredients', items = {
                { name = 'beef' },
                { name = 'coffe_beans', label = 'Coffee Beans' },
                { name = 'corn' }, { name = 'eggs' }, { name = 'garlic' },
                { name = 'mushrooms' }, { name = 'onion' }, { name = 'parsley' },
                { name = 'potatos', label = 'Potatoes' },
                { name = 'potatos_carrots', label = 'Potatoes & Carrots' },
                { name = 'raw_chicken', label = 'Raw Chicken' },
                { name = 'raw_fish', label = 'Raw Fish' },
                { name = 'salt' },
            }},
            { id = 'cooked', label = 'Cooked', items = {
                { name = 'grilled_fish', label = 'Grilled Fish' },
                { name = 'roasted_chicken', label = 'Roasted Chicken' },
                { name = 'mushroom_soup', label = 'Mushroom Soup' },
                { name = 'soup' }, { name = 'stew' },
                { name = 'grilled_vegetables', label = 'Grilled Vegetables' },
                { name = 'coffe', label = 'Coffee' },
            }},
        },
    },

    -- -------------------------------------------------------------------------
    -- Merged in from vl_suitshop 2026-09-02.
    --
    -- kind = 'suit': the suits are FREE (the original charged nothing), and the
    -- item is the interesting part -- using it swaps the player's ped model and
    -- using it again puts their real appearance back. That behaviour moved with
    -- it into client/suits.lua.
    suits = {
        kind   = 'suit',
        label  = 'Suit Dealer',
        coords = vector4(2631.59, 3672.20, 101.44, 147),
        ped    = 'makeshift',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-user-shield',

        -- 'list' stacks the cards vertically with a large image and the
        -- description beside it, instead of the compact grid the other shops
        -- use. Suits are few and each one needs explaining; a grid of three
        -- small tiles wasted the space and had nowhere to put the text.
        layout = 'list',

        categories = {
            { id = 'suits', label = 'Suits', items = {
                { name = 'rust_scientist', label = 'Scientist Hazmat Suit', model = 'rust_scientist', price = 0,
                  description = 'Protects you from radiation.' },
                { name = 'rust_nomad',     label = 'Nomad Suit',            model = 'rust_nomad',     price = 0,
                  description = 'Protects you from dust.' },
                { name = 'arctic_hazmat',  label = 'Arctic Suit',           model = 'arctic_hazmat',  price = 0,
                  description = 'Protects you from low temperatures.' },
            }},
        },
    },

    -- -------------------------------------------------------------------------
    -- Retrieve an owned vehicle, or buy one from the dealer list. Deliberately
    -- NOT a qbx_garages garage: this is a self-contained NPC that talks to
    -- qbx_vehicles directly (client/main.lua's openGarage/server/main.lua's
    -- garage callbacks), so it needs no entry in qbx_garages' own Config.
    garage = {
        kind   = 'garage',
        label  = 'Garage',
        coords = vector4(2641.19, 3677.00, 51.76, 79.0),
        ped    = 'a_m_m_business_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-car',

        -- Free-form label stamped on player_vehicles.garage for anything
        -- stored/bought through this NPC. Not registered with qbx_garages --
        -- see the note above.
        garageName = 'vl_outpost_garage',

        -- Tried in this order; the first spot with no player sitting in a
        -- vehicle within `spotRadius` of it is used.
        retrievePoints = {
            vector4(2618.90, 3692.11, 51.69, 232.0),
            vector4(2617.78, 3683.15, 51.73, 251.0),
            vector4(2610.35, 3673.28, 51.75, 263.0),
        },
        spotRadius = 3.0,

        -- Drive in and press the prompt to store the vehicle back into this
        -- garage (drawn as a red disc on the ground). Any vehicle owned by
        -- the player works here, not just ones bought/retrieved through this
        -- NPC.
        parkPoint = vector4(2636.05, 3677.80, 51.73, 257.0),
        parkRadius = 4.0,

        -- What's for sale. `name` must be a valid vehicle spawn name.
        dealer = {
            { name = 'bf400', label = 'BF400', price = 5000 },
        },
    },

    -- -------------------------------------------------------------------------
    -- NOTE: the marketplace is NOT listed here.
    --
    -- vl_market brought its own ped spawning and targeting (see
    -- market/config.lua's Config.Locations and market/client.lua), and it still
    -- does that job perfectly well. Adding an entry here too would put two
    -- traders on the same spot. Its outpost location and the /e smokeweed
    -- scenario are set in market/config.lua instead.

    -- -------------------------------------------------------------------------
    -- NOT an NPC: a marker on the ground that opens the appearance menu.
    clothing = {
        kind   = 'clothing',
        label  = 'Clothing',
        coords = vector4(2599.5251, 3669.6741, 101.4447, 261.0355),
        ped    = false,
        icon   = 'fa-solid fa-shirt',

        -- Charged every time the menu is opened, not just once like the stash.
        price  = 1000,
    },

    -- =========================================================================
    -- SECOND OUTPOST -- same services, new location. `categories` tables are
    -- shared BY REFERENCE with the originals above (not copied), so editing an
    -- item or price once updates both locations -- one source of truth per
    -- item list, same idea as the merged-in vl_campshop/vl_suitshop blocks.
    -- =========================================================================

    gunsmith_2 = {
        kind    = 'repair',
        label   = 'Gunsmith',
        coords  = vector4(-1817.7435, -1171.9427, 13.0174, 51.9876),
        ped     = 'mp_m_waremech_01',
        scenario = 'WORLD_HUMAN_WELDING',
        icon    = 'fa-solid fa-screwdriver-wrench',

        minPrice  = 400,
        maxPrice  = 2000,
        freeAbove = 95.0,
    },

    supplies_2 = {
        kind   = 'shop',
        label  = 'Supplies',
        coords = vector4(-1816.7477, -1193.8678, 14.3059, 330.9755),
        ped    = 'a_m_m_farmer_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-briefcase-medical',
        -- categories wired up below, once Config.Shops.supplies itself exists.
    },

    artifacts_2 = {
        kind   = 'exchange',
        label  = 'Artifact Broker',
        coords = vector4(-1846.8418, -1190.5093, 14.3238, 141.2526),
        ped    = 'a_m_y_business_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        icon   = 'fa-solid fa-gem',
        -- categories wired up below, once Config.Shops.artifacts itself exists.
    },

    -- Opens the SAME personal stash as the original -- see the shopId-agnostic
    -- key in server/main.lua's openStash callback. This is just a second door
    -- into it, not a second storage account.
    stash_2 = {
        kind   = 'stash',
        label  = 'Outpost Stash',
        coords = vector4(-1860.7339, -1208.0223, 13.0172, 160.6244),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_GUARD_STAND',
        icon   = 'fa-solid fa-box-archive',

        slots  = 15 * 100,
        weight = 3000 * 1000,
        price  = 5000,
    },

    pets_2 = {
        kind   = 'shop',
        label  = 'Pets',
        coords = vector4(-1841.8037, -1199.3009, 14.3059, 238.7512),
        ped    = 'a_m_y_hipster_01',
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        icon   = 'fa-solid fa-paw',
        -- categories wired up below, once Config.Shops.pets itself exists.
    },

    camp_2 = {
        kind   = 'shop',
        label  = 'Camp Shop',
        coords = vector4(-1833.1439, -1176.1288, 14.3069, 332.8390),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-campground',
        -- defaultPrice/categories wired up below, once Config.Shops.camp itself exists.
    },

    -- NOT an NPC: a marker on the ground, same as the original clothing point.
    clothing_2 = {
        kind   = 'clothing',
        label  = 'Clothing',
        coords = vector4(-1810.6652, -1239.9553, 13.0174, 142.9509),
        ped    = false,
        icon   = 'fa-solid fa-shirt',

        price  = 1000,
    },

    -- =========================================================================
    -- THIRD OUTPOST -- same services again, third location. Same
    -- share-by-reference note as the _2 block above applies here.
    -- =========================================================================

    gunsmith_3 = {
        kind    = 'repair',
        label   = 'Gunsmith',
        coords  = vector4(720.7186, 1293.7264, 363.5150, 269.9511),
        ped     = 'mp_m_waremech_01',
        scenario = 'WORLD_HUMAN_WELDING',
        icon    = 'fa-solid fa-screwdriver-wrench',

        minPrice  = 400,
        maxPrice  = 2000,
        freeAbove = 95.0,
    },

    supplies_3 = {
        kind   = 'shop',
        label  = 'Supplies',
        coords = vector4(780.8536, 1274.8473, 361.2848, 274.8321),
        ped    = 'a_m_m_farmer_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-briefcase-medical',
        -- categories wired up below, once Config.Shops.supplies itself exists.
    },

    artifacts_3 = {
        kind   = 'exchange',
        label  = 'Artifact Broker',
        coords = vector4(744.3419, 1315.3496, 363.2021, 181.2027),
        ped    = 'a_m_y_business_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        icon   = 'fa-solid fa-gem',
        -- categories wired up below, once Config.Shops.artifacts itself exists.
    },

    -- Opens the SAME personal stash as the original (see server/main.lua).
    stash_3 = {
        kind   = 'stash',
        label  = 'Outpost Stash',
        coords = vector4(762.8823, 1269.3630, 360.2969, 17.8251),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_GUARD_STAND',
        icon   = 'fa-solid fa-box-archive',

        slots  = 15 * 100,
        weight = 3000 * 1000,
        price  = 5000,
    },

    pets_3 = {
        kind   = 'shop',
        label  = 'Pets',
        coords = vector4(746.7688, 1261.1661, 360.2964, 288.5552),
        ped    = 'a_m_y_hipster_01',
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        icon   = 'fa-solid fa-paw',
        -- categories wired up below, once Config.Shops.pets itself exists.
    },

    camp_3 = {
        kind   = 'shop',
        label  = 'Camp Shop',
        coords = vector4(720.2454, 1274.7268, 360.2963, 343.3151),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-campground',
        -- defaultPrice/categories wired up below, once Config.Shops.camp itself exists.
    },

    -- NOT an NPC: a marker on the ground, same as the original clothing point.
    clothing_3 = {
        kind   = 'clothing',
        label  = 'Clothing',
        coords = vector4(714.1654, 1288.7906, 360.2963, 217.5714),
        ped    = false,
        icon   = 'fa-solid fa-shirt',

        price  = 1000,
    },

    -- =========================================================================
    -- FOURTH OUTPOST -- same services again, fourth location.
    -- =========================================================================

    -- NOT an NPC, unlike the other three gunsmiths: a ground marker instead of
    -- a ped/ox_target zone, same as the clothing and stash-elevator points.
    gunsmith_4 = {
        kind   = 'repair',
        label  = 'Gunsmith',
        coords = vector4(-1134.0565, 4948.6084, 222.2687, 244.2269),
        ped    = false,
        icon   = 'fa-solid fa-screwdriver-wrench',

        minPrice  = 400,
        maxPrice  = 2000,
        freeAbove = 95.0,
    },

    supplies_4 = {
        kind   = 'shop',
        label  = 'Supplies',
        coords = vector4(-1075.5671, 4897.5225, 214.2713, 10.8092),
        ped    = 'a_m_m_farmer_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-briefcase-medical',
        -- categories wired up below, once Config.Shops.supplies itself exists.
    },

    artifacts_4 = {
        kind   = 'exchange',
        label  = 'Artifact Broker',
        coords = vector4(-1093.3578, 4951.0371, 218.3542, 163.4548),
        ped    = 'a_m_y_business_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        icon   = 'fa-solid fa-gem',
        -- categories wired up below, once Config.Shops.artifacts itself exists.
    },

    -- Opens the SAME personal stash as the original (see server/main.lua).
    stash_4 = {
        kind   = 'stash',
        label  = 'Outpost Stash',
        coords = vector4(-1149.7977, 4940.3975, 222.2688, 250.4007),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_GUARD_STAND',
        icon   = 'fa-solid fa-box-archive',

        slots  = 15 * 100,
        weight = 3000 * 1000,
        price  = 5000,
    },

    pets_4 = {
        kind   = 'shop',
        label  = 'Pets',
        coords = vector4(-1124.4694, 4892.5728, 218.4724, 326.3832),
        ped    = 'a_m_y_hipster_01',
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        icon   = 'fa-solid fa-paw',
        -- categories wired up below, once Config.Shops.pets itself exists.
    },

    camp_4 = {
        kind   = 'shop',
        label  = 'Camp Shop',
        coords = vector4(-1147.7311, 4907.6743, 220.9688, 359.4474),
        ped    = 'a_m_m_hillbilly_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        icon   = 'fa-solid fa-campground',
        -- defaultPrice/categories wired up below, once Config.Shops.camp itself exists.
    },

    -- NOT an NPC: a marker on the ground, same as the original clothing point.
    clothing_4 = {
        kind   = 'clothing',
        label  = 'Clothing',
        coords = vector4(-1177.0935, 4926.9414, 223.3467, 251.4891),
        ped    = false,
        icon   = 'fa-solid fa-shirt',

        price  = 1000,
    },
}

-- The _2/_3/_4 entries above share their item lists BY REFERENCE with the
-- originals -- done here rather than inline because `Config.Shops` doesn't
-- exist yet while its own table constructor is still running.
Config.Shops.supplies_2.categories  = Config.Shops.supplies.categories
Config.Shops.artifacts_2.categories = Config.Shops.artifacts.categories
Config.Shops.pets_2.categories      = Config.Shops.pets.categories
Config.Shops.camp_2.categories      = Config.Shops.camp.categories
Config.Shops.camp_2.defaultPrice    = Config.Shops.camp.defaultPrice

Config.Shops.supplies_3.categories  = Config.Shops.supplies.categories
Config.Shops.artifacts_3.categories = Config.Shops.artifacts.categories
Config.Shops.pets_3.categories      = Config.Shops.pets.categories
Config.Shops.camp_3.categories      = Config.Shops.camp.categories
Config.Shops.camp_3.defaultPrice    = Config.Shops.camp.defaultPrice

Config.Shops.supplies_4.categories  = Config.Shops.supplies.categories
Config.Shops.artifacts_4.categories = Config.Shops.artifacts.categories
Config.Shops.pets_4.categories      = Config.Shops.pets.categories
Config.Shops.camp_4.categories      = Config.Shops.camp.categories
Config.Shops.camp_4.defaultPrice    = Config.Shops.camp.defaultPrice

-- =============================================================================
-- MARKERS
-- =============================================================================
-- The clothing point and the elevator floors are NOT ox_target zones: they are
-- blue markers on the ground you walk into and activate with a key.
--
-- Deliberately different from the shops: those are people you talk to, and the
-- eye cursor suits that. These are places, and a marker reads as somewhere to
-- stand rather than something to aim at.

Config.Marker = {
    -- 1 = flat cylinder on the ground. 27 is the thin ring if you prefer that.
    type = 1,

    size = vector3(1.2, 1.2, 0.6),
    colour = { r = 40, g = 130, b = 255, a = 120 },   -- blue

    -- Sits slightly below the point so it lies flat on the floor rather than
    -- floating at waist height.
    zOffset = -0.95,

    bobUpAndDown = false,
    rotate = true,

    -- Rendered within this range; the marker thread sleeps beyond it.
    drawDistance = 18.0,

    -- Close enough to press the key.
    interactDistance = 1.6,

    -- 38 = INPUT_PICKUP (E).
    key = 38,
    keyLabel = 'E',
}

-- =============================================================================
-- ELEVATOR
-- =============================================================================
-- Also not an NPC. Each floor is a point you can interact with; selecting the
-- other floor teleports you there.

Config.Elevator = {
    enabled = true,
    label   = 'Elevator',
    icon    = 'fa-solid fa-elevator',

    floors = {
        { id = 'level1',      label = 'Level 1',   coords = vector4(2630.3972, 3679.3364, 101.5119, 62.6366) },
        { id = 'underground', label = 'Underground', coords = vector4(2643.3528, 3677.3274, 51.7688, 347.2939) },
    },

    -- Fade so the teleport is not a hard cut, and so the destination has a
    -- moment to stream in before the player can see it.
    fadeMs = 500,
}
