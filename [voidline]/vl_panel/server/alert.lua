-- =============================================================================
-- vl_alert -- server
--
-- /vl_alert broadcasts a full-screen emergency transmission to every player.
-- It replaced /eas-lspd and /eas-lsfd, which were identical to each other in
-- everything but name.
--
-- /pageralert and /pageralertto push the same idea to af-pager instead: a
-- message that lands in the pager's WARNING tab rather than covering the
-- screen. Added here because this is already the broadcast resource; the pager
-- calls are guarded so vl_alert still works with af-pager stopped.
-- =============================================================================

local COMMAND = 'vl_alert'
local ACE = 'lance.eas'  -- granted to group.admin in permissions.cfg

---@param src number 0 = server console
---@return boolean
local function isAllowed(src)
    -- Console always passes.
    if src == 0 then return true end

    -- Identifier allowlist from server_config.lua.
    for _, id in ipairs(VLAlertConfig.EAS.admins or {}) do
        for _, pid in ipairs(GetPlayerIdentifiers(src)) do
            if string.lower(pid) == string.lower(id) then
                return true
            end
        end
    end

    -- ACE. This used to sit in an if/else whose else branch reset the result to
    -- false, silently throwing away any match from the list above and making
    -- the allowlist dead code. Both paths now grant independently.
    if IsPlayerAceAllowed(src, ACE) then
        return true
    end

    return false
end

RegisterCommand(COMMAND, function(src, args)
    if not isAllowed(src) then
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 200, 140, 50 },
                args = { 'ALERT', 'You do not have permission to broadcast.' },
            })
        else
            print('[vl_alert] not permitted')
        end
        return
    end

    local msg = table.concat(args, ' ')
    if msg == '' then
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 200, 140, 50 },
                args = { 'ALERT', 'Usage: /' .. COMMAND .. ' <message>' },
            })
        else
            print('[vl_alert] usage: ' .. COMMAND .. ' <message>')
        end
        return
    end

    TriggerClientEvent('SendAlert', -1, '', msg)

    local who = src > 0 and GetPlayerName(src) or 'console'
    print(('[vl_alert] %s broadcast: %s'):format(who, msg))
end, false)


-- =============================================================================
-- Pager broadcasts (af-pager)
--
-- af-pager exposes SendPagerWarning as a SERVER export, so it cannot be called
-- from chat directly -- these two commands are that missing front door.
--
-- Both accept an optional title using `title | body`:
--     /pageralert EVACUATION | Hostiles in the north sector, move south
--     /pageralert Supply drop inbound              (title falls back to WARNING)
--
-- Delivery is NOT guaranteed. af-pager's antenna system is on, so a player
-- outside 1500m of a relay tower has no signal and is counted as a failure.
-- The export returns nothing useful about that, hence the "sent" wording in
-- the feedback rather than "delivered".
-- =============================================================================

local PAGER_RESOURCE = 'af-pager'

---@param src number 0 = server console
---@param text string
local function reply(src, text)
    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 200, 140, 50 },
            args = { 'PAGER', text },
        })
    else
        print('[vl_alert] ' .. text)
    end
end

--- Splits "TITLE | body" into its two halves. No pipe means no title, and
--- af-pager then falls back to VLAlertConfig.WarningDefaultTitle ('WARNING').
---@param raw string
---@return string? title, string body
local function splitTitle(raw)
    local title, body = raw:match('^(.-)%s*|%s*(.+)$')

    if title and title ~= '' and body and body ~= '' then
        return title, body
    end

    return nil, raw
end

---@param src number
---@param target string|number 'all', a server id, a pager id, or a list
---@param raw string
---@return boolean
local function sendPage(src, target, raw)
    if GetResourceState(PAGER_RESOURCE) ~= 'started' then
        reply(src, PAGER_RESOURCE .. ' is not running, nothing was sent.')
        return false
    end

    local title, body = splitTitle(raw)
    local payload = { body = body }

    if title then payload.title = title end

    local ok, err = pcall(function()
        exports[PAGER_RESOURCE]:SendPagerWarning(target, payload)
    end)

    if not ok then
        reply(src, 'af-pager rejected the message: ' .. tostring(err))
        return false
    end

    return true
end

RegisterCommand('pageralert', function(src, args)
    if not isAllowed(src) then
        return reply(src, 'You do not have permission to broadcast.')
    end

    local raw = table.concat(args, ' ')

    if raw == '' then
        return reply(src, 'Usage: /pageralert [TITLE | ]<message>')
    end

    if sendPage(src, 'all', raw) then
        reply(src, 'Sent to every pager in range.')
        print(('[vl_alert] %s paged all: %s'):format(
            src > 0 and GetPlayerName(src) or 'console', raw))
    end
end, false)

RegisterCommand('pageralertto', function(src, args)
    if not isAllowed(src) then
        return reply(src, 'You do not have permission to broadcast.')
    end

    local target = args[1]

    if not target or not args[2] then
        return reply(src, 'Usage: /pageralertto <serverId|pagerId> [TITLE | ]<message>')
    end

    -- af-pager reads a number as a server id and a string as a pager id, so the
    -- conversion decides which lookup it does. "12" must become 12; "P482917"
    -- must stay a string.
    local resolved = tonumber(target) or target
    local raw = table.concat(args, ' ', 2)

    if sendPage(src, resolved, raw) then
        reply(src, ('Sent to %s.'):format(tostring(target)))
        print(('[vl_alert] %s paged %s: %s'):format(
            src > 0 and GetPlayerName(src) or 'console', tostring(target), raw))
    end
end, false)

-- Confirmation line at start. The pager commands were added to a file that was
-- already loaded, and the only symptom of forgetting to restart is a command
-- that does nothing -- FiveM does not say "no such command" for one that was
-- never registered by a running resource. This makes the state visible.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    print(('[vl_alert] commands ready: /%s, /pageralert, /pageralertto (ace: %s)')
        :format(COMMAND, ACE))

    if GetResourceState(PAGER_RESOURCE) ~= 'started' then
        print(('[vl_alert] note: %s is %s -- the two pager commands will refuse until it is started.')
            :format(PAGER_RESOURCE, GetResourceState(PAGER_RESOURCE)))
    end
end)
