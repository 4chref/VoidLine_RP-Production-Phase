-- MERGED INTO vl_outpost 2026-09-02.
--
-- `Config or {}`, not `{}`: shared/config.lua loads first and this would
-- otherwise wipe every outpost setting. The two use entirely separate keys --
-- Locations/Settings/Interaction/AvailableItems here, Shops/Currency/Elevator
-- there -- so sharing one table is safe.
Config = Config or {}

-- Marketplace Locations (add more as needed)
Config.Locations = {
    {
        -- VoidLine 2026-09-02: moved from Legion Square to the outpost.
        -- The Paleto Bay market below is untouched.
        name = "Outpost Trader",
        coords = vector3(2600.7131, 3679.9226, 104.4360),
        ped = {
            model = "mp_m_shopkeep_01",
            heading = 229.6594,
            coords = vector3(2600.7131, 3679.9226, 104.4360),
            -- The scenario behind rpemotes' /e smokeweed
            -- ([standalone]/rpemotes/client/AnimationList.lua:5595). rpemotes
            -- itself is player-only, so an NPC needs the scenario directly.
            scenario = "WORLD_HUMAN_DRUG_DEALER"
        },
        blip = {
            sprite = 52,
            color = 3,
            scale = 0.8,
            label = "Outpost Trader"
        }
    },
    {
        name = "Outpost Trader",
        coords = vector3(-1830.7596, -1180.9561, 19.1685),
        ped = {
            model = "mp_m_shopkeep_01",
            heading = 331.9772,
            coords = vector3(-1830.7596, -1180.9561, 19.1685),
            scenario = "WORLD_HUMAN_DRUG_DEALER"
        },
        blip = {
            sprite = 52,
            color = 3,
            scale = 0.8,
            label = "Outpost Trader"
        }
    },
    {
        name = "Outpost Trader",
        coords = vector3(780.6835, 1296.7393, 361.3619),
        ped = {
            model = "mp_m_shopkeep_01",
            heading = 266.4807,
            coords = vector3(780.6835, 1296.7393, 361.3619),
            scenario = "WORLD_HUMAN_DRUG_DEALER"
        },
        blip = {
            sprite = 52,
            color = 3,
            scale = 0.8,
            label = "Outpost Trader"
        }
    },
    {
        name = "Outpost Trader",
        coords = vector3(-1113.4293, 4903.4321, 218.5955),
        ped = {
            model = "mp_m_shopkeep_01",
            heading = 319.8615,
            coords = vector3(-1113.4293, 4903.4321, 218.5955),
            scenario = "WORLD_HUMAN_DRUG_DEALER"
        },
        blip = {
            sprite = 52,
            color = 3,
            scale = 0.8,
            label = "Outpost Trader"
        }
    }
    -- VoidLine 2026-09-02: the Paleto Bay market was removed at the owner's
    -- request -- the outpost trader above is the only one now.

}

-- Available items (only these items can be listed on marketplace)
-- If this list is empty, all items will be available
-- Add items to this list to restrict what can be listed
--
-- VoidLine: left empty (= all items) so the sell tab isn't limited to a
-- handful of crafting materials -- the previous 7-item whitelist meant the
-- sell dropdown looked empty for anyone not carrying exactly one of those.
-- Re-add specific item names here to restrict it again.
Config.AvailableItems = {}

-- Marketplace Settings
Config.Settings = {
    maxListingsPerPlayer = 20,        -- Maximum active listings per player
    maxBuyOrdersPerPlayer = 10,       -- Maximum active buy orders per player
    minPrice = 1,                      -- Minimum price for items
    maxPrice = 1000000,                -- Maximum price for items
    transactionFeePercent = 2.5,      -- Transaction fee percentage (2.5%)
    refreshInterval = 5000,            -- UI refresh interval in ms (5 seconds)
    enableAnalytics = true            -- Enable analytics tracking
}

-- Interaction Settings (ox_target handles interaction automatically)
Config.Interaction = {
    -- ox_target handles interaction distance and keybinds automatically
}

