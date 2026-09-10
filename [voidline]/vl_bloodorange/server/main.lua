-- ════════════════════════════════════════════════════════════════════════════
--  BLOOD ORANGE  —  server side
-- ════════════════════════════════════════════════════════════════════════════
--  vl_dynamicweather owns and syncs the weather, so there is no second sync
--  loop here. This file only offers a shortcut to slam the preset on/off for
--  the whole server without opening /weatherpanel, plus a small export layer.
-- ════════════════════════════════════════════════════════════════════════════

local TRIGGER = (BO.TriggerWeather or 'HALLOWEEN'):upper()
local RES     = BO.WeatherResource

local function weatherResourceUp()
    return GetResourceState(RES) == 'started'
end

local function canUse(src)
    if src == 0 then return true end -- console
    local id = tostring(src)
    if IsPlayerAceAllowed(id, BO.AcePermission) then return true end
    -- Anyone already trusted with the weather panel is trusted with this.
    if IsPlayerAceAllowed(id, 'dynamicweather.admin') then return true end
    return false
end

--- Force BLOOD ORANGE everywhere. Temperature is pushed high on purpose: the
--- weather panel drives vl_dynamicweather's heat-haze shimmer off temperature,
--- and the shimmer sells the "hot, toxic, dusty" half of the look.
local function setEverywhere(temperature)
    if not weatherResourceUp() then return false, ('%s is not running'):format(RES) end
    local ok, res = pcall(function()
        return exports[RES]:setGlobalWeather(TRIGGER, temperature or 47)
    end)
    if not ok then return false, tostring(res) end
    return res ~= false
end

local function clearEverywhere()
    if not weatherResourceUp() then return false, ('%s is not running'):format(RES) end
    local ok, res = pcall(function() return exports[RES]:clearWeatherOverride() end)
    if not ok then return false, tostring(res) end
    return res ~= false
end

RegisterCommand('bloodorange', function(src, args)
    if not canUse(src) then
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 200, 40, 10 },
                args  = { 'BLOOD ORANGE', 'You are not allowed to do that.' },
            })
        end
        return
    end

    local mode = (args[1] or 'on'):lower()
    local ok, err

    if mode == 'off' or mode == 'clear' or mode == 'stop' then
        ok, err = clearEverywhere()
    else
        ok, err = setEverywhere(tonumber(args[2]))
    end

    local msg
    if ok then
        msg = (mode == 'off' or mode == 'clear' or mode == 'stop')
            and 'Weather override cleared — back to the panel setup.'
            or  'BLOOD ORANGE forced server-wide.'
    else
        msg = 'Failed: ' .. tostring(err or 'rejected by ' .. RES)
    end

    if src == 0 then
        print('[bloodorange] ' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = { 200, 60, 10 },
            args  = { 'BLOOD ORANGE', msg },
        })
    end
end, false)

exports('setGlobal', function(temperature) return setEverywhere(temperature) end)
exports('clearGlobal', function() return clearEverywhere() end)
exports('getTriggerWeather', function() return TRIGGER end)

CreateThread(function()
    Wait(3000)
    if not weatherResourceUp() then
        print(('^3[bloodorange]^7 %s is not started — the preset will fall back to '
            .. 'reading the raw game weather and cannot be driven by /weatherpanel.'):format(RES))
    elseif BO.Debug then
        print(('^2[bloodorange]^7 armed on weather slot %s via %s'):format(TRIGGER, RES))
    end
end)


-- ─── timecycle var dump (debug aid) ─────────────────────────────────────────
-- Receives the client's timecycle variable dictionary and writes it to a file,
-- because which var names a build accepts decides what this preset can control
-- and reading that off the F8 console is painful.
--
-- Deliberately unguarded by ACE: it writes a fixed filename with nothing but
-- names the game itself supplied, and it is the same list on every client. The
-- size cap and the string check are there so a malformed or hostile payload
-- cannot write junk or blow memory.
RegisterNetEvent('vl_bloodorange:dumpVars', function(names)
    if type(names) ~= 'table' then return end
    if #names == 0 or #names > 4000 then return end

    local out = {}
    for i = 1, #names do
        local n = names[i]
        if type(n) == 'string' and #n < 128 then out[#out + 1] = n end
    end

    SaveResourceFile(GetCurrentResourceName(), 'timecycle_vars.txt', table.concat(out, '\n'), -1)
    print(('[bloodorange] wrote %d timecycle var names to timecycle_vars.txt'):format(#out))
end)
