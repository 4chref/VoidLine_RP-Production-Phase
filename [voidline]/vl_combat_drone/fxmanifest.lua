fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'combat_drone'
description 'Intelligent networked combat drone PED with real GTA weapon combat, state-machine AI, patrol, search, obstacle avoidance and squad coordination.'
author 'combat_drone resource'
version '1.0.0'

-- The alert siren and the warning countdown are both rendered here: FiveM has
-- no native way to play a custom mp3 out of a world entity, so the sound is
-- spatialised with the Web Audio API instead. See client/audio.lua.
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/alert.mp3',
}

-- Load order matters: shared helpers first, then subsystems, then the
-- state machine that ties them together, then main.lua which owns the
-- per-drone update loop.
client_scripts {
    'config.lua',
    'client/utils.lua',
    'client/obstacle.lua',
    'client/movement.lua',
    'client/detection.lua',
    'client/targeting.lua',
    'client/combat.lua',
    'client/strike.lua',
    'client/patrol.lua',
    'client/squad.lua',
    'client/visual.lua',
    'client/audio.lua',
    'client/warning.lua',
    'client/statemachine.lua',
    'client/debug.lua',
    'client/main.lua',
}

server_scripts {
    'config.lua',
    'server.lua',
}
