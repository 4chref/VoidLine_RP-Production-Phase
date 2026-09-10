fx_version 'cerulean'
game 'gta5'

author 'VoidLine'
description 'Copy another player\'s outfit onto yourself (admin tool)'
version '1.0.0'

dependencies {
    'ox_lib',
    'illenium-appearance',
}

shared_script '@ox_lib/init.lua'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

lua54 'yes'
