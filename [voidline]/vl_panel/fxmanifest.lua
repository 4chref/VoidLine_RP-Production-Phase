fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_panel'
author 'VoidLine'
description 'One resource, one admin panel: blackout, alert, pager alert and air raid, with a live player map. Formerly four separate resources (vl_blackout, vl_alert, vl_airraid) -- now merged, see config.lua'
version '2.0.0'

-- qbx_core is used purely for notifications (blackout/pager/alert feedback);
-- everything else here is either console commands or self-contained state.
dependencies {
    'qbx_core',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/panel.lua',    -- open/close, button wiring, live radar feed
    'client/blackout.lua', -- was vl_blackout/client.lua
    'client/alert.lua',    -- was vl_alert/client.lua
    'client/airraid.lua',  -- was vl_airraid/client/main.lua
}

server_scripts {
    'server/panel.lua',        -- open-panel gate, command dispatch, radar push
    'server/blackout.lua',     -- was vl_blackout/server.lua
    'server/alert_config.lua', -- was vl_alert/server_config.lua (admin allowlist,
                                -- server-only, must load AFTER shared config.lua)
    'server/alert.lua',        -- was vl_alert/server.lua
    'server/airraid.lua',      -- was vl_airraid/server/main.lua
}

ui_page 'html/index.html'

files {
    'html/index.html',

    'html/panel.css',
    'html/panel.js',

    'html/blackout.css',
    'html/blackout.js',
    'html/blackout.mp3',

    'html/alert.css',
    'html/alert.js',
    'html/alert.mp3',

    'html/airraid.js',
    'html/civil-defense-siren.mp3', -- air raid siren -- see config.lua

    'html/radio.css',
    'html/radio.js',

    'html/youtube.css',
    'html/youtube.js',

    -- NOT shipped -- drop your own file in at exactly this path. Missing, the
    -- outpost alarm is simply silent (the NUI's buffer load fails and the voice
    -- is discarded); nothing errors. See VLAirRaid.intruderAudio in config.lua.
    'html/intruder.mp3',

    -- NOT shipped -- drop your own file in at exactly this path. Missing
    -- entirely, the radar still works, just as a plain grid. See
    -- VLPanel.radar in config.lua.
    'html/gta_map.png',

    'html/fonts/apocalypse_fax.ttf',
    'html/fonts/VCR_OSD_MONO.ttf',
}
