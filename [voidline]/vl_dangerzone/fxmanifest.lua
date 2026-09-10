fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_dangerzone'
author 'VoidLine'
description 'Danger zone entry notification: af-expeditions-styled letterbox alert + sound, fired when a player enters a configured radius'
version '1.0.0'

shared_scripts {
    'config.lua',
}

-- NUI frames stack in resource start order (later-started draws on top).
-- Forcing vl_hud to start first guarantees the letterbox fade renders above
-- the HUD icons instead of underneath them.
dependency 'vl_hud'

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts/BebasNeue.woff2',
    'html/fonts/BebasNeue.woff',
    'html/sounds/*.ogg',
    'html/sounds/*.mp3',
}
