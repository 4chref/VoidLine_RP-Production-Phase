Config = {}

-- ════════════════════════════════════════
-- GENERAL
-- ════════════════════════════════════════

-- Command that opens the admin panel.
Config.Command = 'weatherpanel'

-- ════════════════════════════════════════
-- PERMISSION
-- ════════════════════════════════════════
-- A player may open the panel (and change anything) if ANY of the layers below allows it.
-- If none does, access is DENIED. Everything is checked server-side on every action.
--
-- Edit server/permissions.lua directly if you need something these options cannot express;
-- that file ships unencrypted on purpose.

-- Dedicated ACE object. Unlike `command.<Command>`, it can never be granted by accident
-- through a broad `command` wildcard. Add ONE line to your server.cfg:
--
--   add_ace group.admin dynamicweather.admin allow     # txAdmin / qbx_core / ESX
--   add_ace qbcore.admin dynamicweather.admin allow    # qb-core
--
-- (ESX puts every player into `group.<their group>`; qbx_core uses cfg ACEs; both work.)
Config.AcePermission = 'dynamicweather.admin'

-- Direct allowlist — works without touching server.cfg. Any identifier type.
-- Example: { 'license:1a2b3c...', 'fivem:1234567', 'steam:110000112345678' }
Config.Admins = {}

-- Zero-setup shortcut for qb-core: it registers `add_ace qbcore.<perm> <perm> allow`
-- and puts admins into the `qbcore.<perm>` principal, so its own ACE objects work.
-- Only consulted while qb-core is actually running.
Config.FrameworkPermission = true
Config.QbPermissions = { 'admin', 'god' }

-- Full override. Return true to allow, false to deny. Runtime errors are treated as DENY.
--   Config.CanOpenPanel = function(src) return IsPlayerAceAllowed(src, 'admin') end
--
--   -- ESX example:
--   Config.CanOpenPanel = function(src)
--       local ESX = exports['es_extended']:getSharedObject()
--       local xPlayer = ESX.GetPlayerFromId(src)
--       return xPlayer ~= nil and xPlayer.getGroup() == 'admin'
--   end
Config.CanOpenPanel = nil

-- Weather transition time in seconds (smooth blend via SetWeatherTypeOvertimePersist).
-- Used when transitioning INTO a wet weather (RAIN/THUNDER) so rain starts naturally/slowly.
Config.TransitionTime = 15.0

-- Transition time in seconds when moving INTO a dry weather (everything except RAIN/THUNDER).
-- Kept SHORTER than TransitionTime so the sky clears smoothly AND the wet roads/puddles from
-- previous rain dry together in about this many seconds (GTA couples ground wetness to the
-- weather, so roads cannot dry before the sky clears). Lower = faster dry, higher = slower.
Config.DryTransitionTime = 15.0

-- Language. Uses the Locales['<code>'] table from locale/<code>.lua.
-- Default 'en'. To add a language: copy locale/en.lua, translate it, add the file
-- to fxmanifest shared_scripts, then change this value.
Config.Locale = 'en'

-- Clock display format in the panel. Anything other than '12' falls back to '24'.
--   '12' -> 12-hour with AM/PM (e.g. 8:00 PM; AM/PM is also shown on the time inputs)
--   '24' -> 24-hour / European (e.g. 20:00)
Config.TimeFormat = '24'

-- Temperature unit shown/entered in the panel. Values are stored internally in Celsius;
-- this only changes how they are displayed and typed in the panel:
--   'C' -> Celsius (e.g. 20°C)
--   'F' -> Fahrenheit (e.g. 68°F)
Config.TempUnit = 'C'

