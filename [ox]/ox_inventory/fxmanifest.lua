fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'ox_inventory'
author 'Overextended'
version '2.47.9'
repository 'https://github.com/overextended/ox_inventory'
description 'Slot-based inventory with item metadata support'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua'
}

client_scripts {
    'init.lua',
    -- VoidLine: feeds the character panel's body-damage indicators.
    'modules/bodydamage/client.lua',
}

-- VoidLine: AVP-styled Vue UI. To revert to stock ox_inventory's React UI
-- (which still has the AVP CSS skin on it), swap these two lines back.
ui_page 'web/avp-build/index.html'
-- ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    -- VoidLine: the AVP skin ships a font; without this the NUI 404s it
    -- and silently falls back to Roboto.
    'web/build/assets/*.ttf',
    -- VoidLine: AVP-styled Vue UI (source in web-avp/, built by vite).
    'web/avp-build/index.html',
    'web/avp-build/assets/*.js',
    'web/avp-build/assets/*.css',
    'web/avp-build/assets/*.ttf',
    'web/avp-build/assets/*.woff',
    -- hover/select sounds the AVP UI plays; without these it 404s per hover
    'web/avp-build/sfx/*.mp3',
    'web/avp-build/sfx/*.wav',
    'web/avp-build/characters/*.png',
    'web/avp-build/clothes_empty_items/*.png',
    'web/images/*.png',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'modules/bridge/**/client.lua',
    'data/*.lua',
}
