fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vl_apocalypse'
author 'VoidLine'
description 'Removes NPC traffic and ambient aircraft, and clears the ones already spawned'
version '1.0.0'

-- STANDALONE. qbx_core is used only for the notification on the admin command
-- and every call is guarded with GetResourceState, so this runs on a bare
-- FiveM server.
--
-- It coexists with qbx_density rather than replacing it: qbx_density owns the
-- per-frame density multipliers, this owns everything the multipliers do not
-- reach (aircraft, scenario spawns, generators, and deleting what already
-- exists). See Config.Density.

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'
