-- Server owns the permission check. The client is never asked whether it is
-- allowed -- it would have no reason to answer honestly.
---@param src number 0 = console
local function allowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(tostring(src), CopyOutfit.ace)
end

local function notify(src, msg, kind)
    if src == 0 then
        print('[vl_copyoutfit] ' .. msg)
        return
    end
    pcall(function() exports.qbx_core:Notify(src, msg, kind or 'inform') end)
end


-- Pulls `fromSrc`'s live appearance and puts it on `toSrc`.
-- `invoker` only ever receives error/confirmation messages.
local function transferOutfit(invoker, fromSrc, toSrc)
    lib.callback('vl_copyoutfit:client:getAppearance', fromSrc, function(appearance)
        if type(appearance) ~= 'table' then
            notify(invoker, 'Could not read that player\'s outfit (are they fully loaded in?).', 'error')
            return
        end

        local imposedBy = (toSrc ~= invoker) and GetPlayerName(invoker) or nil
        TriggerClientEvent('vl_copyoutfit:client:apply', toSrc, appearance, GetPlayerName(fromSrc), imposedBy)

        if toSrc ~= invoker then
            notify(invoker, ('Put %s\'s outfit on %s.'):format(GetPlayerName(fromSrc), GetPlayerName(toSrc)), 'success')
        end

        -- Logged deliberately. Changing what another player looks like is
        -- exactly the kind of action that needs a trail if it is questioned.
        print(('[vl_copyoutfit] %s (%d) put the outfit of %s (%d) onto %s (%d)')
            :format(GetPlayerName(invoker), invoker,
                    GetPlayerName(fromSrc), fromSrc,
                    GetPlayerName(toSrc), toSrc))
    end)
end

-- A cross-model refusal happens on the wearer's client; relay it back so the
-- admin who typed the command is not left staring at silence.
RegisterNetEvent('vl_copyoutfit:server:relayFailure', function(msg)
    if type(msg) ~= 'string' or #msg > 256 then return end
    print(('[vl_copyoutfit] %s: %s'):format(GetPlayerName(source) or '?', msg))
end)

RegisterCommand(CopyOutfit.command, function(src, args)
    if not allowed(src) then
        notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    if src == 0 then
        print('[vl_copyoutfit] this command has to be run by a player - it dresses whoever typed it.')
        return
    end

    local targetSrc = tonumber(args[1])
    if not targetSrc then
        notify(src, ('Usage: /%s <server id>'):format(CopyOutfit.command), 'error')
        return
    end

    if targetSrc == src then
        notify(src, 'That is you.', 'error')
        return
    end

    if not GetPlayerName(targetSrc) then
        notify(src, ('No player online with id %d.'):format(targetSrc), 'error')
        return
    end

    -- Ask the target's own client for what it is wearing. Their client is the
    -- only thing that knows the live state, and this is read-only on their end
    -- -- nothing about their character is changed.
    transferOutfit(src, targetSrc, src)
end, false)

-- /setoutfit <fromId> <toId> -- dress someone else in a third player's outfit.
RegisterCommand(CopyOutfit.setCommand, function(src, args)
    if not allowed(src) then
        notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    local fromSrc, toSrc = tonumber(args[1]), tonumber(args[2])
    if not fromSrc or not toSrc then
        notify(src, ('Usage: /%s <fromId> <toId>'):format(CopyOutfit.setCommand), 'error')
        return
    end

    if not GetPlayerName(fromSrc) then
        notify(src, ('No player online with id %d.'):format(fromSrc), 'error')
        return
    end
    if not GetPlayerName(toSrc) then
        notify(src, ('No player online with id %d.'):format(toSrc), 'error')
        return
    end
    if fromSrc == toSrc then
        notify(src, 'Those are the same player.', 'error')
        return
    end

    -- src may be 0 (console) here: unlike /copyoutfit this does not dress the
    -- invoker, so running it from the server console is perfectly valid.
    transferOutfit(src, fromSrc, toSrc)
end, false)

-- /restoreoutfit [id] -- put back what you, or the given player, were wearing.
RegisterCommand(CopyOutfit.restoreCommand, function(src, args)
    if not allowed(src) then
        notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    local targetSrc = tonumber(args[1]) or src
    if targetSrc == 0 then
        notify(src, 'Give a player id - the console has nothing to restore.', 'error')
        return
    end
    if not GetPlayerName(targetSrc) then
        notify(src, ('No player online with id %d.'):format(targetSrc), 'error')
        return
    end

    TriggerClientEvent('vl_copyoutfit:client:restore', targetSrc)
    if targetSrc ~= src then
        notify(src, ('Restored %s\'s previous outfit.'):format(GetPlayerName(targetSrc)), 'success')
    end
end, false)
