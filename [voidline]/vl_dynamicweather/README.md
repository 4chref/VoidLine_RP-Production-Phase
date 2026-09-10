# Dynamic Weather & Time

A premium dynamic weather + time admin panel for FiveM. Control server weather and time from a stylised Los Santos map — set a single static weather, or build per‑zone dynamic forecast schedules that change automatically over time.

- **Two layers** – 4 preset city regions + admin‑drawn custom zones (zones win on overlap).
- **Static or Dynamic** per area – one fixed weather, or a timed forecast schedule you can reorder.
- **On‑map zone editor** – freehand draw or drop a resizable box, curve edges, drag/insert points, pick any colour, rename and delete.
- **Change weather for all** – one click sets every city (or every zone) to a static weather.
- **Animated map** – per‑zone weather icons and flowing wind ribbons (decorative).
- **Your units** – Celsius/Fahrenheit and 12h/24h clock, each a one‑line config switch.
- **Developer API** – exports to read weather/time, drive it (temporary overrides + per‑client local weather), and open the panel from another resource.
- **JSON or MySQL** persistence (auto‑fallback to JSON if oxmysql is missing).
- **Localization** – English + Turkish included, fully editable, add your own language.
- **Standalone & safe** – fail‑closed permissions (ACE / allowlist / your own hook), server‑side validation, conflicting‑script detection, no framework.

---

## Requirements

- FiveM server (game build 3258+ recommended).
- **oxmysql** – *optional*, only if you set `Config.Storage = 'sql'`. Must start **before** this resource.

## Installation

1. Drop the `codem-dynamicweather` folder into your server `resources` directory.
2. Add to your `server.cfg`:
   ```cfg
   ensure codem-dynamicweather
   ```
   If you use SQL storage, make sure `oxmysql` is `ensure`d **before** this line.
3. Grant the admin permission — **one line in `server.cfg`**, see below.
4. Restart the server. You should see in the console:
   ```
   [codem-dynamicweather] Aiakos — Dynamic Weather v1.0.0 | ready: 4 areas (JSON)
   ```

## Permission

> ⚠️ **Add one line to your `server.cfg`.** Without it nobody can open the panel — the
> check is fail‑closed on purpose.

```cfg
add_ace group.admin dynamicweather.admin allow     # txAdmin / qbx_core / ESX
add_ace qbcore.admin dynamicweather.admin allow    # qb-core
```

Access is controlled by a **dedicated ACE object** (`Config.AcePermission`, default
`dynamicweather.admin`). The `command.<Config.Command>` ACE is deliberately **never** used:
a single broad line such as `add_ace group.user command allow` hands every `command.*` ace —
including ours — to every player in that group, and which groups exist on your server cannot
be enumerated from a resource. On start we check `builtin.everyone`, `group.user` and
`group.default` and print a red **SECURITY** warning if one of them somehow holds the panel
ace.

The same check gates **every** action, not just opening the panel — setting weather,
drawing zones, editing forecasts. It is always evaluated server‑side.

### Ways to grant access

A player is allowed if **any** of these says yes; otherwise access is denied.

| Layer | Option | Notes |
|---|---|---|
| Identifier allowlist | `Config.Admins` | `{ 'license:1a2b…', 'fivem:1234567' }` — no `server.cfg` edit needed |
| Dedicated ACE | `Config.AcePermission` | The line above. Works on txAdmin, qbx_core, ESX and qb-core |
| qb-core shortcut | `Config.FrameworkPermission` | Accepts qb-core's own `admin` / `god` permissions with zero setup |
| Custom hook | `Config.CanOpenPanel` | `function(src) return true/false end`. Errors are treated as **deny** |

Need something else? **`server/permissions.lua` ships unencrypted** — edit it directly.

<details>
<summary>ESX example (<code>Config.CanOpenPanel</code>)</summary>

```lua
Config.CanOpenPanel = function(src)
    local ESX = exports['es_extended']:getSharedObject()
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer ~= nil and xPlayer.getGroup() == 'admin'
end
```
</details>

Open the panel in‑game with:

```
/weatherpanel
```

(The command name is configurable — see `Config.Command`.)

---

## Using the panel

The panel has two sides: the **map** (left) and the **area list** (right).

**Forecast tab** (default) — the map shows each area's current weather icon. Toggle **Zone Base / City Wide** (bottom‑left) to choose which layer you manage; the animated wind ribbons are drawn on the **City Wide** layer. With nothing selected, the list shows every area and a **Change Static Weather For All** button (bottom) sets them all to one static weather at once.

