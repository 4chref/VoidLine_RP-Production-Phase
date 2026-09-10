-- ════════════════════════════════════════════════════════════════════════════
--  BLOOD ORANGE  —  client runtime
-- ════════════════════════════════════════════════════════════════════════════
--  Watches the weather vl_dynamicweather has synced to this client and, while
--  it equals BO.TriggerWeather, keeps the BLOOD ORANGE timecycle preset applied
--  and self-healed. Because the weather itself is server-authoritative and
--  self-healing, every player in the area runs this at the same moment.
-- ════════════════════════════════════════════════════════════════════════════

local active      = false
local built       = false
local modifierIdx = -1
local validVars   = nil       -- lowercased name -> true
local reported    = false

local NAME     = BO.PresetName
local TRIGGER  = (BO.TriggerWeather or 'HALLOWEEN'):upper()

-- client/dust.lua defines BODust. If the manifest change was not picked up --
-- a `restart` alone does not re-read fxmanifest, only `refresh` does -- the
-- global is missing. Degrade to no-ops and say so once, rather than throwing
-- inside the self-heal loop every 500 ms.
local DUST_STUB = {
    stop    = function() end,
    tick    = function() end,
    refresh = function() end,
    count   = function() return 0 end,
}
local warnedNoDust = false
local function dust()
    if BODust then return BODust end
    if not warnedNoDust then
        warnedNoDust = true
        print('^3[bloodorange]^7 client/dust.lua did not load — the dust wall is off. '
            .. 'Run `refresh` then `ensure vl_bloodorange` on the server console: '
            .. 'a plain `restart` does not re-read fxmanifest.lua.')
    end
    return DUST_STUB
end

local function log(...)
    if BO.Debug then print('[bloodorange]', ...) end
end

-- ─── native availability ────────────────────────────────────────────────────
-- CreateTimecycleModifier / SetTimecycleModifierVar are CitizenFX extensions.
-- They exist on every current build, but guard anyway so an old artifact
-- degrades to "stock modifier + screen layer" instead of erroring every frame.
local hasRuntimeTC = (CreateTimecycleModifier ~= nil) and (SetTimecycleModifierVar ~= nil)

-- ─── variable validation ────────────────────────────────────────────────────
-- Ask the running game which timecycle variables it actually knows, so a name
-- this build spells differently is skipped silently instead of throwing.
local function buildVarIndex()
    if validVars then return validVars end
    validVars = {}
    if not GetTimecycleVarCount or not GetTimecycleVarNameByIndex then
        return validVars -- no way to check; applyVars will just try them all
    end
    local ok, count = pcall(GetTimecycleVarCount)
    if not ok or not count or count <= 0 then return validVars end
    for i = 0, count - 1 do
        local ok2, name = pcall(GetTimecycleVarNameByIndex, i)
        if ok2 and type(name) == 'string' and name ~= '' then
            validVars[name:lower()] = true
        end
    end
    log(('timecycle var dictionary: %d names'):format(count))
    return validVars
end

local function isKnownVar(name)
    local index = buildVarIndex()
    if next(index) == nil then return true end -- dictionary unavailable, try anyway
    return index[name:lower()] == true
end

-- ─── atmosphere: visibility + haze colour ───────────────────────────────────
-- Everything that decides how the distance READS lives here, derived from
-- BO.VisibilityMeters / BO.HazeColor / BO.HazeBrightness so it can be retuned
-- live without touching the preset table.
--
--   fog_shape_log_10_of_visibility -- log10 of the distance, in metres, at which
--       the fog becomes opaque. 10 m is 1.0, 100 m is 2.0, vanilla clear weather
--       sits near 4.0. A negative value here does nothing at all.
--
--   far_clip is deliberately NOT used as the visibility lever. A clip plane does
--       not draw fog, it draws nothing -- which is exactly how you get a hard
--       black band across the horizon instead of a mist wall. It is pinned high
--       so geometry always reaches the fog and dissolves into it properly.
local function sampleCurve(curve, hour)
    local exact = curve[hour]
    if exact then return exact end

    -- Nearest defined keyframe below and above, wrapping past midnight.
    local loH, loV, hiH, hiV
    for h, v in pairs(curve) do
        local down = (hour - h) % 24
        local up   = (h - hour) % 24
        if not loH or down < (hour - loH) % 24 then loH, loV = h, v end
        if not hiH or up   < (hiH - hour) % 24 then hiH, hiV = h, v end
    end
    if not loH then return nil end
    if loH == hiH then return loV end

    local span = (hiH - loH) % 24
    if span == 0 then return loV end
    local t = ((hour - loH) % 24) / span
    return loV + (hiV - loV) * t
