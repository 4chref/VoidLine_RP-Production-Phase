fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- VoidLine: this used to say name 'basic_needs', which doesn't match the
-- actual folder name (vl_basic_needs) FXServer uses for GetResourceState/
-- exports/ensure -- that mismatch had vl_hud silently calling a
-- nonexistent resource, always falling back to hardcoded defaults instead of
-- real sleep/poop/pee values. Fixed 2026-08-30 (see vl_hud/client/main.lua).
name 'vl_basic_needs'
author 'basic_needs'
description 'Standalone poop/sleep/pee survival needs system with HUD'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'bridge/standalone.lua',
    'bridge/qbox.lua',
    'client/needs.lua',
    'client/sleep.lua',
    'client/poop.lua',
    'client/pee.lua',
    'client/interactions.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/standalone.lua',
    'bridge/qbox.lua',
    'server/database.lua',
    'server/needs.lua',
    'server/main.lua'
}

-- The old pill-bar HUD (web/index.html etc.) is disabled: sleep/poop/pee are
-- shown via vl_hud's icons instead (see [voidline]/vl_hud), which reads these
-- values through the GetNeeds export below. Those files are left on disk,
-- unregistered, in case they're wanted back.
--
-- VoidLine: the sleep_overlay.html ui_page (full-screen dark/blur layer for
-- the faint sequence, see client/sleep.lua) was removed on 2026-08-30 -- it
-- was this resource's ONLY ui_page, so FXServer loaded and displayed that NUI
-- frame immediately on every resource start, before any faint logic ever ran,
-- causing a black screen (only other resources' HUDs visible on top) on every
-- login until this resource was stopped. The faint sequence now relies only
-- on the native blur/desaturate/timecycle effects already in sleep.lua
-- (TriggerScreenblurFadeIn, AnimpostfxPlay, SetTimecycleModifier), which
-- can't get stuck as a persistent full-screen NUI layer. web/sleep_overlay.*
-- are left on disk, unregistered, in case a real fix for the NUI approach is
-- wanted back later.

exports {
    'AddFood',
    'AddDrink',
    'GetNeeds',
    'GetPoop',
    'GetSleep',
    'GetPee',
    'SetPoop',
    'SetSleep',
    'SetPee'
}
