-- =============================================================================
-- vl_airraid -- server
--
-- One GlobalState table, two admin commands, nothing timed. vl_blackout
-- schedules its own end because a blackout always has a duration; an air raid
-- does not -- the brief was "till I stop the script" -- so there is no timer
-- here to get wrong, and no remaining-time math for a late joiner (see
-- vl_blackout's vl_airraid:requestState... there isn't one, on purpose:
-- GlobalState already replicates to a joining client with nothing extra
-- needed).
--
-- `startedAt` exists for exactly one reason: so every site's siren loop is
-- PHASE-LOCKED to when the raid began, not to when a given player happened to
-- walk into range. Without it, each site's loop restarts from 0:00 the moment
-- someone enters its zone, which reads as "the sound starts playing when I
-- arrive" rather than "the siren has been going the whole time and I just
-- started hearing it".
--
-- The callback below is how a client actually gets that as a number of
-- elapsed SECONDS: FiveM's client Lua has no `os` library at all, so a client
-- cannot compute `os.time() - startedAt` itself the way this file can. Only
-- the server ever calls os.time(); see client/main.lua's start().
-- =============================================================================

-- Bumped once per /airraidon; every scheduled intro step compares against it so
-- /airraidoff can cancel a sequence already in flight.
local currentToken = 0
local introToken = nil

---@return boolean
local function isActive()
    local s = GlobalState.airraid
    return s ~= nil and s.active == true
end

---@param src number 0 = console
local function allowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(tostring(src), VLAirRaid.ace)
end

local function notify(src, text, kind)
    if src == 0 then
        print('[vl_airraid] ' .. text)
        return
    end
    exports.qbx_core:Notify(src, text, kind or 'inform')
end