end

local function atmosphereVars()
    local m = math.max(6.0, tonumber(BO.VisibilityMeters) or 22.0)
    local c = BO.HazeColor or { 0.920, 0.375, 0.115 }
    -- HAZE BRIGHTNESS FOLLOWS THE CLOCK.
    --
    -- This used to be a single fixed number, and applyAtmosphere() re-applies it
    -- after every hourly pass -- so it overwrote the time-of-day work with the
    -- same daylight value at every hour, and the world never got dark. Because
    -- the fog is most of the screen, that one constant was holding the whole
    -- scene lit at midnight.
    local b = tonumber(BO.HazeBrightness) or 1.30
    if type(BO.HazeBrightnessByHour) == 'table' then
        local sampled = sampleCurve(BO.HazeBrightnessByHour, GetClockHours())
        if sampled then b = sampled end
    end

    -- fog_shape_log_10_of_visibility: a timecycle MODIFIER value is not always
    -- applied as an absolute override -- for some variables the engine treats it
    -- as a multiplier against the weather's own keyframe. Which one applies here
    -- decides whether log10(22) = 1.34 means "22 m of visibility" or "22x the
    -- vanilla 4.0", i.e. the difference between a wall and a clearer sky. That
    -- is almost certainly why the earlier values read as no fog at all.
    --
    -- Dividing by the vanilla clear-weather value (~4.0) is dense under BOTH
    -- readings: as an absolute it is well under a metre of visibility, and as a
    -- multiplier it lands back on log10(m). No guess required.
    local logVis = math.log(m, 10) / 4.0

    local vars = {
        fog_shape_log_10_of_visibility = logVis,
        fog_shape_falloff              = 1.0,
        far_clip                       = 1600.0,

        -- Fully opaque haze that starts at the camera. Density/alpha do the
        -- "how much", the log10 visibility above does the "how far".
        fog_start                      = 0.0,
        fog_density                    = 1.0,
        fog_alpha                      = 1.0,
        fog_falloff                    = 1.0,
        fog_haze_start                 = 0.0,
        fog_haze_density               = 1.0,
        fog_haze_alpha                 = 1.0,

        -- A tall, deep slab so the mist fills the sky down to below sea level --
        -- a shallow slab leaves a clean band of unfogged air near the horizon.
        fog_shape_bottom               = -600.0,
        fog_shape_top                  = 2600.0,

        -- Blend the fog into the sky at the horizon so there is no seam.
        fog_horizon_tint_scale         = 1.0,

        -- Brightness of the wall. This IS the distance's exposure: most of the
        -- far half of the screen is literally this colour.
        fog_hdr                        = b,
        fog_haze_hdr                   = b,
    }

    -- Near fog sits at the haze colour; the deep fog a little richer, so
    -- distance darkens *into orange* rather than washing flat.
    vars.fog_near_col_r, vars.fog_near_col_g, vars.fog_near_col_b = c[1], c[2], c[3]
    vars.fog_haze_col_r, vars.fog_haze_col_g, vars.fog_haze_col_b = c[1], c[2], c[3]
    vars.fog_col_r = c[1] * 0.86
    vars.fog_col_g = c[2] * 0.78
    vars.fog_col_b = c[3] * 0.72

    return vars
end

-- The game's own modifier name to use instead of the custom preset, or nil.
-- Declared up here because applyAtmosphere() below needs it.
local function stockModifier()
    local m = BO.StockModifier
    if type(m) == 'string' and m ~= '' then return m end
    return nil
end

local function applyAtmosphere()
    if not built then return end
    -- These write into the runtime modifier NAME. In BO.StockModifier mode that
    -- modifier is never created, so every write here is a silent no-op -- which
    -- is exactly how BO.VisibilityMeters, BO.HazeColor and BO.HazeBrightness
    -- came to look "ignored". Bail explicitly rather than pretending to work.
    if stockModifier and stockModifier() then return end
    for varName, value in pairs(atmosphereVars()) do
        if isKnownVar(varName) then
            pcall(SetTimecycleModifierVar, NAME, varName, value + 0.0, value + 0.0)
        end
    end
