fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_jobs'
author 'VoidLine'
description 'Bunker work foreman: electrical repair shifts with server-assigned repair points'
version '1.0.0'

dependencies {
    'ox_lib',        -- progress bar, callbacks, notifications
    'ox_target',     -- foreman + repair point interactions
    'ox_inventory',  -- tool handout/reclaim and reward
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

-- The foreman's board. A custom page rather than an ox_lib context menu: it is
-- styled after af-camping's campfire panel, and restyling ox_lib itself would
-- have themed every other resource's menus on this server along with it.
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}
