# basic_needs

A standalone FiveM survival-needs resource with three needs — **Poop**, **Sleep**, **Pee** —
each represented on a polished 4-pill glass HUD. Server-authoritative, configurable, and
framework-agnostic (Qbox support isolated in `bridge/qbox.lua`).

## 1. Installation

1. Copy the `basic_needs` folder into your server's `resources` directory.
2. If you want database persistence, import `sql/install.sql` into your database.
3. Add to your `server.cfg`:
   ```
   ensure oxmysql   # only if Config.UseDatabase = true
   ensure basic_needs
   ```
4. Restart the server / start the resource.

## 2. Configuration

All configuration lives in `config.lua`:

- `Config.Framework` — `'standalone'` or `'qbox'`.
- `Config.UseDatabase` — enable/disable oxmysql persistence.
- `Config.HudPosition` — `'bottom-right'`, `'bottom-left'`, `'top-right'`, `'top-left'`.
- `Config.TickInterval` — how often (ms) the server decays sleep and persists data. Defaults to 60s — never runs per-frame.
- `Config.Warnings` — threshold notifications per need.

## 3. Food integration

Add poop by amount when a player eats, from any resource's **client** script:

```lua
exports['basic_needs']:AddFood(10)
```

Or edit `Config.Food` to define default amounts per item and call `AddFood(Config.Food.burger)`
from your inventory/eating script.

## 4. Drink integration

Same pattern, for pee, from a client script:

```lua
exports['basic_needs']:AddDrink(15)
```

Edit `Config.Drinks` for default amounts per item.

## 5. Toilet setup

Add entries to `Config.Toilets` in `config.lua`:

```lua
Config.Toilets = {
    { coords = vector3(x, y, z), radius = 2.0, type = 'both' } -- 'pee' | 'poop' | 'both'
}
```

Players see `[E] Pee` / `[E] Use Toilet` when in range. Durations and restore amounts are set in
`Config.ToiletSettings`.

## 6. Bed setup

Add entries to `Config.Beds`:

```lua
Config.Beds = {
    { coords = vector3(x, y, z), heading = 0.0 }
}
```

Players see `[E] Sleep` near a bed; sleep restores gradually (`Config.Sleep.bedRestorePerSecond`)
and can be cancelled early with `X`.

## 7. Qbox integration

Set `Config.Framework = 'qbox'`. All Qbox-specific logic (player identifier resolution, load-state
checks) lives in `bridge/qbox.lua` and is not referenced anywhere else in the codebase. No other
files need to change.

## 8. Exports

**Client-side** (call from another client script, no player id required):
```lua
exports['basic_needs']:AddFood(amount)
exports['basic_needs']:AddDrink(amount)
exports['basic_needs']:GetNeeds() -- returns local player's {poop, sleep, pee}
```

**Server-side** (call from another server script, pass the player's server id):
```lua
exports['basic_needs']:AddFood(source, amount)
exports['basic_needs']:AddDrink(source, amount)
exports['basic_needs']:GetNeeds(source)
exports['basic_needs']:GetPoop(source)
exports['basic_needs']:GetSleep(source)
exports['basic_needs']:GetPee(source)
exports['basic_needs']:SetPoop(source, value)
exports['basic_needs']:SetSleep(source, value)
exports['basic_needs']:SetPee(source, value)
```

All server-side setters clamp values between 0 and 100 and trigger the same warning/effect logic
as normal gameplay — client values are never trusted directly.

## 9. Debug commands

Set `Config.Debug = true` in `config.lua`. This enables server commands (console or ACE
`basic_needs.debug`-permitted admins only):

```
/needs
/setpoop 100
/setsleep 100
/setpee 100
```

These commands are completely unregistered when `Config.Debug = false`.

## 10. Customizing the HUD

Edit `web/style.css` for colors, blur, sizing, and animations. Edit `web/index.html` for markup/
icons/labels. Edit `web/app.js` if you need different pill-fill logic. The HUD only receives NUI
messages when a value actually changes, so it's cheap to leave running.

## 11. Changing the 3-minute faint duration

In `config.lua`:
```lua
Config.Sleep = {
    faintDuration = 180000, -- ms
    wakeUpValue = 20        -- sleep value restored to after waking
}
```

## 12. Changing the poop walking effect

In `config.lua`:
```lua
Config.Poop = {
    walkingClipSet = 'move_m@drunk@moderatedrunk'
}
```
Any valid GTA V movement clipset name works. The clipset is requested safely and released on
resource stop, player death, or when poop drops below 100%.

## 13. Changing the pee animation

In `config.lua`:
```lua
Config.PeeAnimation = {
    dict = 'missfam5_yoga@',
    anim = 'idle_a_female',
    fallbackDict = 'amb@world_human_urinate@male@idle_a',
    fallbackAnim = 'idle_c',
    duration = 8000
}
```
If the primary dictionary fails to load within its timeout, the fallback is used automatically —
the animation system never throws if a dictionary is missing.

## Notes on safety/edge cases

- All values are clamped 0–100 server-side; the client never sets need values directly.
- Poop/sleep/pee effects are skipped while the player is dead.
- The forced-pee sequence waits for the player to exit any vehicle before playing (configurable
  via `Config.PeeSettings.waitForVehicleExit`).
- Fainting, forced-pee, and toilet/bed usage all guard against re-triggering while already active.
- All effects (clipsets, anim dicts, screen fade, frozen position, disabled controls) are cleaned
  up on resource stop, so restarting the resource never leaves a player stuck.
