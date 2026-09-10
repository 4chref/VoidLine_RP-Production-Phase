fx_version 'cerulean'
game 'gta5'
author 'Aiakos'
description 'Dynamic Weather & Time — admin panel with per-zone forecasts (JSON/SQL, i18n)'
version '1.1.0'

shared_scripts {
    'config/Config.lua',
    'config/Cities.lua',
    -- Clock pace table (Config.TimeScale) — must load AFTER Config.lua
    'shared/timescale.lua',
    -- Locale: language files first, resolver (locale.lua) LAST
    'locale/en.lua',
    'locale/tr.lua',
    'locale/locale.lua',
}

client_scripts {
    'client/main.lua',
    'client/nui.lua',
}

server_scripts {
    'server/permissions.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/**/*',
}

escrow_ignore {
    'config/*.lua',
    'locale/*.lua', -- keep locale files editable (not encrypted)
    -- Permission decision point — buyers must be able to plug in their own admin check
    'server/permissions.lua',
}

lua54 'yes'

dependency '/assetpacks'