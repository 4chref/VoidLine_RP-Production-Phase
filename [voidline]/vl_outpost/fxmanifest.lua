fx_version 'cerulean'
game 'gta5'

author 'VoidLine'
description 'Outpost hub: gun repair, supplies, artifacts, stash, elevator, heli dealer, clothing and pets'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    -- The marketplace's own script and logo, from vl_market. Kept under a
    -- distinct name because both resources called theirs script.js.
    'ui/market.js',
    'ui/ns-logo.png'
}

-- qbx_vehicles is deliberately NOT listed here: it's server_only, so it's
-- never sent to the client, and a `dependencies` entry for a resource the
-- client never receives breaks client-side dependency resolution outright
-- ("Could not find dependency qbx_vehicles"). The garage code only reaches
-- it via exports.qbx_vehicles:* on the server, which needs no manifest
-- dependency to work -- only that qbx_vehicles is actually running.
dependencies {
    'oxmysql',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core',
}

shared_script '@ox_lib/init.lua'

shared_scripts {
    -- Exposes the global `qbx` table (qbx.spawnVehicle, etc.), same as
    -- qbx_garages -- needed by the garage NPC's retrieve/buy flow.
    '@qbx_core/modules/lib.lua',
    'shared/config.lua',
    'shared/items.lua',
    -- vl_market's own config, merged in unchanged. It defines its own Config
    -- fields and does not clash with the ones above.
    'market/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/suits.lua',
    'market/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'market/server.lua',
}

lua54 'yes'
