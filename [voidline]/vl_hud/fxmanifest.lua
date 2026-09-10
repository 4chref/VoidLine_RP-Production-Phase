fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_hud'
author 'VoidLine'
description 'DayZ-style survival HUD: silent status icons, no bars, no numbers'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/threat.lua',   -- defines Threat, which main.lua reads each tick
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