end

-- ─── build the modifier ─────────────────────────────────────────────────────

-- Writes BO.KillSunVars into `target`.
--
-- MUST run after every hourly pass, not just once at build. BO.Hourly keyframes
-- light_dir_mult (0.08 at midnight, 0.39 by 09:00) and light_dir_col_*, so the
-- hourly writer was restoring the very directional sun this is meant to remove
-- -- one hour after startup the sun was back, every time. A comment here used
-- to claim light_dir_mult was not in BO.Hourly; it is, and that was the bug.
local function applySunKill(target, verbose)
    if not BO.KillSun or not BO.KillSunVars or not SetTimecycleModifierVar then return end
    local n = 0
    for varName, value in pairs(BO.KillSunVars) do
        if isKnownVar(varName) then
            local okV = pcall(SetTimecycleModifierVar, target, varName, value + 0.0, value + 0.0)
            if okV then n = n + 1 end
        end
    end
    -- FOG SHAPE, written into the same target.
    --
    -- Lives here rather than in atmosphereVars() so it applies in STOCK mode
    -- too. atmosphereVars only ever writes into the runtime modifier, which a
    -- stock grade never creates -- which is why fog was uncontrollable whenever
    -- BO.StockModifier was set, and why the view changed so much with altitude:
    -- nothing was overriding GTA's own height falloff.
    local f = 0
    if type(BO.ForceVars) == 'table' then
        for varName, value in pairs(BO.ForceVars) do
            if isKnownVar(varName) then
                if pcall(SetTimecycleModifierVar, target, varName, value + 0.0, value + 0.0) then
                    f = f + 1
                end
            end
        end
    end

    -- Sight distance, in metres, using the same log10/4 encoding the custom
    -- path uses (see atmosphereVars for why it is divided by 4).
    local vis = tonumber(BO.StockVisibilityMeters)
    if vis and isKnownVar('fog_shape_log_10_of_visibility') then
        local logVis = math.log(math.max(vis, 6.0), 10) / 4.0
        if pcall(SetTimecycleModifierVar, target, 'fog_shape_log_10_of_visibility', logVis, logVis) then
            f = f + 1
        end
    end

    if verbose then
        log(('sun suppression: %d vars, fog shape: %d vars -> %s'):format(n, f, target))
    end
end

