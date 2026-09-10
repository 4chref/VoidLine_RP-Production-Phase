-- Pushes the local player's display name (Steam/Rockstar profile name) into
-- the loading screen NUI while it's still on screen. GetPlayerName(PlayerId())
-- reflects the local profile name and is available before the server
-- connection finishes, so this works during the loadscreen itself.
Citizen.CreateThread(function()
    local name = nil

    -- retry for a few seconds in case the profile name isn't populated yet
    for _ = 1, 50 do
        name = GetPlayerName(PlayerId())
        if name and name ~= '' and name ~= '**Invalid**' then
            break
        end
        Citizen.Wait(100)
    end

    if not name or name == '' then
        name = 'Player'
    end

    SendLoadingScreenMessage(json.encode({
        eventName = 'setPlayerName',
        name = name,
    }))
end)