-- ════════════════════════════════════════
-- THEME (panel accent color)
-- ════════════════════════════════════════
-- The accent color used across the WHOLE panel: buttons, highlights, active tabs,
-- focus rings, info banners and the zone-drawing color on the map.
--
-- Set EITHER a preset name from Config.ThemePresets below, OR any custom hex.
--   Config.Theme = 'Blue'        -- a preset name (case-insensitive)
--   Config.Theme = '#8A2BE2'     -- any custom hex ('#RGB' or '#RRGGBB', the # is optional)
-- If the value is invalid, the panel falls back to the default red.
Config.Theme = 'purple'

-- Named color presets. Add/rename freely; the value must be a hex string.
Config.ThemePresets = {
    White  = '#FFFFFF',
    Green  = '#55FF74',
    Blue   = '#55E6FF',
    Yellow = '#E8FF55',
    Orange = '#FF9655',
    Purple = '#AD55FF',
    Pink   = '#FF55C4',
    Red    = '#FF5558',
    Cyan   = '#8AF4BD',
}

-- ════════════════════════════════════════
-- PERSISTENCE
-- ════════════════════════════════════════

-- Where zones and per-city weather state are stored:
--   'json' -> data/zones.json inside the resource (default, no setup required)
--   'sql'  -> MySQL (requires oxmysql; the table is created automatically)
-- If 'sql' is set but oxmysql is not running, it automatically falls back to 'json'.
-- oxmysql must start BEFORE this resource.
Config.Storage = 'json'

-- Table name used in SQL mode (stores a single JSON blob row).
Config.SqlTable = 'codem_dynamicweather'

-- Debug: print storage reads/writes, loaded data and key events to the console.
-- Turn on while installing/troubleshooting; keep false in production.
Config.Debug = false

-- ════════════════════════════════════════
-- TIME
-- ════════════════════════════════════════

-- If true, this resource controls the in-game clock. Disable any other
-- weather/time sync resource (default qbx sync, Renewed-Weathersync, etc.)
-- or they will conflict.
Config.HandleTime = true

-- Real milliseconds per in-game minute. 2000 = a full day in ~48 minutes.
-- This is the speed for the WHOLE day while Config.UseTimeScale below is false.
Config.MsPerGameMinute = 2000

-- UNEVEN DAY/NIGHT — on/off switch for the Config.TimeScale table below.
--   false -> one flat speed all day (Config.MsPerGameMinute above). Default.
--   true  -> each range in Config.TimeScale runs at its own speed, so day and
--            night do NOT have to last the same amount of real time.
Config.UseTimeScale = true

-- Clock speed per part of the day. Only read when Config.UseTimeScale = true.
--
--   from / to    In-game hours, 0-24. Fractions allowed (5.5 = 05:30). A range
--                may wrap past midnight: { from = 21, to = 5 } is valid.
--   msPerMinute  Real milliseconds for one in-game minute inside that range.
--
-- Pick msPerMinute with:  (real minutes you want) * 60000 / (in-game hours * 60)
--
-- The example below: daytime (05:00-21:00) passes in 1 real hour while night
-- (21:00-05:00) takes 3 real hours -> a full in-game day is 4 real hours.
-- Hours no range covers fall back to MsPerGameMinute, so you may define only the
-- night. Overlapping ranges are allowed (the later one wins). With the switch on,
-- the server prints the resulting pace on startup.
Config.TimeScale = {
    { from = 5,  to = 21, msPerMinute = 3750  }, -- 16 in-game hours in 60 real min
    { from = 21, to = 5,  msPerMinute = 22500 }, -- 8 in-game hours in 180 real min
}

-- Clock when the resource first starts.
Config.StartHour = 8
Config.StartMinute = 0

-- Dynamic FORECAST scheduling clock. This is SEPARATE from the in-game sun above.
--   true  -> forecasts trigger on the SERVER MACHINE's real clock, and the panel
--            shows that machine time. So "rain at 13:00" happens when the server's
--            wall clock hits 13:00 (not when the in-game sun reaches 13:00). The
--            in-game day/night cycle above is unaffected.
--   false -> forecasts + panel use the in-game clock (StartHour/MsPerGameMinute).
Config.ForecastRealTime = true

-- Hours to add to the server machine clock for the panel display + forecast times
-- (only used when ForecastRealTime = true). Use this when the server machine's
-- timezone differs from the one you want admins to see/enter. Example: machine is
-- UTC but your team works in UTC+3 -> set 3. Fractional allowed (e.g. 5.5). This is
-- a fixed offset: it does NOT auto-adjust for daylight saving.
Config.TimeZoneOffset = 0

-- Known weather/time sync resources that would fight this one over the weather
-- and clock natives. On startup (and if one starts later) a console warning is
-- printed so you can stop it. Add your own resource names here if needed.
-- This only WARNS — it never stops or disables anything.
Config.ConflictResources = {
    'qb-weathersync',
    'qbx_weathersync',
    'Renewed-Weathersync',
    'cd_easytime',
    'vSync',
    'vSync_reborn',
    'av_weather',
    'weathersync',
}

-- ════════════════════════════════════════
-- WEATHER
-- ════════════════════════════════════════

-- The valid weather types are fixed by GTA V itself, so they are not configurable here.
-- Any of these 15 names can be used below and in the panel:
--   EXTRASUNNY  CLEAR  NEUTRAL  SMOG  FOGGY  CLOUDS  OVERCAST  CLEARING
--   RAIN  THUNDER  SNOWLIGHT  SNOW  BLIZZARD  XMAS  HALLOWEEN
-- To change how a type is spelled in the panel, edit `weather.*` in locale/<lang>.lua.

-- Weather applied to every area when the resource starts (and to new zones).
Config.StartWeather = 'CLEAR'

-- ════════════════════════════════════════
-- TEMPERATURE EFFECTS (client-side visuals)
-- ════════════════════════════════════════
-- Purely visual, per-client, driven by the temperature at the PLAYER'S location
-- (the resolved zone/city temperature, or a setLocalWeather override).

-- Heat haze: GTA's real desert heat shimmer (distorts the 3D scene) when it's hot.
-- Uses the "heathaze" timecycle modifier. It re-applies itself (self-heals after an
-- interior clears the modifier) and is removed once the temperature drops.
-- Set false if another resource fights over the timecycle modifier on your server.
Config.HeatHaze = true
Config.HeatHazeTemp = 35        -- °C at/above which the shimmer appears (stronger the hotter)

-- Cold overlay: a frosty blue screen overlay (drawn by the panel UI layer) when it's
-- freezing. Screen-only — no conflict with anything. Removed once the temperature rises.
Config.ColdOverlay = true
Config.ColdOverlayTemp = -15    -- °C at/below which the frost appears (stronger the colder)

-- ════════════════════════════════════════
-- PERFORMANCE (panel UI)
-- ════════════════════════════════════════
-- The animated "flowing dashes" on the map's wind ribbons repaint every frame while the
-- panel is open. It looks nice but is the heaviest continuous cost in the UI. Set false
-- on weaker machines to make the ribbons static (they still show, just don't flow) —
-- this removes the per-frame repaint and noticeably smooths the panel.
Config.WindRibbonFlow = false
