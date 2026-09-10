Config = {}
Config.DB = {}

-------             CONFIGURATION          --------           
---------------------------------------------------

Config.EnableDebug                          = false                 -- Whether to enable debug prints or not

Config.ESXSkin                              = "AK"                  -- AK for ak47 or Default for esx_skin

Config.DefaultDarkMode                      = 1                     -- Whether dark mode should be enabled by default. 1 is on by default, 0 is off

Config.ServerName                           = "ELITE Roleplay"
Config.ServerDiscord                        = "https://discord.gg/eliteroleplaytn" -- For kick/ban messages

-- VoidLine: these two shipped with LIVE, pre-filled webhook URLs pointing at
-- a third party's Discord -- NOT this server's. That meant every admin
-- action log, plus every "screenshot player" moderation capture (which also
-- embeds the target's IP, Steam ID, license, Xbox Live ID and Discord ID --
-- see server/adminactions.lua's ScreenshotSubmit handler) was being sent
-- straight to whoever distributed this copy. Removed.
--
-- Left blank here on purpose -- config.lua is a SHARED script (loads
-- client-side too), so a real secret must never live in this file. The
-- actual values are set server-only in server/env.lua from convars, which
-- overrides these blanks after config.lua loads. Set the two convars in
-- server.cfg (see server/env.lua's header comment for the exact lines) once
-- you have your own webhook URLs -- until then both stay blank and
-- server/main.lua's existing "Webhook missing from config!" check quietly
-- no-ops instead of sending anything anywhere.
Config.ScreenshotWebhook                    = ""
Config.LogsWebhook                          = ""

Config.NoClipKey                            = "9"
Config.AdminPanelKey                        = "0"
Config.ShowNamesKey                         = "8"

Config.EnableAdminPanelCommand              = true                  -- Whether to enable the admin panel command (/a by default)
Config.AdminPanelCommand                    = "admin"

Config.NoClipType                           = 1                    -- 1 (default) NEW txAdmin-like NoClip system, or 2 for old style 919Admin NoClip system, or 3 for default qbcore NoClip system

Config.ShowIPInIdentifiers                  = false                 -- Whether to show player's IPs in the identifiers box in player info view

Config.EnableReportCommand                  = false                  -- Enable or disable the report command if you use another report system (reports tab will still show)
Config.ReportCommand                        = "report"              -- The command to use for reports (default /report)
Config.MaxReportsPerPlayer                  = 2                     -- The maximum amount of reports a player can place
Config.SaveTOJSON                           = false                  -- Whether to save reports and admichat to JSON onResourceStopped (server restarts etc) and load from JSON on resource start

Config.DB.VehiclesTable                     = "player_vehicles"     -- Standards: player_vehicles   for QBCore  | user_vehicle   for ESX
Config.DB.CharactersTable                   = "players"             -- Standards: players           for QBCore  | users          for ESX
Config.DB.BansTable                         = "bans"
Config.DB.PermissionsTable                  = "permissions"

Config.AnnounceBan                          = false                  -- Whether to announce bans in chat or not
Config.TagEveryone                          = true                 -- Enable to tag everyone in the discord log on ban

Config.EnableNames                          = true                  -- Whether or not to enable the names overhead
Config.AllPlayersUseNames                   = false                 -- Wheter or not all players can use the overhead names
Config.NamesOverSelfHead                    = true                  -- Whether or not your name and id should be over your own head or not

Config.FuelScript                           = 'LegacyFuel'


Config.Permissions = {

    -- ═══════════════════════════════════════════════════════
    -- GOD — Full access to everything
    -- ═══════════════════════════════════════════════════════
    ["god"] = {
        AllowedActions = {
            "adminmenu",            -- Open the admin menu
            "adminchat",            -- Use admin chat
            "resourcepage",         -- Access the Resource control page
            "viewreports",          -- Access the reports list
            "claimreport",          -- Claim a report
            "deletereport",         -- Delete a report
            "clearreports",         -- Clear all reports (God only)
            "clearadminchat",       -- Clear admin chat (God only)
            "clearlogs",            -- Clear server logs
            "clearblood",           -- Clear blood from player
            "reviveall",            -- Revive all players
            "messageall",           -- Message all players
            "kickall",              -- Kick all players
            "massdeleteentities",   -- Delete ALL vehicles/peds/objects
            "copyEntityInfo",       -- Copy entity information
            "freeaimMode",          -- Enable free aim mode
            "displayVehicles",      -- Vehicle dev mode
            "displayPeds",          -- Peds dev mode
            "displayObjects",       -- Objects dev mode
            "deleteclosestped",     -- Delete closest ped
            "deleteclosestobject",  -- Delete closest object
            "leaderboardinfo",      -- Check leaderboards
            "serverlogs",           -- Access server logs
            "servermetrics",        -- Access server metrics
            "savedata",             -- Save player data
            "setpedmodel",          -- Set a player ped model
            "clearinventory",       -- Clear inventory
            "randomvisualparts",    -- Random visual parts (vehicle)
            "setlivery",            -- Set livery (vehicle)
            "setcolor",             -- Set color (vehicle)
            "forceradar",           -- Force minimap on
            "skinmenu",             -- Give skin menu
            "deletecharacter",      -- Delete a character
            "characterspage",       -- Access All Characters page
            "vehiclesinfo",         -- Vehicle spawn code list
            "itemsinfo",            -- Item spawn code list
            "noclip",               -- Noclip
            "teleport",             -- Teleport yourself/others/to location
            "kill",                 -- Kill yourself/others
            "freeze",               -- Freeze a player
            "ban",                  -- Ban a player
            "unban",                -- Unban a player
            "weather",              -- Change server weather
            "time",                 -- Change server time
            "givetakemoney",        -- Give or take money
            "warn",                 -- Warn a player
            "checkwarns",           -- View player warnings
            "revive",               -- Revive a player
            "foodandwater",         -- Feed a player
            "relievestress",        -- Relieve stress
            "savecar",              -- Save car to garage
            "spawncar",             -- Spawn a vehicle
            "openinventory",        -- Open inventory
            "setjob",               -- Set job of a player
            "setgang",              -- Set gang of a player
            "firejob",              -- Fire from job
            "firegang",             -- Fire from gang
            "giveitem",             -- Give items
            "setmedriver",          -- Teleport as driver
            "setmepassenger",       -- Teleport as passenger
            "deleteclosestvehicle", -- Delete closest vehicle
            "repairvehicle",        -- Repair a vehicle
            "washvehicle",          -- Wash a vehicle
            "lockvehicle",          -- Lock a vehicle
            "unlockvehicle",        -- Unlock a vehicle
            "maxperformanceupgrades",-- Max upgrades (vehicle)
            "fillgastank",          -- Fill gas tank
            "hotwirevehicle",       -- Hotwire a vehicle
            "playerblips",          -- Toggle player blips
            "playernames",          -- Toggle player names
            "invisibility",         -- Toggle invisibility
            "godmode",              -- Toggle god mode
            "superjump",            -- Super jump
            "fastrun",              -- Fast run
            "infinitestam",         -- Infinite stamina
            "noragdoll",            -- No ragdoll
            "setViewDistance",      -- Set view distance
            "ipl",                  -- Load IPL/interiors
            "dryclothes",           -- Dry player clothes
            "wetclothes",           -- Wet player clothes
            "uncuffSelf",           -- Uncuff yourself/others
            "cuff",                 -- Cuff a player
            "jobpage",              -- Access jobs page
            "gangpage",             -- Access gangs page
            "banspage",             -- Access bans page
            "screenshot",           -- Screenshot a player
            "spectate",             -- Spectate a player
            "kick",                 -- Kick a player
            -- VoidLine 2026-09-02: added while auditing for the new
            -- admin/moderator split -- vec3/vec4/heading (the "Developer
            -- Actions" clipboard-copy buttons) had NO permission check at
            -- all before this, so any panel user could use them regardless
            -- of role. Gated now, alongside the rest of Developer Actions.
            "vec3",                 -- Copy vector3 to clipboard
            "vec4",                 -- Copy vector4 to clipboard
            "heading",              -- Copy heading to clipboard
        },
    },

    -- ═══════════════════════════════════════════════════════
    -- ADMIN — Everything God has EXCEPT: the Resources page/tab (and its
    -- underlying start/stop/restart action), and the Dashboard page's
    -- Developer/Entity Actions button groups. Self Actions, Server Actions,
    -- and Vehicle Actions ARE enabled for admin (VoidLine 2026-09-02,
    -- revised: Server + Vehicle Actions moved from excluded to granted).
    -- clearreports/clearadminchat/clearlogs/kickall stay God-only, per their
    -- original "(God only)" design intent above -- the new spec didn't ask
    -- to loosen that.
    -- ═══════════════════════════════════════════════════════
    ["admin"] = {
        AllowedActions = {
            "adminmenu",            -- Open the admin menu
            "adminchat",            -- Use admin chat
            "viewreports",          -- Access the reports list
            "claimreport",          -- Claim a report
            "deletereport",         -- Delete a report
            "clearblood",           -- Clear blood from player (Self Actions)
            "leaderboardinfo",      -- Check leaderboards
            "serverlogs",           -- Access server logs
            "servermetrics",        -- Access server metrics page
            "savedata",             -- Save player data
            "setpedmodel",          -- Set a player ped model
            "clearinventory",       -- Clear inventory
            "forceradar",           -- Force minimap on (Self Actions)
            "skinmenu",             -- Give skin menu
            "deletecharacter",      -- Delete a character
            "characterspage",       -- Access All Characters page
            "vehiclesinfo",         -- Vehicle spawn code list
            "itemsinfo",            -- Item spawn code list
            "noclip",               -- Noclip (Self Actions)
            "teleport",             -- Teleport yourself/others/to location
            "kill",                 -- Kill yourself/others
            "freeze",               -- Freeze a player
            "ban",                  -- Ban a player
            "unban",                -- Unban a player
            "weather",              -- Change server weather
            "givetakemoney",        -- Give or take money
            "warn",                 -- Warn a player
            "checkwarns",           -- View player warnings
            "revive",               -- Revive a player
            "foodandwater",         -- Feed a player
            "relievestress",        -- Relieve stress
            "savecar",              -- Save car to garage
            "openinventory",        -- Open inventory
            "setjob",                -- Set job of a player
            "setgang",               -- Set gang of a player
            "firejob",               -- Fire from job
            "firegang",              -- Fire from gang
            "giveitem",              -- Give items
            "hotwirevehicle",        -- Hotwire a vehicle (not a Dashboard group action)
            "playerblips",           -- Toggle player blips (Self Actions)
            "playernames",           -- Toggle player names (Self Actions)
            "invisibility",          -- Toggle invisibility (Self Actions)
            "godmode",               -- Toggle god mode (Self Actions)
            "superjump",             -- Super jump (Self Actions)
            "fastrun",               -- Fast run (Self Actions)
            "infinitestam",          -- Infinite stamina (Self Actions)
            "noragdoll",             -- No ragdoll (Self Actions)
            "dryclothes",            -- Dry player clothes (Self Actions)
            "wetclothes",            -- Wet player clothes (Self Actions)
            "uncuffSelf",            -- Uncuff yourself/others
            "cuff",                  -- Cuff a player
            "jobpage",               -- Access jobs page
            "gangpage",              -- Access gangs page
            "banspage",              -- Access bans page
            "screenshot",            -- Screenshot a player
            "spectate",              -- Spectate a player
            "kick",                  -- Kick a player

            -- Dashboard "Server Actions" group (VoidLine 2026-09-02)
            "time",                  -- Set server time
            "reviveall",             -- Revive all players
            "messageall",            -- Message all players

            -- Dashboard "Vehicle Actions" group (VoidLine 2026-09-02)
            "repairvehicle",         -- Repair current vehicle
            "fillgastank",           -- Fill gas tank
            "washvehicle",           -- Wash vehicle
            "maxperformanceupgrades",-- Max upgrades (vehicle)
            "randomvisualparts",     -- Random visual parts (vehicle)
            "setcolor",              -- Set color (vehicle)
            "setlivery",             -- Set livery (vehicle)
            "setmedriver",           -- Teleport as driver
            "setmepassenger",        -- Teleport as passenger
            "lockvehicle",           -- Lock a vehicle
            "unlockvehicle",         -- Unlock a vehicle

            -- Explicitly NOT granted (VoidLine 2026-09-02):
            --   "resourcepage"                          -- Resources page/tab
            --   "vec3", "vec4", "heading", "ipl", "setViewDistance",
            --   "copyEntityInfo", "freeaimMode", "displayVehicles",
            --   "displayPeds", "displayObjects"          -- Dashboard "Developer Actions" group
            --   "spawncar", "deleteclosestvehicle", "deleteclosestped",
            --   "deleteclosestobject", "massdeleteentities" -- Dashboard "Entity Actions" group
            --   "clearreports", "clearadminchat", "clearlogs", "kickall" -- God-only by original design
        },
    },

    -- ═══════════════════════════════════════════════════════
    -- MODERATOR — Panel access + spectate + Dashboard "Self Actions" ONLY.
    -- No pages beyond the dashboard, no per-player moderation actions
    -- (ban/kick/freeze/teleport/warn/etc), no Server/Vehicle/Developer/
    -- Entity Actions groups.
    --
    -- Caveat (VoidLine 2026-09-02): "revive" and "skinmenu" each gate a
    -- single server event shared by both the self-action button AND the
    -- equivalent per-player action (there's no separate "revive yourself"
    -- vs "revive a player" permission string in this codebase). Granting
    -- them for the Self Actions buttons therefore also technically permits
    -- reviving/skinning OTHER players via those same events. "teleport" is
    -- NOT granted for the same reason (it also gates goto/bring/send-back
    -- on OTHER players) -- so moderator's "Go Back" self-action button
    -- will not work; splitting these permissions apart is a larger change
    -- outside this task's scope.
    -- ═══════════════════════════════════════════════════════
    ["moderator"] = {
        AllowedActions = {
            "adminmenu",      -- Open the admin menu
            "spectate",       -- Spectate a player
            "revive",         -- Revive self (see caveat above)
            "uncuffSelf",     -- Uncuff self
            "skinmenu",       -- Clothing menu (see caveat above)
            "invisibility",   -- Toggle invisibility
            "playerblips",    -- Toggle player blips
            "playernames",    -- Toggle player names
            "fastrun",        -- Speed toggle
            "noclip",         -- Noclip
            "godmode",        -- Self god mode
            "forceradar",     -- Radar toggle
            "superjump",      -- Superjump
            "noragdoll",      -- No-ragdoll
            "infinitestam",   -- Infinite stamina
            "clearblood",     -- Clear own blood
            "wetclothes",     -- Wet clothes
            "dryclothes",     -- Dry clothes
        },
    },
}


-------                  KEYS              --------           
---------------------------------------------------


Config.Keys = {
    ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
}


-------               FUNCTIONS            --------           
---------------------------------------------------

function DebugTrace(message)
    if Config.EnableDebug then
        print("^3[919DESIGN Admin ("..GetCurrentResourceName()..")]^7 "..message)
    end
end

function print_table(node)
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)

    print(output_str)
end

function ExtractIdentifiers(src)
    local identifiers = {
        steam = "",
        ip = "",
        discord = "",
        license = "",
        xbl = "",
        live = ""
    }

    --Loop over all identifiers
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)

        --Convert it to a nice table.
        if string.find(id, "steam") then
            identifiers.steam = id
        elseif string.find(id, "ip") then
            identifiers.ip = id
        elseif string.find(id, "discord") then
            identifiers.discord = id
        elseif string.find(id, "license") then
            identifiers.license = id
        elseif string.find(id, "xbl") then
            identifiers.xbl = id
        elseif string.find(id, "live") then
            identifiers.live = id
        end
    end

    return identifiers
end

local entityEnumerator = {
    __gc = function(enum)
      if enum.destructor and enum.handle then
        enum.destructor(enum.handle)
      end
      enum.destructor = nil
      enum.handle = nil
    end
  }
  
  local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
      local iter, id = initFunc()
      if not id or id == 0 then
            disposeFunc(iter)
            return
        end
      
        local enum = {handle = iter, destructor = disposeFunc}
        setmetatable(enum, entityEnumerator)
      
        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next
      
        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end
  
function EnumerateObjects()
    return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end
  
function EnumeratePeds()
    return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end
  
function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end
  
function EnumeratePickups()
    return EnumerateEntities(FindFirstPickup, FindNextPickup, EndFindPickup)
end