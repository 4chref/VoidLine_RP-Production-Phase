Config = {}

-- Item dropped in wrecks. core is the server's currency item and is
-- defined in ox_inventory/data/items.lua -- AddItem silently fails for anything
-- ox has no definition for, so it has to stay there.
Config.CoinItem = 'core'
Config.CoinMin  = 1
Config.CoinMax  = 10

-- ox_target reach, and the server-side sanity radius. The server re-checks the
-- distance because the coordinates arrive from the client.
Config.SearchDistance = 2.5

-- Size of the stash that opens. ox counts slots rather than a grid, so these
-- multiply out to the slot count (5 x 4 = 20). Small on purpose: it is a car
-- boot, not a warehouse. StashWeight is in kilograms; the server converts.
Config.StashX      = 5
Config.StashY      = 4
Config.StashWeight = 50
Config.StashLabel  = 'Wreck'

-- Round coordinates to this many decimal places when building the stash id.
-- These are static map props, so their position never changes -- rounding to
-- whole units is what lets the same wreck resolve to the same stash every time
-- without storing an entity handle (map props are client-side and have no
-- network id).
Config.CoordPrecision = 0

-- =============================================================================
--  MODELS
-- =============================================================================
-- Every prop treated as a lootable wreck. Names that do not exist on this
-- server are simply never matched, so an over-broad list costs nothing.
--
-- Use /carmodel (admin) while looking at a wreck to print its model name, then
-- add it here. That is the reliable way to catch the ones this list misses --
-- the apocalypse maps ship their own wreck props under custom names.
Config.Models = {
    -- Base game abandoned/wrecked cars
    'prop_car_abandoned_01',
    'prop_car_abandoned_02',
    'prop_car_abandoned_03',
    'prop_car_abandoned_04',
    'prop_car_abandoned_05',
    'prop_rub_carwreck_1',
    'prop_rub_carwreck_2',
    'prop_rub_carwreck_3',
    'prop_rub_carwreck_4',
    'prop_rub_carwreck_5',
    'prop_rub_carwreck_6',
    'prop_rub_carwreck_7',
    'prop_rub_carwreck_8',
    'prop_rub_carwreck_9',
    'prop_rub_carwreck_10',
    'prop_rub_carwreck_11',
    'prop_rub_carwreck_12',
    'prop_rub_carwreck_13',
    'prop_rub_carwreck_14',
    'prop_rub_carwreck_15',
    'prop_rub_carwreck_16',
    'prop_veh_burnt_01',
    'prop_veh_burnt_02',

    -- Custom wreck props shipped by the map packs in resources/[maps]
    'brother_rivia_paleto_carcassa_01',
    'brother_sp1_03_carwreck_07',
    'brother_cs4_05_buswreck',
    'ch_chint02_carcrash_neon',
}
