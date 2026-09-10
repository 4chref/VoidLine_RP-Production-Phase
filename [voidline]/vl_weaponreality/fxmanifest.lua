fx_version 'adamant'
games { 'gta5' }
author '0Resmon | aliko.'
description '0RESMON WEAPON REALITY'
lua54 'yes'

client_script {
  "main/client.lua",
}

server_script {
  "@oxmysql/lib/MySQL.lua",
  "main/server.lua",
  "main/server_noescrow.lua",
}

shared_script {
  "config.lua",
  "utils.lua",
}

escrow_ignore {
  'main/server_noescrow.lua',
  'main/server.lua',
  'main/client.lua',
  'config.lua',
  'utils.lua'  
}
dependency '/assetpacks'
