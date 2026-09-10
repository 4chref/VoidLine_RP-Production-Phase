local APPEARANCE = 'illenium-appearance'

-- What we were wearing before the most recent copy, so it can be put back.
local previous = nil

local function notify(msg, kind)
    pcall(function() exports.qbx_core:Notify(msg, kind or 'inform') end)
end

-- Asked of the TARGET client. Returns their current appearance.
--
-- Read live off the ped rather than from the database on purpose: what someone
-- is wearing right now is frequently not what is saved (a job uniform, a
-- disguise, a temporary outfit), and "copy what I can see" is the whole point.
lib.callback.register('vl_copyoutfit:client:getAppearance', function()
    return exports[APPEARANCE]:getPedAppearance(cache.ped)
end)

local function applyOutfit(appearance)
    local ped = cache.ped

    if CopyOutfit.copyAppearance or CopyOutfit.copyModel then
        -- setPlayerAppearance re-creates the ped, so `ped` is stale afterwards.
        exports[APPEARANCE]:setPlayerAppearance(appearance)
        return true
    end

    exports[APPEARANCE]:setPedComponents(ped, appearance.components)
    exports[APPEARANCE]:setPedProps(ped, appearance.props)
    return true
end

-- `imposedBy` is the admin's name when someone else dressed us, nil when we
-- ran the command ourselves. Only the wording differs -- a player silently
-- changing clothes with no explanation is worse than being told why.
RegisterNetEvent('vl_copyoutfit:client:apply', function(appearance, targetName, imposedBy)
    if type(appearance) ~= 'table' then return end

    local mine = exports[APPEARANCE]:getPedAppearance(cache.ped)

    -- Component indices are per-model: item 4/12 on a male model is a different
    -- garment from 4/12 on a female one. Applying across a mismatch does not
    -- error, it just dresses you in whatever happens to sit at those indices --
    -- usually invisible or broken. Refuse instead of producing that silently.
    if not CopyOutfit.copyModel and mine.model ~= appearance.model then
        local msg = ('%s uses a different ped model - outfit indices would not match. Enable CopyOutfit.copyModel to copy it anyway.')
            :format(targetName or 'That player')
        notify(msg, 'error')
        -- Tell the admin too: they are the one who ran the command, and
        -- otherwise a cross-model refusal looks like the command did nothing.
        TriggerServerEvent('vl_copyoutfit:server:relayFailure', msg)
        return
    end

    previous = mine

    if applyOutfit(appearance) then
        if imposedBy then
            notify(('%s changed your outfit to %s\'s.'):format(imposedBy, targetName or 'another player'), 'inform')
        else
            notify(('Copied %s\'s outfit. /%s to undo.'):format(targetName or 'player', CopyOutfit.restoreCommand), 'success')
        end
    end
end)

RegisterNetEvent('vl_copyoutfit:client:restore', function()
    if not previous then
        notify('Nothing to restore - you have not copied an outfit this session.', 'error')
        return
    end

    applyOutfit(previous)
    previous = nil
    notify('Your previous outfit is back.', 'success')
end)
