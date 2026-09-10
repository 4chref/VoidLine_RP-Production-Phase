fx_version 'cerulean'
game 'gta5'

author 'VoidLine'
description 'Armory station -- take standard-issue gear from a fixed point'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

shared_script '@ox_lib/init.lua'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

lua54 'yes'