-- One round trip per client per raid-activation (not per site -- see
-- client/main.lua's start()). Returns 0 rather than erroring if asked while
-- nothing is running, since a client can legitimately race this against the
-- raid ending between its state-bag read and this reply landing.
lib.callback.register('vl_airraid:getElapsed', function(_)
    local s = GlobalState.airraid
    if not s or s.active ~= true or not s.startedAt then return 0 end
    return math.max(0, os.time() - s.startedAt)
end)

math.randomseed(os.time())

---Shuffles site 1..#sites into a random cascade order, one site every
---`VLAirRaid.cascadeIntervalMs` -- "sirens start randomly one by one" rather
---than every site starting in the same instant. Returns delays[i] = how many
---seconds after startedAt site i is due to begin.
---
---Generated ONCE per /airraidon and put straight in GlobalState, so every
---client works from the exact same schedule -- this has to be server-decided
---and replicated, not rolled independently per client, or different players
---would disagree about which site goes off when.
---@return table<integer, number>
local function rollCascade()
    local order = {}
    for i = 1, #VLAirRaid.sites do order[i] = i end

    -- Fisher-Yates.
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end

    local stepSeconds = VLAirRaid.cascadeIntervalMs / 1000.0
    local delays = {}
    for position, siteIndex in ipairs(order) do
        delays[siteIndex] = (position - 1) * stepSeconds
    end
    return delays
end

-- =============================================================================
-- INTRO SEQUENCE
--
-- The raid is announced before it arrives -- pager, radio, blackout, outpost
-- alarm, then the sirens. See VLAirRaid.intro in config.lua for the timings.
--
-- ORDER OF OPERATIONS matters here, and not in the obvious way: GlobalState is
-- set LAST, immediately before the sirens are due. That flag is what every
-- client's siren loop and vl_hud's threat icon read, so setting it up front
-- would light the icon and start the cascade clock while the pager message was
-- still being typed -- the whole point of the intro is that the sirens are the
-- last thing to happen, not the first.
--
-- Each step is scheduled with its own SetTimeout rather than one thread with
-- Waits, so a step that is disabled costs nothing and the delays stay absolute
-- (measured from /airraidon) instead of accumulating.
-- =============================================================================

---Escape a string for safe use inside ExecuteCommand.
---Same reasoning as server/panel.lua's sanitise(): the result is executed as
---though typed into the console, so a stray ; or newline would be a second
---command.
---@param text string
---@return string
local function sanitise(text)
    return (tostring(text or ''):gsub('[;\r\n]', ''))
end

---@param src number who triggered the raid, for the confirmation line
local function runIntro(src)
    local intro = VLAirRaid.intro or {}

    local function beginSirens()
        -- Bail if someone ran /airraidoff during the intro -- without this the
        -- sirens would start anyway, minutes after being cancelled.
        if not introToken or introToken ~= currentToken then return end

        -- Belt and braces: silence the outpost alarm again at the instant the
        -- sirens begin. It is already stopped on its own schedule, but that
        -- schedule is derived from a CONFIGURED clip length -- if clipMs is
        -- ever shorter than the real file, the alarm would still be sounding
        -- here and the two would overlap. Three of the four outposts sit
        -- 212-449m from a siren site, well inside both audible ranges, so an
        -- overlap would be heard exactly where it is least wanted.
        TriggerClientEvent('vl_airraid:intruder', -1, false)

        GlobalState.airraid = { active = true, startedAt = os.time(), delays = rollCascade() }

        local rolloutSeconds = (#VLAirRaid.sites - 1) * (VLAirRaid.cascadeIntervalMs / 1000.0)
        notify(src, ('Air raid siren sounding at %d sites over the next %ds. Use /%s to stop.')
            :format(#VLAirRaid.sites, math.ceil(rolloutSeconds), VLAirRaid.commands.off), 'success')
    end

    if intro.enabled == false then
        return beginSirens()
    end

    -- A token per activation. Every scheduled step checks it, so /airraidoff
    -- mid-intro cancels the rest instead of letting a blackout or a siren land
    -- after the admin already called it off.
    currentToken = (currentToken or 0) + 1
    introToken = currentToken
    local token = currentToken
    local function live() return introToken == token end

    local pager = intro.pager or {}
    local radio = intro.radio or {}
    local blackout = intro.blackout or {}
    local intruder = intro.intruder or {}

    notify(src, 'Air raid warning sequence started.', 'inform')

    -- 1. PAGER
    if pager.text then
        SetTimeout(pager.delayMs or 0, function()
            if not live() then return end
            ExecuteCommand(('pageralert %s | %s')
                :format(sanitise(pager.title or 'WARNING'), sanitise(pager.text)))
        end)
    end

    -- 2. RADIO TRANSMISSION
    if radio.text then
        SetTimeout(radio.delayMs or 0, function()
            if not live() then return end
            TriggerClientEvent('vl_airraid:radio', -1, {
                channel = radio.channel,
                text = radio.text,
                sound = radio.sound or nil,
                volume = radio.volume,
                holdMs = radio.holdMs,
                typeMs = radio.typeMs,
            })
        end)
    end

    -- 3. BLACKOUT -- our own, not /blackouton. See config.lua for why.
    SetTimeout(blackout.delayMs or 0, function()
        if not live() then return end
        TriggerClientEvent('vl_airraid:blackout', -1, true, blackout.affectVehicles and true or false)
    end)

    -- 4. OUTPOST ALARM
    SetTimeout(intruder.delayMs or 0, function()
        if not live() then return end
        TriggerClientEvent('vl_airraid:intruder', -1, true)
    end)

    -- 5. SIRENS.
    --
    -- Measured from the END of the outpost alarm, not from when it started:
    -- the alarm plays a fixed number of times and the four seconds are meant
    -- to be four seconds of silence after it, not four seconds of overlap.
    --
    -- The window is computed here rather than reported back by a client on
    -- purpose. The sirens must begin at the same instant for everyone, so the
    -- server has to own the schedule -- and it cannot ask a browser how long
    -- an mp3 is. That is what VLAirRaid.intruderAudio.clipMs is for.
    local ia = VLAirRaid.intruderAudio or {}
    local alarmMs = (tonumber(ia.plays) or 1) * (tonumber(ia.clipMs) or 4000)

    -- Stop the alarm's range loops once its window has passed, so a player
    -- walking to an outpost a minute later does not re-trigger it.
    SetTimeout((intruder.delayMs or 0) + alarmMs, function()
        if live() then TriggerClientEvent('vl_airraid:intruder', -1, false) end
    end)

    SetTimeout((intruder.delayMs or 0) + alarmMs + (intro.sirenDelayMs or 4000), function()
        if live() then beginSirens() end
    end)
end

RegisterCommand(VLAirRaid.commands.on, function(src)
    if not allowed(src) then
        notify(src, 'Only admins can sound the air raid siren.', 'error')
        return
    end

    if isActive() then
        notify(src, ('Already running. Use /%s to stop it.'):format(VLAirRaid.commands.off), 'error')
        return
    end

    runIntro(src)
end, false)

RegisterCommand(VLAirRaid.commands.off, function(src)
    if not allowed(src) then
        notify(src, 'Only admins can silence the air raid siren.', 'error')
        return
    end

    -- An intro still counting down is "running" even though the sirens have
    -- not started and isActive() is false -- cancelling has to work then too,
    -- or the admin watches the raid they just stopped arrive anyway.
    local pending = introToken ~= nil

    if not isActive() and not pending then
        notify(src, 'Nothing is running.', 'error')
        return
    end

    introToken = nil
    GlobalState.airraid = { active = false }
    TriggerClientEvent('vl_airraid:intruder', -1, false)
    TriggerClientEvent('vl_airraid:blackout', -1, false)
    notify(src, pending and not isActive()
        and 'Air raid warning sequence cancelled.'
        or 'Air raid siren silenced.', 'success')
end, false)

-- Never come back up mid-raid after a restart -- there is no state to resume,
-- the previous admin's intent does not carry across a resource restart.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    GlobalState.airraid = { active = false }
end)

-- Equally, never leave every client's siren stuck on if this resource stops
-- while a raid is active. A GlobalState write here is NOT trusted to actually
-- replicate -- the resource's networking context is already tearing down, the
-- same reason vl_blackout broadcasts a direct client event on stop instead of
-- relying on GlobalState for this one specific moment. Belt and braces: set
-- the state AND broadcast, since the broadcast is the one guaranteed to land.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    introToken = nil
    GlobalState.airraid = { active = false }
    TriggerClientEvent('vl_airraid:forceStop', -1)
    -- Lights are a client-side native with no state of its own: stopping this
    -- resource mid-raid would otherwise leave the map dark for everyone with
    -- nothing alive to turn it back on.
    TriggerClientEvent('vl_airraid:blackout', -1, false)
end)
