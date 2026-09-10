fx_version 'cerulean'
game 'gta5'

author 'VoidLine'
description 'Daily goods vendor NPC -- seated trader selling everyday essentials'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core',
}

shared_script '@ox_lib/init.lua'

shared_scripts {
    'shared/config.lua',
    'shared/items.lua',
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

lua54 'yes'
