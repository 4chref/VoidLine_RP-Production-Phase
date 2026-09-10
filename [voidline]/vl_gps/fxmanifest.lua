fx_version "cerulean"

description "CRT-8000 GPS — handheld map terminal (Afterfall pager theme)"
author "af-gps"
version "1.0.0"

lua54 "yes"

games {
  "gta5",
}

ui_page "web/index.html"

client_scripts {
  "client/*.lua",
}

server_scripts {
  "server/*.lua",
}

shared_scripts {
  "@ox_lib/init.lua",
  "shared/config.lua",
}

files {
  "web/index.html",
  "web/images/tiles/*.jpg",
}

dependencies {
  "ox_lib",
  "qbx_core",
}
