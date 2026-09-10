Config = {}

Config.debug = false

Config.Framework = 'auto' -- 'auto' | 'qbx' | 'esx' | 'qb' | 'standalone'
Config.Inventory = 'auto' -- 'auto' | 'ox' | 'qb' | 'esx' | 'standalone'
Config.Target    = 'auto' -- 'auto' | 'ox_target' | 'qb-target' | 'marker'
Config.Notify    = 'auto' -- 'auto' | 'ox_lib' | 'framework'

Config.Locale = 'en' -- config/locale/*.lua

Config.Admin = {
    ace = 'of_stash.admin', -- add_ace group.admin of_stash.admin allow
    groups = { 'admin', 'god', 'superadmin' },
    jobs = {},
    command = 'stashadmin', -- false to disable
    giveUnitCommand = 'giveunit', -- /giveunit <playerId> <tier> [days]
    keybind = false,
}

Config.Stash = {
    defaultSlots     = 50,
    defaultMaxWeight = 100000, -- grams
    renderDistance   = 60.0,

    marker = {
        drawDistance     = 8.0,
        interactDistance = 1.5,
        key              = 38,
        keyLabel         = 'E', -- keep in sync with `key`
        type             = 21,
        color            = { r = 108, g = 99, b = 255, a = 180 },
        size             = { x = 0.3, y = 0.3, z = 0.3 },
    },

    blip = {
        enabled = false,
        sprite  = 473,
        color   = 3,
        scale   = 0.7,
        label   = 'Stash',
    },
}

Config.StorageUnits = {
    enabled      = false, -- Downtown Storage removed; no locations left to rent from
    allowVirtual = true,
    sellVirtual  = false,
    command      = 'units', -- false to disable
    currency     = 'bank', -- 'cash' | 'bank'
    rentGrace    = 86400, -- seconds after expiry before contents lock

    tiers = {
        { id = 'small',  label = 'Small Unit',  slots = 25,  maxWeight = 50000,  price = 5000,  rent = 500,  rentPeriod = 604800 },
        { id = 'medium', label = 'Medium Unit', slots = 50,  maxWeight = 100000, price = 12000, rent = 1200, rentPeriod = 604800 },
        { id = 'large',  label = 'Large Unit',  slots = 100, maxWeight = 250000, price = 25000, rent = 2500, rentPeriod = 604800 },
    },

    locations = {},
}

Config.Boxes = {
    enabled             = true,
    maxPerPlayer        = 3,
    pickupRequiresEmpty = true,
    cleanupOnRestart    = true,
    openPolicy          = 'owner', -- 'owner' | 'anyone'
    pickupPolicy        = 'owner', -- 'owner' | 'anyone'
    interaction         = 'prop', -- 'prop' | 'marker'

    sizes = {
        { item = 'stash_box_small',  label = 'Small Box',  slots = 15, maxWeight = 25000,  prop = 'prop_box_ammo01a' },
        { item = 'stash_box_medium', label = 'Medium Box', slots = 30, maxWeight = 60000,  prop = 'prop_box_ammo03a' },
        { item = 'stash_box_large',  label = 'Large Box',  slots = 50, maxWeight = 120000, prop = 'prop_box_ammo04a' },
    },
}

Config.UI = {
    keepInput = true,
    blurOnOpen = true,
}
