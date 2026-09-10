fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_hospital'
author 'VoidLine'
description 'Compound doctor NPC: check in to heal/revive and rest in a clinic bed'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qbx_core',
    'qbx_medical',
    'ox_lib',
    'ox_target',
}
