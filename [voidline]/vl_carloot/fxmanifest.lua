fx_version 'cerulean'
game 'gta5'

name 'vl_carloot'
description 'Searchable wrecked cars: each wreck opens its own ox_inventory stash holding a one-time coin drop.'
version '1.0.0'

lua54 'yes'

-- ox_inventory provides the stash (RegisterStash / AddItem / openInventory),
-- ox_target provides the interaction, ox_lib provides notify + MySQL wrappers.
dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
}

shared_script '@ox_lib/init.lua'

client_scripts {
    'config.lua',
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua',
}
