-- =============================================================================
-- vl_panel -- server
--
-- Two jobs:
--   1. Gate and dispatch the four systems' own commands via ExecuteCommand.
--   2. Push live player positions to whichever admins currently have the
--      panel open (the "watchers" set below), and only them.
-- =============================================================================

---@param src number 0 = console
---@return boolean
local function allowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(tostring(src), VLPanel.ace)
end

---Strips characters that would let a free-text field escape a single console
---command. ExecuteCommand runs its argument as if typed in console, where `;`
---chains a second command and a newline starts one outright -- an admin
---client is still a client, and nothing client-supplied should be trusted
---enough to skip this just because the ACE check above already passed.
---@param text string
---@return string
local function sanitise(text)
    return (tostring(text or ''):gsub('[;\r\n]', ''))
end

local function denyDeny(src)
    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 200, 60, 60 },
            args = { 'PANEL', 'You do not have permission to use this.' },
        })
    end
end

-- =============================================================================
-- ACTIONS
--
-- Every handler re-checks `allowed(src)` itself rather than trusting a single
-- gate earlier in the chain -- these are the only checkpoint the four systems
-- underneath get, since ExecuteCommand runs as console and auto-passes their
-- own checks. Get this wrong and the whole point of those systems' own
-- permission checks is silently bypassed for anyone who can reach this event.
-- =============================================================================

RegisterNetEvent('vl_panel:blackoutOn', function(duration)
    local src = source
    if not allowed(src) then return denyDeny(src) end

    local arg = sanitise(duration)
    ExecuteCommand(arg ~= '' and ('blackouton %s'):format(arg) or 'blackouton')
end)

RegisterNetEvent('vl_panel:blackoutOff', function()
    local src = source
    if not allowed(src) then return denyDeny(src) end
    ExecuteCommand('blackoutoff')
end)

RegisterNetEvent('vl_panel:alert', function(message)
    local src = source
    if not allowed(src) then return denyDeny(src) end

    local msg = sanitise(message)
    if msg == '' then return end

    ExecuteCommand(('vl_alert %s'):format(msg))
end)

RegisterNetEvent('vl_panel:pagerAlert', function(title, message)
    local src = source
    if not allowed(src) then return denyDeny(src) end

    local body = sanitise(message)
    if body == '' then return end

    local t = sanitise(title)
    local raw = (t ~= '') and (('%s | %s'):format(t, body)) or body

    ExecuteCommand(('pageralert %s'):format(raw))
end)

RegisterNetEvent('vl_panel:airraidOn', function()
    local src = source
    if not allowed(src) then return denyDeny(src) end
    ExecuteCommand('airraidon')
end)

RegisterNetEvent('vl_panel:airraidOff', function()
    local src = source
    if not allowed(src) then return denyDeny(src) end
    ExecuteCommand('airraidoff')
end)

-- =============================================================================
-- YOUTUBE BROADCAST
--
-- Plays a YouTube video, fullscreen with sound, on EVERY connected client at
-- once -- unlike the radar above, this is a genuine broadcast (src -1), not
-- limited to watchers/admins. The server extracts and validates the video ID
-- itself rather than trusting the client's URL string verbatim: only an
-- 11-character YouTube ID (the one thing every URL shape below reduces to)
-- ever reaches TriggerClientEvent, so there is no way for arbitrary text or
-- markup to ride along into every player's NUI.
-- =============================================================================

---Extracts the 11-char YouTube video ID from any common URL shape
---(watch?v=, youtu.be/, /embed/, /shorts/) or a bare ID typed directly.
---@param input string
---@return string? videoId
local function extractYoutubeId(input)
    local s = tostring(input or ''):gsub('%s+', '')
    if s == '' then return nil end

    local id = s:match('[?&]v=([%w_%-]+)')
        or s:match('youtu%.be/([%w_%-]+)')
        or s:match('/embed/([%w_%-]+)')
        or s:match('/shorts/([%w_%-]+)')
        or s:match('/live/([%w_%-]+)')
        or (s:match('^[%w_%-]+$') and s or nil)

    if id and #id >= 11 then
        return id:sub(1, 11)
    end
    return nil
end

RegisterNetEvent('vl_panel:youtubePlay', function(url)
    local src = source
    if not allowed(src) then return denyDeny(src) end

    local id = extractYoutubeId(url)
    if not id then
        print(('[vl_panel] youtubePlay: could not extract a video ID from "%s"'):format(tostring(url)))
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 200, 60, 60 },
                args = { 'PANEL', 'That does not look like a valid YouTube link.' },
            })
        end
        return
    end

    print(('[vl_panel] youtubePlay: broadcasting video "%s" to all clients'):format(id))
    TriggerClientEvent('vl_panel:youtubeShow', -1, id)

    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 130, 190, 130 },
            args = { 'PANEL', ('Now playing on all screens: %s'):format(id) },
        })
    end
end)

RegisterNetEvent('vl_panel:youtubeStop', function()
    local src = source
    if not allowed(src) then return denyDeny(src) end
    print('[vl_panel] youtubeStop: broadcasting stop to all clients')
    TriggerClientEvent('vl_panel:youtubeHide', -1)
end)

-- Console-only debug command: bypasses the NUI panel entirely so the
-- broadcast/display chain can be tested in isolation from the button/fetch
-- chain. `vl_youtube <url>` from the server console.
RegisterCommand('vl_youtube', function(source, args)
    if source ~= 0 then return end -- console only
    local url = table.concat(args, ' ')
    local id = extractYoutubeId(url)
    if not id then
        print(('[vl_panel] vl_youtube: could not extract a video ID from "%s"'):format(url))
        return
    end
    print(('[vl_panel] vl_youtube: broadcasting video "%s" to all clients'):format(id))
    TriggerClientEvent('vl_panel:youtubeShow', -1, id)
end, true)

-- =============================================================================
-- LIVE PLAYER RADAR
--
-- Pushed only to players who currently have the panel open, not broadcast to
-- everyone -- a set rather than a single "is it open" flag, since more than
-- one admin can have the panel up at once.
-- =============================================================================

local watchers = {} -- src -> true

RegisterNetEvent('vl_panel:watchStart', function()
    local src = source
    if not allowed(src) then return denyDeny(src) end
    watchers[src] = true
end)

RegisterNetEvent('vl_panel:watchStop', function()
    watchers[source] = nil
end)

AddEventHandler('playerDropped', function()
    watchers[source] = nil
end)

CreateThread(function()
    while true do
        if next(watchers) ~= nil then
            local players = {}

            for _, playerId in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(playerId)
                if ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    players[#players + 1] = {
                        id = tonumber(playerId),
                        name = GetPlayerName(playerId) or ('#' .. playerId),
                        x = coords.x,
                        y = coords.y,
                    }
                end
            end

            for src in pairs(watchers) do
                -- A watcher can disconnect between the loop starting and this
                -- line; TriggerClientEvent to a gone player is a harmless no-op,
                -- but drop the stale entry so the set does not grow forever.
                if GetPlayerName(src) then
                    TriggerClientEvent('vl_panel:players', src, players)
                else
                    watchers[src] = nil
                end
            end
        end

        Wait(VLPanel.radar.pushIntervalMs)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    watchers = {}
end)
