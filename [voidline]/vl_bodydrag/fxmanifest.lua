fx_version 'cerulean'
game 'gta5'
author 'Laugh'
version '1.0.0'

-- VoidLine: adapted for this server. The proximity prompt was replaced with an
-- ox_target option (ALT), and every "is this player dead" test now reads
-- qbx_medical's replicated isDead statebag instead of IsPedDeadOrDying -- a
-- qbx-dead player is a live, full-health, invincible ped, so the native reports
-- false for exactly the people you want to drag. Search for "VoidLine" in
-- client/client.lua and server/server.lua.
dependencies {
    'ox_target',
    'qbx_medical',
}

shared_scripts {
    'config.lua',
    'locales.lua',
    'locales/en.lua',
    'locales/fr.lua',
}


client_scripts {
    'client/functions.lua',
    'client/client.lua',
    'client/debug.lua',
}


server_scripts {
    'server/server.lua',
}
