-- VoidLine: added 2026-08-31. The bunker hallway laser fences (see
-- client/editable/bunker_hallway.lua) used to run 24/7 for every player
-- regardless of whether anyone was near the bunker -- constant create/delete
-- churn on 6 beams every 50ms, forever. They're now gated behind two
-- conditions: a blackout is active AND the bunker exit door is unlocked
-- ("open"). This answers the client's query for the door's ox_doorlock id
-- and current state in one call, since ox_doorlock only exposes that
-- lookup server-side (exports.ox_doorlock:getDoorFromName).
local BUNKER_DOOR_NAME = 'bunker exit door'

lib.callback.register('vl_lasers:server:getBunkerDoorInfo', function(source)
    if GetResourceState('ox_doorlock') ~= 'started' then return nil end

    local ok, door = pcall(function()
        return exports.ox_doorlock:getDoorFromName(BUNKER_DOOR_NAME)
    end)

    if not ok or not door then return nil end

    -- state 0 = unlocked ("open"), 1 = locked ("closed") -- same convention
    -- vl_panel's blackout system already uses for this exact door.
    return { id = door.id, open = door.state == 0 }
end)
