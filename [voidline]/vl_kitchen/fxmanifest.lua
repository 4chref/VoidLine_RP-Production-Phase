shared_script "@clientloader/shared.lua" --line 1
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_kitchen'
author 'VoidLine'
description 'Kitchen chef NPC handing out a ration pack, limited to a set number of collections per day'
version '1.0.0'

dependencies {
    'qbx_core',      -- player object + persistent metadata for the daily limit
    'ox_lib',        -- callbacks, notifications, model loading
    'ox_target',     -- the interaction
    'ox_inventory',  -- CanCarryItem / AddItem
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

clientloader {
    'client.lua'
}

server_script 'server.lua'