fx_version 'cerulean'
game 'gta5'

author 'Sinatra#0101'
description '919DESIGN Admin Panel'
version '1.7.1'
lua54 'yes'

ui_page 'html/index.html'

escrow_ignore {
    'config.lua',
    'server/main.lua',
    'server/adminactions.lua',
    
    -- Compatibility Stuff
    'compat/qbcore.lua',
    --'compat/esx18.lua',
    
    -- NoClip Stuff
    'client/freecam/utils.lua',
    'client/freecam/config.lua',
    'client/freecam/camera.lua',
    'client/freecam/main.lua',
    'client/noclip_new.lua',

    -- Locale Stuff
    'locales/locale.lua',
    'locales/en.lua',
    'locales/de.lua',
    'locales/nl.lua',
    'version.lua',
}

files {
	'html/**',
    'json/reports.json',
    'json/adminchat.json',
    'json/logs.json',
    'json/crew_colors.json',
}

shared_scripts {
    'locales/locale.lua',
    'locales/en.lua', -- Can change to other languages available in locales folder
    'config.lua',
    'compat/qbcore.lua', -- If using ESX uncomment line below & comment this line
    --'compat/esx18.lua', -- If using ESX comment line above & uncomment this line
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/env.lua',
    'server/staff.lua', -- VoidLine 2026-09-02: staff.json roster loader, must run before main.lua uses AdminPanel.GetStaffRole
    'server/main.lua',
    'server/adminactions.lua',
    'server/job_manage.lua',
    'server/crew_colors.lua',
    'server/crew_manage.lua',
}

client_scripts {
    'client/main.lua',
    'client/functions.lua',
    'client/freecam/utils.lua',
    'client/freecam/config.lua',
    'client/freecam/camera.lua',
    'client/freecam/main.lua',
    'client/noclip_new.lua',
    -- VoidLine: 'client/DeveloperOptions.lua' removed 2026-08-31 -- listed
    -- here but never existed on disk, throwing a load warning every boot.
}

dependencies { 'oxmysql' }