local function buildModifier()
    -- A stock grade needs no building -- it is already registered by the game.
    -- Resolve its index so the main-slot ownership check below can still tell
    -- "we own this slot" from "another script does".
    local stock = stockModifier()
    if stock then
        if GetTimecycleModifierIndexByName then
            local okS, idx = pcall(GetTimecycleModifierIndexByName, stock)
            if okS and idx then modifierIdx = idx end
        end

        -- Stock grades render a full-strength sun straight through the fog,
        -- which is added AFTER the grade and the screen tint -- so it cannot be
        -- dialled out by either. Write the suppression straight into the game's
        -- own modifier; see BO.KillSun in the config for the session caveat.
        applySunKill(stock, true)

        built = true
        applyAtmosphere()
        log('using stock timecycle modifier: ' .. stock)
        return true
    end

    if built or not hasRuntimeTC then return built end

    -- A modifier from a previous resource start would still be registered.
    if RemoveTimecycleModifier then pcall(RemoveTimecycleModifier, NAME) end

    local ok, hash = pcall(CreateTimecycleModifier, NAME, BO.PresetDesc or NAME, 1.0)
    if not ok then
        log('CreateTimecycleModifier failed:', hash)
        return false
    end

    local applied, skipped = 0, {}
    for varName, value in pairs(BO.Preset) do
        if isKnownVar(varName) then
            local ok2, err = pcall(SetTimecycleModifierVar, NAME, varName, value + 0.0, value + 0.0)
            if ok2 then
                applied = applied + 1
            else
                skipped[#skipped + 1] = varName .. ' (' .. tostring(err) .. ')'
            end
        else
            skipped[#skipped + 1] = varName
        end
    end

    if GetTimecycleModifierIndexByName then
        local ok3, idx = pcall(GetTimecycleModifierIndexByName, NAME)
        if ok3 and idx then modifierIdx = idx end
    end

    applySunKill(NAME, true)

    built = true
    applyAtmosphere()
    if BO.Debug and not reported then
        reported = true
        log(('preset built: %d vars applied, %d skipped'):format(applied, #skipped))
        if #skipped > 0 then
            log('skipped (not known to this build): ' .. table.concat(skipped, ', '))
        end
    end
    return true
end

-- ─── hourly keyframes ───────────────────────────────────────────────────────
-- BO.Hourly replaces vanilla's per-hour curves (the ones that swing light_dir_col
-- blue after dark) with an all-orange curve. Re-written whenever the in-game
-- hour changes, interpolated between the defined keyframe hours.
local lastHour = -1

local function applyHour(hour, force)
    if not built or not BO.Hourly then return end
    if hour == lastHour and not force then return end
    lastHour = hour

    -- A stock grade ships its own per-hour curves, and the modifier BO.Hourly
    -- targets was never created in that mode -- so every write here would be a
    -- silent no-op fired twice a second. Skip straight to the atmosphere pass,
    -- which is still wanted either way (wind, clouds, weather).
    if stockModifier() then
        applyAtmosphere()
        return
    end

    for varName, curve in pairs(BO.Hourly) do
        if isKnownVar(varName) then
            local v = sampleCurve(curve, hour)
            if v then
                -- BO.Exposure shifts the whole exposure curve instead of replacing
                -- it, so the hourly shape survives while the user trims brightness.
                if varName == 'postfx_exposure' then
                    -- BO.EXPOSURE_BASE must match the midday value of the curve
                    -- above, so the default config value is a no-op offset.
                    v = v + ((tonumber(BO.Exposure) or -0.55) - (-0.55))
                end
                pcall(SetTimecycleModifierVar, NAME, varName, v + 0.0, v + 0.0)
            end
        end
    end
    -- Sun-kill re-asserted AFTER the hourly writes, or BO.Hourly's light_dir_*
    -- keyframes put the sun straight back on the next tick.
    applySunKill(NAME, false)
    applyAtmosphere()   -- must land after the hourly pass, never before
    -- Report the values that decide night brightness, so "still bright at night"
    -- can be diagnosed from the log instead of from screenshots.
    local hb = tonumber(BO.HazeBrightness) or 1.30
    if type(BO.HazeBrightnessByHour) == 'table' then
        hb = sampleCurve(BO.HazeBrightnessByHour, hour) or hb
    end
    log(('hour %02d:00 applied  haze=%.2f  overlay=%s@%.2f  exposure=%.2f')
        :format(hour, hb,
                tostring(BO.StockOverlay ~= '' and BO.StockOverlay or 'none'),
                tonumber(BO.StockOverlayStrength) or 0.0,
                tonumber(BO.Exposure) or 0.0))
end

CreateThread(function()
    while true do
        if active then applyHour(GetClockHours(), false) end
        Wait(2000)
    end
end)

-- ─── apply / clear ──────────────────────────────────────────────────────────
-- The preset always takes the EXTRA slot. It additionally takes the MAIN slot
-- while nothing else owns it, which roughly doubles the strength -- and steps
-- back out the moment another script (heat haze, interiors, scenarios) claims
-- it, so the two never fight over the same slot.
local function pushModifier()
    -- BO.StockModifier wins outright; otherwise the built preset; otherwise
    -- 'heathaze' as the degraded fallback when runtime TC is unavailable.
    local target = stockModifier() or (built and NAME or 'heathaze')

    -- TWO SLOTS, TWO JOBS.
    --
    -- The problem with running a stock grade in BOTH slots is that everything
    -- this resource controls -- sun suppression, visibility/fog, exposure -- is
    -- written into a modifier it creates itself, which a stock grade replaces
    -- rather than layers onto. You got the colours and lost every control.
    --
    -- BO.StockOverlay splits them: the stock grade sits in the EXTRA slot at
    -- its own low strength, contributing only colour, while the custom preset
    -- keeps the MAIN slot and carries the fog, the visibility curve and the
    -- sun-kill. Both apply, and nothing is given up.
    local overlay = BO.StockOverlay
    if type(overlay) ~= 'string' or overlay == '' then overlay = nil end

    -- BO.UseExtraSlot = false runs the grade in the MAIN slot ONLY, which is the
    -- plain SetTimecycleModifier + SetTimecycleModifierStrength arrangement.
    -- With a stock grade that is what you want: putting it in both slots applies
    -- it twice, so a strength of 0.85 does not mean 0.85.
    if BO.UseExtraSlot == false then
        if ClearExtraTimecycleModifier then pcall(ClearExtraTimecycleModifier) end
    elseif SetExtraTimecycleModifier then
        pcall(SetExtraTimecycleModifier, overlay or target)
        if SetExtraTimecycleModifierStrength then
            local st = overlay and (BO.StockOverlayStrength or 0.3) or (BO.Strength or 1.0)
            pcall(SetExtraTimecycleModifierStrength, st)
        end
    end

    if BO.UseMainSlot then
        local current = GetTimecycleModifierIndex and GetTimecycleModifierIndex() or -1
        if current == -1 or (modifierIdx ~= -1 and current == modifierIdx) then
            SetTimecycleModifier(target)
            SetTimecycleModifierStrength(BO.Strength or 1.0)
            if modifierIdx == -1 and GetTimecycleModifierIndex then
                modifierIdx = GetTimecycleModifierIndex()
            end
        end
    end
end

local function popModifier()
    if SetExtraTimecycleModifier then pcall(ClearExtraTimecycleModifier) end
    local current = GetTimecycleModifierIndex and GetTimecycleModifierIndex() or -1
    if modifierIdx ~= -1 and current == modifierIdx then
        ClearTimecycleModifier()
    end
    SetTimecycleModifierStrength(1.0)
end

-- ─── sky / weather dressing ─────────────────────────────────────────────────
-- Swap this client onto the foggy base weather. vl_dynamicweather treats
-- setLocalWeather as a sanctioned deviation, so its 2 s self-heal leaves it
-- alone instead of yanking us back every tick.
-- Snow-family bases carry the driving precipitation that sells the sandstorm.
-- Suppressing precipitation there would throw away the entire reason for using
-- them, so KillRain is ignored while one of these is the base weather.
local SNOW_BASE = { BLIZZARD = true, SNOW = true, SNOWLIGHT = true, XMAS = true }

local function killRainWanted()
    if not BO.KillRain then return false end
    local base = (BO.BaseWeather or ''):upper()
    return not SNOW_BASE[base]
end

local function pushBaseWeather()
    local base = BO.BaseWeather
    if not base or base == '' then return end

    -- Preferred route: vl_dynamicweather's own setLocalWeather, which it treats
    -- as a sanctioned deviation so its self-heal leaves us alone.
    local ok = pcall(function() exports[BO.WeatherResource]:setLocalWeather(base) end)

    -- Fallback: set it with the natives directly.
    --
    -- Worth having because the export above is wrapped in a pcall and
    -- vl_dynamicweather is escrowed -- if that export does not exist, the call
    -- fails silently and BO.BaseWeather never takes effect at all, which looks
    -- exactly like "the weather setting does nothing".
    --
    -- The trade: this deviates without telling vl_dynamicweather, so its self-
    -- heal may pull the weather back on its next tick. Set BO.ForceWeather to
    -- false if you see the weather flickering between two types.
    if BO.ForceWeather then
        pcall(SetWeatherTypeNowPersist, base)
        pcall(SetWeatherTypePersist, base)
        pcall(SetOverrideWeather, base)
    elseif not ok then
        log(('setLocalWeather failed and BO.ForceWeather is off - %s was never applied'):format(base))
    end
end

local function popBaseWeather()
    if not BO.BaseWeather or BO.BaseWeather == '' then return end
    pcall(function() exports[BO.WeatherResource]:clearLocalWeather() end)
end

local function pushSky()
    pushBaseWeather()
    if killRainWanted() then
        if SetRain then pcall(SetRain, 0.0) end
        if SetRainLevel then pcall(SetRainLevel, 0.0) end
    end
    if BO.CloudHat and BO.CloudHat ~= '' then
        pcall(SetCloudHatTransition, BO.CloudHat, 0.0)
        if SetCloudHatOpacity then pcall(SetCloudHatOpacity, BO.CloudOpacity or 0.5) end
    end
    if BO.WindSpeed then
        SetWind(BO.WindSpeed)
        SetWindSpeed(BO.WindSpeed)
    end
end

local function popSky()
    popBaseWeather()
    if BO.CloudHat and BO.CloudHat ~= '' then
        pcall(ClearCloudHat)
        if SetCloudHatOpacity then pcall(SetCloudHatOpacity, 1.0) end
    end
end

-- ─── screen layer ───────────────────────────────────────────────────────────
-- Timecycle grading does the real work; this is the guaranteed floor so the
-- blood cast survives low graphics settings and interiors.
local tintR, tintG, tintB = table.unpack(BO.ScreenTintColor or { 190, 45, 8 })
-- VoidLine: lowered 8 -> 4 on 2026-08-31 -- resmon flagged this resource as
-- high-cost. This loop runs at Wait(0) (every frame, unavoidable for DrawRect
-- to persist) while the preset is active, and each vignette step issues 4
-- DrawRect calls (top/bottom/left/right) -- 8 steps meant up to 32 draw calls
-- every single frame. Halving the steps halves that to ~16, still a soft
-- multi-band gradient, just slightly coarser.
local VIGNETTE_STEPS = 4
local VIGNETTE_DEPTH = 0.22

CreateThread(function()
    while true do
        -- Read live so /botint takes effect without a restart.
        local tint     = BO.ScreenTint or 0.0
        local vignette = BO.ScreenVignette or 0.0

        if active and not IsPauseMenuActive() and (tint > 0.0 or vignette > 0.0)
            and GetInteriorFromEntity(PlayerPedId()) == 0 then
            if tint > 0.0 then
                DrawRect(0.5, 0.5, 1.0, 1.0, tintR, tintG, tintB, math.floor(tint * 255))
            end
            if vignette > 0.0 then
                -- Soft edge burn: stacked slivers with falling alpha, so the
                -- frame fades into the haze instead of showing hard bars.
                for i = 1, VIGNETTE_STEPS do
                    local a = math.floor(vignette * 255 * (1.0 - (i - 1) / VIGNETTE_STEPS) / VIGNETTE_STEPS * 2.0)
                    if a > 0 then
                        local h = VIGNETTE_DEPTH / VIGNETTE_STEPS
                        local o = (i - 0.5) * h
                        DrawRect(0.5, o, 1.0, h, 34, 5, 0, a)
                        DrawRect(0.5, 1.0 - o, 1.0, h, 34, 5, 0, a)
                        DrawRect(o * 0.75, 0.5, h * 0.75, 1.0, 34, 5, 0, a)
                        DrawRect(1.0 - o * 0.75, 0.5, h * 0.75, 1.0, 34, 5, 0, a)
                    end
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- ─── activate / deactivate ──────────────────────────────────────────────────
local function activate()
    if active then return end
    active = true
    buildModifier()
    lastHour = -1
    applyHour(GetClockHours(), true)
    pushModifier()
    pushSky()
    log('ACTIVE')
    TriggerEvent('bloodorange:onStateChange', true)
end

local function deactivate()
    if not active then return end
    active = false
    popModifier()
    popSky()
    dust().stop()
    log('inactive')
    TriggerEvent('bloodorange:onStateChange', false)
end

-- Self-heal: interiors, cutscenes and other resources clear timecycle
-- modifiers; put ours straight back while the weather says so.
--
-- VoidLine: the preset used to self-heal unconditionally, including while the
-- player was inside an MLO/building interior. It runs in the EXTRA timecycle
-- slot specifically because that slot survives what interiors normally clear,
-- so the orange fog/tint stayed fully visible indoors -- e.g. standing inside
-- a shop looking as hazy as the street outside. Gated behind an interior
-- check 2026-08-30: pop the modifier (clear it) while inside, and let the
-- self-heal push it back the moment the player steps back out.
local wasInInterior = false
CreateThread(function()
    local interval = BO.HealInterval or 500
    local ticks = 0
    while true do
        if active then
            local inInterior = GetInteriorFromEntity(PlayerPedId()) ~= 0

            if inInterior then
                if not wasInInterior then
                    popModifier()
                    wasInInterior = true
                end
            else
                if wasInInterior then
                    wasInInterior = false
                end
                pushModifier()
                if killRainWanted() and SetRain then pcall(SetRain, 0.0) end
                if BO.WindSpeed then
                    SetWind(BO.WindSpeed)
                    SetWindSpeed(BO.WindSpeed)
                end
            end

            -- Re-assert the foggy base every ~5 s: a zone change or a panel
            -- edit can drop the local override without changing our weather.
            -- The dust ring is rebuilt on ped change / culled handles. Wrapped:
            -- a ptfx error must never take the self-heal loop down with it.
            -- dust().tick() already skips interiors on its own (BO.DustSkipInteriors).
            local okDust, dustErr = pcall(dust().tick)
            if not okDust then log('dust tick error:', dustErr) end

            ticks = ticks + 1
            if ticks * interval >= 5000 then
                ticks = 0
                if not inInterior then pushBaseWeather() end
            end
        end
        Wait(interval)
    end
end)

-- ─── weather tracking ───────────────────────────────────────────────────────
-- Source of truth is the AREA weather, never getWeather(). Once the preset is
-- live it puts this client on the foggy base weather, so getWeather() would
-- report FOGGY and we would immediately switch ourselves back off. getWeatherAt
-- reads the zone's synced value, which the local override does not touch.
local function syncedWeather()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local ok, w = pcall(function()
        return exports[BO.WeatherResource]:getWeatherAt(c.x, c.y)
    end)
    if ok and type(w) == 'string' and w ~= '' then return w end

    -- No area resolved (zone gap, resource restarting): fall back to the plain
    -- local value, but only while we are not the ones overriding it.
    if not active then
        local ok2, w2 = pcall(function() return exports[BO.WeatherResource]:getWeather() end)
        if ok2 and type(w2) == 'string' and w2 ~= '' then return w2 end
    end
    return nil
end

local function evaluate()
    local w = syncedWeather()
    if not w then return end
    if w:upper() == TRIGGER then activate() else deactivate() end
end

-- vl_dynamicweather fires this whenever the weather applied to this client
-- changes. The payload is ignored on purpose -- it can be our own base-weather
-- override echoing back -- so it is used purely as a "something moved" ping.
AddEventHandler('cdw:onWeatherChange', function() evaluate() end)

-- Poll as a safety net: covers first spawn, zone crossings, resource restarts
-- on either side, and any path that does not emit the event.
CreateThread(function()
    while true do
        evaluate()
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        deactivate()
        if built and RemoveTimecycleModifier then pcall(RemoveTimecycleModifier, NAME) end
    end
end)

-- ─── introspection ──────────────────────────────────────────────────────────
-- Prints the timecycle variable names this build actually knows, filtered.
-- Always registered (read-only, no gameplay effect) because guessing at var
-- names from memory is exactly how the fog ended up not working.
--   /bovars fog      -> every fog variable this build supports
--   /bovars          -> the full dictionary, in chunks
-- /bovardump -- writes this build's full timecycle variable dictionary to
-- vl_bloodorange/timecycle_vars.txt on the SERVER.
--
-- Exists because /bovars prints to the F8 client console, which is awkward to
-- read back and easy to run in the wrong window. A file can just be opened.
RegisterCommand('bovardump', function()
    local index = buildVarIndex()
    local names = {}
    for name in pairs(index) do names[#names + 1] = name end
    table.sort(names)

    if #names == 0 then
        print('[bloodorange] this build exposes no timecycle var dictionary - nothing to dump')
        return
    end

    TriggerServerEvent('vl_bloodorange:dumpVars', names)
    print(('[bloodorange] sent %d var names to the server -> vl_bloodorange/timecycle_vars.txt'):format(#names))
end, false)

RegisterCommand('bovars', function(_, args)
    local filter = (args[1] or ''):lower()
    local index  = buildVarIndex()
    if next(index) == nil then
        print('[bloodorange] this build exposes no timecycle var dictionary')
        return
    end

    local names = {}
    for name in pairs(index) do
        if filter == '' or name:find(filter, 1, true) then names[#names + 1] = name end
    end
    table.sort(names)

    print(('[bloodorange] %d timecycle vars matching "%s":'):format(#names, filter))
    local line = {}
    for i = 1, #names do
        line[#line + 1] = names[i]
        if #line == 4 or i == #names then
            print('  ' .. table.concat(line, '  '))
            line = {}
        end
    end
end, false)

-- What the dust wall is actually doing right now.
RegisterCommand('bodustdbg', function()
    print(('[bloodorange] active=%s  dust=%s  emitters live=%d  fx=%s/%s')
        :format(tostring(active), tostring(BO.Dust), dust().count(),
                tostring(BO.DustDict), tostring(BO.DustEffect)))
    print(('  spacing=%.1f field=%.0f max=%d scale=%.1f alpha=%.2f  interior=%d')
        :format(BO.DustSpacing or -1, BO.DustFieldRadius or -1, BO.DustMaxEmitters or -1,
                BO.DustScale or -1, BO.DustAlpha or -1, GetInteriorFromEntity(PlayerPedId())))
end, false)

-- ─── live tuning (BO.Debug only) ────────────────────────────────────────────
-- Dial the look in without restarting the resource. Client-side and local-only,
-- so they are gated behind BO.Debug -- otherwise any player could type /bovis 500
-- and see straight through the dust storm.
if BO.Debug then
    RegisterCommand('bovis', function(_, args)
        BO.VisibilityMeters = tonumber(args[1]) or BO.VisibilityMeters
        applyAtmosphere()
        print(('[bloodorange] visibility -> %.1f m'):format(BO.VisibilityMeters))
    end, false)

    RegisterCommand('boexp', function(_, args)
        BO.Exposure = tonumber(args[1]) or BO.Exposure
        applyHour(GetClockHours(), true)
        print(('[bloodorange] exposure -> %.2f EV'):format(BO.Exposure))
    end, false)

    RegisterCommand('bodust', function(_, args)
        BO.DustSpacing = tonumber(args[1]) or BO.DustSpacing
        BO.DustAlpha   = tonumber(args[2]) or BO.DustAlpha
        BO.DustScale   = tonumber(args[3]) or BO.DustScale
        dust().refresh()
        print(('[bloodorange] dust spacing %.1f m  alpha %.2f  scale %.1f  (%d live)')
            :format(BO.DustSpacing, BO.DustAlpha, BO.DustScale, dust().count()))
    end, false)

    RegisterCommand('bodustmax', function(_, args)
        BO.DustMaxEmitters = tonumber(args[1]) or BO.DustMaxEmitters
        BO.DustFieldRadius = tonumber(args[2]) or BO.DustFieldRadius
        dust().refresh()
        print(('[bloodorange] max emitters %d  field radius %.0f m')
            :format(BO.DustMaxEmitters, BO.DustFieldRadius))
    end, false)

    RegisterCommand('bodustfx', function(_, args)
        if args[1] and args[2] then
            BO.DustDict, BO.DustEffect = args[1], args[2]
            dust().stop()
            dust().refresh()
            print(('[bloodorange] dust fx -> %s / %s (%d live)')
                :format(BO.DustDict, BO.DustEffect, dust().count()))
        else
            print('[bloodorange] usage: /bodustfx <dict> <effect>')
        end
    end, false)

    RegisterCommand('bobase', function(_, args)
        local base = (args[1] or ''):upper()
        if base == 'OFF' or base == 'NONE' then base = '' end
        popBaseWeather()
        BO.BaseWeather = base
        if active then pushBaseWeather() end
        print(('[bloodorange] base weather -> %s'):format(base == '' and '(none)' or base))
    end, false)

    RegisterCommand('bowind', function(_, args)
        BO.WindSpeed = tonumber(args[1]) or BO.WindSpeed
        SetWind(BO.WindSpeed)
        SetWindSpeed(BO.WindSpeed)
        print(('[bloodorange] wind -> %.2f'):format(BO.WindSpeed))
    end, false)

    RegisterCommand('bohaze', function(_, args)
        BO.HazeBrightness = tonumber(args[1]) or BO.HazeBrightness
        applyAtmosphere()
        print(('[bloodorange] haze brightness -> %.2f'):format(BO.HazeBrightness))
    end, false)

    RegisterCommand('bohazecol', function(_, args)
        local r, g, b = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
        if r and g and b then
            BO.HazeColor = { r, g, b }
            applyAtmosphere()
            print(('[bloodorange] haze colour -> %.3f %.3f %.3f'):format(r, g, b))
        else
            print('[bloodorange] usage: /bohazecol <r> <g> <b>   (linear 0.0-1.0)')
        end
    end, false)

    RegisterCommand('botint', function(_, args)
        BO.ScreenTint = tonumber(args[1]) or BO.ScreenTint
        print(('[bloodorange] screen tint -> %.2f'):format(BO.ScreenTint))
    end, false)
end

-- ─── exports ────────────────────────────────────────────────────────────────
exports('isActive', function() return active end)
exports('getPresetName', function() return NAME end)

-- Force the look on/off for THIS client only (cutscenes, missions), ignoring
-- the synced weather until the next weather change re-evaluates it.
exports('setLocal', function(state)
    if state then activate() else deactivate() end
end)
