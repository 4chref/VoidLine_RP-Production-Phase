fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

name 'kq_security'
author 'KuzQuality | Kuzkay'
description 'Lasers by KuzQuality.com'
version '1.0.0'

shared_script '@ox_lib/init.lua'

--
-- Server
--

server_scripts {
    'config.lua',

    'components/public/dispatch/server.lua',

    -- Answers the bunker hallway laser system's door-state query (see
    -- client/editable/bunker_hallway.lua) -- needs ox_lib's lib.callback.
    'main/server/bunker_door.lua',
}

--
-- Client
--

client_scripts {
    'config.lua',

    'main/client/functions.lua',
    'main/client/cache.lua',
    'main/client/debug.lua',

    'main/client/editable/client.lua',
    'main/client/editable/esx.lua',
    'main/client/editable/qb.lua',

    'components/protected/laser/classes/laser.lua',
    'components/protected/laser/client.lua',

    'components/public/dispatch/client.lua',

    -- Loaded last: calls exports['vl_lasers']:CreateLaser, which needs the
    -- laser system above to have already registered its exports.
    'main/client/editable/bunker_hallway.lua',
}

escrow_ignore {
    'config.lua',
    'main/client/editable/*.lua',
    'components/public/**/*.lua',
}

dependency '/assetpacks'