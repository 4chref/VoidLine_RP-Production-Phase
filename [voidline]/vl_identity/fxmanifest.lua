fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_identity'
author 'VoidLine'
description 'Character creation with unique 3-digit identity, spawn allocation and minimal ID card'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'illenium-appearance',
    'MugShotBase64',
}
