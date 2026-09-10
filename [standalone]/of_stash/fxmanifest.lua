lua54 "yes"
fx_version "cerulean"
game "gta5"
author "overflow5m.com"
description "Overflow — standalone stash & storage-unit creator with in-game admin tooling"
version "v1.0.1"

use_fxv2_oal "yes"

ui_page "dist/index.html"

files {
    "dist/**/*",
}

dependencies {
    "oxmysql",
}

shared_scripts {
    "config/config.lua",
    "config/locale/en.lua",
    "config/locale/es.lua",
    "config/hooks.lua",

    "src/helpers/shared/log.lua",
    "src/helpers/shared/table.lua",

    "src/init.lua",
    "src/shared/constants.lua",
    "src/shared/validate.lua",
}

client_scripts {
    "framework/registry.lua",
    "framework/qbx/init.lua",
    "framework/esx/init.lua",
    "framework/qb/init.lua",
    "framework/standalone/init.lua",
    "framework/inventory/ox.lua",
    "framework/inventory/qb.lua",
    "framework/inventory/esx.lua",
    "framework/inventory/standalone.lua",
    "framework/target.lua",
    "framework/notify.lua",

    "src/client/state.lua",
    "src/client/nui.lua",
    "src/client/rpc.lua",
    "src/client/main.lua",
    "src/client/admin.lua",
    "src/client/creator.lua",
    "src/client/units.lua",
    "src/client/boxes.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",

    "framework/registry.lua",
    "framework/qbx/init.lua",
    "framework/esx/init.lua",
    "framework/qb/init.lua",
    "framework/standalone/init.lua",
    "framework/inventory/ox.lua",
    "framework/inventory/qb.lua",
    "framework/inventory/esx.lua",
    "framework/inventory/standalone.lua",
    "framework/notify.lua",

    "src/server/db.lua",
    "src/server/state.lua",
    "src/server/crud.lua",
    "src/server/sharing.lua",
    "src/server/main.lua",
    "src/server/units.lua",
    "src/server/boxes.lua",
}

escrow_ignore {
    "config/**/*.lua",
    "framework/**/*.lua",
    "dist/**/*",
}

dependency '/assetpacks'