**Zone Editor tab** — build custom zones with the toolbar (each tool has a hover tooltip). The **ⓘ** button (top‑right of the map) opens a help bubble listing these same steps.

- **Draw** – click to place corner points freehand.
- **Box** – click the map for a ready rectangle; drag its corners to resize, drag the centre to move it.
- **Shape** – drag corner points to reposition them, drag the mid‑edge handles to curve an edge, or **double‑click an edge to add a point**.
- **Undo / Redo / Reset / Confirm** – manage the draft; **Confirm** opens the create dialog (name, **colour picker**, weather, temperature).
- **Rename / Change color / Delete** – appear once a zone is selected on the map (Delete asks for confirmation in a pop‑up).
- **Hide** – temporarily hide the existing zones while working.

**Setting weather** — pick an area from the list to open it. Use **Change Static Weather** for a fixed weather, or **Enable Dynamic Weather** to build a timed forecast schedule (add entries, drag to reorder, edit or delete each). Every change broadcasts to all players and is saved automatically.

---

## Configuration (`config/Config.lua`)

| Setting | Default | Description |
|---|---|---|
| `Config.Command` | `'weatherpanel'` | Command that opens the panel. |
| `Config.AcePermission` | `'dynamicweather.admin'` | Dedicated ACE object that grants panel access. See [Permission](#permission). |
| `Config.Admins` | `{}` | Identifier allowlist, e.g. `{ 'license:1a2b…' }`. Bypasses ACE entirely. |
| `Config.FrameworkPermission` | `true` | Also accept qb-core's own permissions (`Config.QbPermissions`) when qb-core is running. |
| `Config.QbPermissions` | `{ 'admin', 'god' }` | qb-core permission names honoured by the option above. |
| `Config.CanOpenPanel` | `nil` | `function(src) return true/false end` — full override. Errors are treated as **deny**. |
| `Config.HandleTime` | `true` | Let this resource control the in‑game clock (the sun / day‑night). Disable other weather/time sync resources to avoid conflicts. |
| `Config.MsPerGameMinute` | `2000` | Real ms per in‑game minute (2000 = full day in ~48 min). Controls the **in‑game sun** only, and the whole day while `UseTimeScale` is off. |
| `Config.UseTimeScale` | `false` | Turn on per‑range clock speeds so **day and night can last different amounts of real time**. See [Uneven day/night](#uneven-daynight-length). |
| `Config.TimeScale` | day/night example | The ranges and their speeds. Only read when `UseTimeScale = true`. |
| `Config.ForecastRealTime` | `true` | Trigger dynamic forecasts on the **server machine's real clock** and show that time in the panel (so "rain at 13:00" fires at machine 13:00). The in‑game sun above is unaffected. `false` = use the in‑game clock. |
| `Config.TimeZoneOffset` | `0` | Hours added to the server machine clock for the panel/forecast (only when `ForecastRealTime`). Use if the machine's timezone differs from your team's (e.g. machine UTC, team UTC+3 → `3`). Fixed offset, no DST. |
| `Config.Storage` | `'json'` | `'json'` (file, zero‑setup) or `'sql'` (MySQL via oxmysql). |
| `Config.SqlTable` | `'codem_dynamicweather'` | Table name for SQL storage (auto‑created). |
| `Config.Locale` | `'en'` | Language code — see Localization. |
| `Config.TimeFormat` | `'24'` | Clock display in the panel: `'24'` (20:00) or `'12'` (8:00 PM, with AM/PM shown next to the time inputs too). Any other value falls back to `'24'`. |
| `Config.TempUnit` | `'C'` | Temperature unit shown/entered in the panel: `'C'` (20°C) or `'F'` (68°F). Stored internally in Celsius. |
| `Config.Debug` | `false` | Print storage read/write + loaded data to the console (for setup/testing). |
| `Config.ConflictResources` | list | Known weather/time sync resources (qb-weathersync, Renewed-Weathersync, …). If any is running, a console warning is printed on start so you can stop it. Warns only — never disables anything. |

> **Only run one weather/time controller.** This resource drives the weather and clock via game natives every tick; any other weather/time sync running alongside it will fight over the same natives (flicker). Stop the other one — the console warning lists which was detected.

The weather blend time (`Config.TransitionTime`, default `15.0` seconds), the start weather (`Config.StartWeather`, default `'CLEAR'`) and the clock the server starts on (`Config.StartHour` / `Config.StartMinute`, default `8:00`) also live in `config/Config.lua`. The 15 valid weather types are fixed by GTA V and are not configurable.

### Uneven day/night length

By default the clock runs at one speed all day (`Config.MsPerGameMinute`), so daytime
and night take the same amount of real time. Flip `Config.UseTimeScale` to `true` and
each range in `Config.TimeScale` gets its own speed — for example a short day and a
long night:

```lua
Config.UseTimeScale = true

-- Daytime (05:00-21:00) passes in 1 real hour, night (21:00-05:00) takes 3 real
-- hours -> a full in-game day is 4 real hours.
Config.TimeScale = {
    { from = 5,  to = 21, msPerMinute = 3750  }, -- 16 in-game hours in 60 real min
    { from = 21, to = 5,  msPerMinute = 22500 }, -- 8 in-game hours in 180 real min
}
```

- `from` / `to` are in‑game hours (`0`–`24`), fractions allowed (`5.5` = 05:30). A range
  may wrap past midnight (`from = 21, to = 5`).
- `msPerMinute` is the real milliseconds one in‑game minute takes inside that range:
  **`(real minutes you want) * 60000 / (in-game hours covered * 60)`**.
- Hours no entry covers fall back to `Config.MsPerGameMinute`, so you can define only
  the night and leave the rest alone. Overlapping ranges are allowed — the later entry
  wins for the shared hours.
- On startup the server prints the resulting pace (per range and the full‑day total), and
  invalid entries are reported and skipped instead of breaking the clock.

Set `Config.UseTimeScale = false` (the default) for the classic single‑speed behaviour —
the table below it is then ignored, so you can leave your ranges in place while it is off.
This affects the in‑game sun only; the panel/forecast clock follows `Config.ForecastRealTime`
as before.

### City regions & map labels — `config/Cities.lua`

The 4 preset city outlines, colours and **map label positions** are defined here. To nudge a city's map label, edit its `labelOffset` (`x+` = right/east, `y+` = up/north):

```lua
name = "GREAT CHAPARRAL",
labelColor = "#3a4700",
labelOffset = { x = 500, y = 550 },  -- edit this
```

Config files are **not** escrow‑encrypted, so you can edit them freely.

---

## Storage: JSON vs SQL

- **JSON (default):** zones + per‑city weather state are saved to `data/zones.json`. No database required.
- **SQL:** set `Config.Storage = 'sql'`. The resource stores the same data as a single JSON row in the `Config.SqlTable` table (auto‑created via `CREATE TABLE IF NOT EXISTS`; a reference schema is in `sql/`). Requires **oxmysql** started before this resource. If oxmysql isn't running, it automatically falls back to JSON and prints a warning.

Both modes are debounced (batched writes) and survive server restarts. Enable `Config.Debug` to confirm which backend is active.

---

## Localization

All player/admin‑facing text lives in `locale/*.lua` (English + Turkish included) and is **not** escrow‑encrypted, so you can translate or reword everything.

- Change language: set `Config.Locale = 'tr'` (or any code you added).
- Add a language:
  1. Copy `locale/en.lua` → `locale/de.lua`.
  2. Change the single line `Locales['en']` → `Locales['de']` and translate the values.
  3. Add the file to `fxmanifest.lua` `shared_scripts` **before** `locale/locale.lua`.
  4. Set `Config.Locale = 'de'` and restart.

Missing keys automatically fall back to English. Console/log messages are always English.

---

## Developer API (exports)

Other resources can read live weather/time and drive it. Weather is **zone-based**
(resolved per player position), so **client** exports return the *local* player's reality,
while **server** exports work with areas and coordinates.

**Writes are temporary overrides:** they apply on top of the admin's panel setup without
saving. Clearing the override (or a server restart) returns players to the admin
configuration — the base setup is never modified. Invalid input is rejected (writes return `false`).

### Client — local player

```lua
-- Read
local weather = exports['codem-dynamicweather']:getWeather()       -- e.g. "RAIN"
local temp    = exports['codem-dynamicweather']:getTemperature()   -- °C number (or nil)
local time    = exports['codem-dynamicweather']:getTime()          -- in-game (sun) clock { hour, minute }
local rtime   = exports['codem-dynamicweather']:getRealTime()      -- panel/forecast clock { hour, minute }
local area    = exports['codem-dynamicweather']:getCurrentArea()   -- { id, name, kind, dynamic } or nil
local wAt     = exports['codem-dynamicweather']:getWeatherAt(x, y) -- weather at coords or nil

-- Local override — force weather for THIS client only (missions / effects).
-- Overrides the area weather and stays enforced until cleared; then the client
-- returns to its area weather. Does not affect other players or the server.
exports['codem-dynamicweather']:setLocalWeather('THUNDER', 14)     -- temperature optional
exports['codem-dynamicweather']:clearLocalWeather()

-- Local time — FREEZE the clock for THIS client only (interiors / missions).
-- The server clock keeps running for everyone else; clearing returns this client
-- to the current server time (no drift, no catching up).
exports['codem-dynamicweather']:setLocalTime(7, 10)                -- freeze at 07:10 (minute optional)
exports['codem-dynamicweather']:setLocalTime()                     -- freeze at the current server time
exports['codem-dynamicweather']:clearLocalTime()

-- Open the admin panel for the local player (same permission check as /weatherpanel).
exports['codem-dynamicweather']:openPanel()
-- …or trigger it as an event (e.g. from another resource):
TriggerEvent('codem-dynamicweather:openPanel')
```

> Normal (server) weather flows through the state and is kept in sync for everyone in
> an area (self-healing — external one-off weather changes are corrected within ~2s).
> `setLocalWeather` is the sanctioned way to deviate a single client without that
> correction fighting you.

Event — fires when the local player's applied weather changes (great for HUDs):

```lua
AddEventHandler('cdw:onWeatherChange', function(weather)
    -- weather is now `weather`
end)
```

### Server (read + write)

```lua
-- Read
local time  = exports['codem-dynamicweather']:getTime()          -- in-game (sun) clock { hour, minute }
local rtime = exports['codem-dynamicweather']:getRealTime()      -- panel/forecast clock { hour, minute }
local areas = exports['codem-dynamicweather']:getAreas()         -- { { id, name, kind, weather, temperature, dynamic }, ... }
local wAt   = exports['codem-dynamicweather']:getWeatherAt(x, y) -- weather at coords or nil

-- Write (temporary override)
exports['codem-dynamicweather']:setTime(20, 30)                    -- set the IN-GAME (sun) clock to 20:30
exports['codem-dynamicweather']:freezeTime(true)                  -- pause the IN-GAME clock (false to resume)

exports['codem-dynamicweather']:setGlobalWeather('THUNDER', 9)     -- force one weather everywhere (temperature optional)
exports['codem-dynamicweather']:setAreaWeather(areaId, 'RAIN', 14) -- one area (temperature optional)
exports['codem-dynamicweather']:clearWeatherOverride()            -- back to admin setup

exports['codem-dynamicweather']:clearOverride()                  -- clear everything (weather + unfreeze)

-- Open the admin panel for a player (same permission check as /weatherpanel).
exports['codem-dynamicweather']:openPanel(playerId)
-- …or trigger it as an event:
TriggerEvent('codem-dynamicweather:openPanel', playerId)
```

Weather values are the 15 GTA V types: `EXTRASUNNY` `CLEAR` `NEUTRAL` `SMOG` `FOGGY` `CLOUDS` `OVERCAST` `CLEARING` `RAIN` `THUNDER` `SNOWLIGHT` `SNOW` `BLIZZARD` `XMAS` `HALLOWEEN`.

> **Two clocks:** with `Config.ForecastRealTime = true`, dynamic forecasts and the panel run on
> the server's real clock — use `getRealTime()` for that. `getTime` / `setTime` / `freezeTime`
> control only the **in-game sun** (day/night), which is independent and does not move the forecasts.

---

## Notes for resellers / packaging

- Only the built UI (`html/`) ships and is loaded (`ui_page` + `files`). The `html/` folder is a **build output** — do not edit it by hand.
- When zipping for distribution, include only the runtime files (`fxmanifest.lua`, `config/`, `shared/`, `locale/`, `server/`, `client/`, `html/`, `data/`, `sql/`, this README). Do **not** include the `web/` source folder or `node_modules/`.
- `escrow_ignore` keeps `config/*.lua`, `locale/*.lua` and `server/permissions.lua` editable after CFX escrow encryption. Everything else (`client/`, the rest of `server/`) is encrypted.

---

## Credits

Author: **Aiakos** · v1.0.0
