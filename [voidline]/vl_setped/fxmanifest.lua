fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_setped'
author 'Voidline'
description 'Set any player\'s ped model, including the custom rust peds in [assets]/vl_rust_peds'
version '2.0.0'

-- illenium-appearance owns the ped's appearance on this server: the model swap
-- goes THROUGH it and is saved back to it, or it silently reverts on the next
-- refresh. qbx_core is not required -- chat is used for feedback so the command
-- works from the console too.
dependencies {
    'illenium-appearance',
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
