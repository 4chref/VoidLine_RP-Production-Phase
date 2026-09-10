fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_corpseloot'
author 'VoidLine'
description 'Search a downed player and take their carried items.'
version '1.0.1'

-- ox_inventory      -- openNearbyInventory (their real inventory, nothing generated)
-- ox_target         -- the "Search body" option on a downed player
dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
