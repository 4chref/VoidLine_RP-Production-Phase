fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_hunters'
author 'VoidLine'
description 'Armed T-800s that spawn around each player and patrol the streets on foot. Config-driven: a new pack is a config entry, not code.'
version '2.0.0'

-- ox_lib is used for lib.requestModel only -- a model request with a timeout,
-- rather than an unbounded wait that hangs forever if the ped resource is not
-- running.
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'

-- Added 2026-09-02: the server now owns the hunter population. Without this the
-- clients' spawn requests go nowhere and no hunter is ever created.
server_script 'server.lua'
