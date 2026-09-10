# VoidLine

Every custom system built for this server, in one portable folder.

Copy `[voidline]` into another Qbox server's `resources/`, add one `ensure` line,
apply the framework patches, and the server is back to this state.

---

## Why this is a category folder, not a single resource

`[voidline]` is a FiveM **category folder** containing eleven independent
resources, rather than one giant resource with a single `fxmanifest.lua`.

That is deliberate:

* `ensure [voidline]` starts all of them — just as portable as one resource.
* Each system can be restarted, disabled or debugged on its own
  (`restart vl_hud` without touching character creation).
* A fault in one system cannot take the others down.
* Client/server/NUI stay separated per system instead of one tangled manifest.

Merging them into a single resource would mean one client script, one server
script and one NUI page for character creation, HUD, weather, drones and world
population all at once — harder to maintain, and a single syntax error would
kill everything.

---

## Contents

| Resource | What it does |
|---|---|
| `vl_loadingscreen` | "THE LAST AGE" loading screen: key art, theme music with mute toggle, typewritten story fragments, real load progress. Replaces the stock `loadscreen` (now in `resources/[disabled]`) |
| `vl_identity` | Character creation: gold-on-black NUI intake (sex + height), unique 3-digit ID with reveal screen, face-only appearance, naked spawn, server-side spawn allocation across 12 points, minimal ID card, starter kit. **The 3-digit range caps the server at 900 characters ever — see `VLConfig.IdMin/IdMax`** |
| `vl_hud` | DayZ-style survival HUD: status icons with bottom-up fill, stamina bar, breath bar while diving, weapon ammo + durability, noise arcs, mic indicator, vehicle dashboard, minimap removal |
| `vl_hospital` | Compound clinic: doctor NPC, check-in heal/revive, 3 occupancy-tracked beds with sleep animation |
| `vl_apocalypse` | Removes NPC-driven traffic and **ambient aircraft**, and deletes the ones already spawned. Fills the three gaps `qbx_density` cannot: aircraft do not come from the traffic system at all (`qbx_ignore` suppresses ten models and lists neither `MAVERICK` nor `POLMAV`), and a density of `0.0` stops new spawns without removing what is already there. Judges entities with `GetEntityPopulationType` plus three more guards, so player and job vehicles are protected four ways. Leaves the per-frame density multipliers to `qbx_density` unless that resource is stopped |
| `vl_mapstyle` | Removes every map blip (waypoints kept) |
| `vl_setped` | `/setped [id] <model>` — change any player's ped model, or your own if you omit the id. Restricted to the `command.setped` ACE (covered by `group.admin command allow` in permissions.cfg). Chat autocomplete lists the custom **rust peds** shipped in `[assets]/vl_rust_peds` — `rust_nomad`, `rust_scientist`, `arctic_hazmat`, `makeshift` — but any valid model works unless `VLSetPed.restrictToList` is turned on. Two server-specific traps are handled: the swap goes **through illenium-appearance** and is saved back to it (a raw `SetPlayerModel` reverts on the next appearance refresh, and other players are shown illenium's version), and the target is **revived afterwards** — `SetPlayerModel` destroys the old ped, which qbx_medical reads as a death and answers with last stand, leaving them frozen and stated as dead |
| `vl_hunters` | **Armed T-800s that spawn around each player and patrol the streets on foot.** `t800` from `[assets]/vl_terminator`, 800 HP, Assault Rifle MK2, `move_m@muscle@a` walk (rpemotes' "Muscle"), accuracy 40, professional combat ability, never flees, drops no weapon. Up to 6 alive, spawned on road nodes 80-180m out and only where the player cannot see, wandering 120m from where they spawned, attacking on sight within 60m and staying committed to 150m. Deleted past 260m and on resource stop. Config-driven via `VLHunters.packs` — a second group is a copy of that block with different numbers, and `useRoadNodes = false` spawns one off the road network. **Entirely client-side by design** — server-spawned peds cost a networked entity slot for everybody and orphan on timeout |
| `vl_corpseloot` | **Search a downed player.** One ox_target option on a player whose `isDead` statebag is set (the native `IsPedFatallyInjured` is useless here — qbx_medical resurrects the ped and keeps it at full health playing `dead_a`) opens their *actual* ox_inventory via ox's own `otherplayer` path. Nothing is generated: garments worn through `vl_clothing` never leave the inventory, they are just flagged `metadata.worn`, and the AVP adapter only hides those from the grid for **your own** inventory (`m.side === 'player'`) — on a corpse they are ordinary grid items already. All this resource adds is the consequence: pulling a worn garment out of somebody's inventory strips it off their ped (through `vl_clothing.stripSlot`, persisted via `illenium-appearance`) and clears the `worn` flag on the item that moved, so the looter does not receive a shirt their clothing panel thinks they are wearing. Fires on ox's `swapItems` **post**-hook, not the pre-hook, so a swap that fails on weight cannot undress anyone |
| `vl_panel` | **One resource, four systems that used to be four separate ones** (`vl_blackout`, `vl_alert`, `vl_airraid` — none of the three exist on disk any more, fully merged in). `/vl_panel` (or the F6 keybind) opens one NUI: **Blackout** (`/blackouton [seconds\|Nm]`, `/blackoutoff` — countdown HUD, light flicker, audio cue, every player sees it), **Alert** (`/vl_alert <message>` — full-screen transmission + siren tone, every player), **Pager Alert** (`/pageralert [TITLE \| ]<message>` — pages every af-pager in range), and **Air Raid** (`/airraidon`/`/airraidoff` — runs a scripted warning *before* the sirens: pager alert → af-expeditions-style radio transmission with a CRT typewriter panel and sting → a **plain** full blackout (lights out until the raid ends, driven straight off `SetArtificialLightsState` — *not* `/blackouton`, whose countdown HUD, audio cue and flicker would read as a second event) → intruder alarm at 4 outposts → 4s → the sirens themselves, civil defense siren at 13 sites cascading in randomly, real 3D positional audio, gated by a citywide zone that fades out past its edge, one flashing zone blip on both minimap and full map. Every step's delay and copy is in `VLAirRaid.intro`; `/airraidoff` mid-sequence cancels the rest. Needs `html/intruder.mp3` dropped in manually — not shipped). Every button calls the same command via `ExecuteCommand` rather than a duplicated code path — see its own config.lua for why that also means its own permission check is the *only* gate those commands get once routed through here. Right side is a live player-position radar over a map image you supply yourself (`html/gta_map.png`, not shipped — see config.lua's calibration notes), falling back to a plain grid if it's absent. Needs `html/civil-defense-siren.mp3` dropped in manually too — not shipped |
| `vl_music` | Personal background music (`html/vl_bgmusic.mp3`). Louder when alone, fades out and pauses when anyone nearby talks or a crowd of more than three forms, fades back in from the same point after 10 s of silence. Entirely client-side — own volume, own position, own on/off via `/music`. Standalone; reads the voice state from the game natives, not from pma-voice |
| `kq_propplacer` | **Third party.** Prop placement tool, not authored here |
| `bodydrag` | **Third party** (Laugh), adapted here. Drag a downed player along the ground with synced animations. Rewired onto `ox_target` (ALT → *Drag body*) in place of its proximity prompt, and every death test now reads qbx_medical's `isDead` statebag — `IsPedDeadOrDying` is false for a qbx-dead player, so stock it could never find a target. Search `VoidLine` in `client/client.lua` and `server/server.lua`. **Also needs two one-line guards outside this folder — see below** |

### `bodydrag`: the two edits in `[qbx]`

Qbox re-applies its downed animation in a `Wait(0)` loop, in two places
depending on the state, and each is guarded with *"if the downed animation is
not playing, play it"*. So the moment bodydrag animates the victim, Qbox puts
the downed animation straight back — the dragger animates and the body just lies
there.

Both loops now skip while `LocalPlayer.state.bodydragged` is set, which bodydrag
sets on attach and clears on release, revive and respawn:

* `[qbx]/qbx_ambulancejob/client/setdownedstate.lua` — `handleDead`, for `DEAD`
* `[qbx]/qbx_medical/client/laststand.lua` — the laststand thread, for `LAST_STAND`

Both are marked `VoidLine:`. **A Qbox update reverts them and the drag animation
silently stops working on the victim** — the dragger will still animate, which
makes it look like a sync bug rather than a missing patch.

Neither loop is otherwise affected: the respawn countdown text still draws, and
each restores the animation matching its own state on the next frame after
release (which is why bodydrag does not call `PlayDeadAnimation` itself — that
would be the wrong animation for `LAST_STAND`).
| `combat_drone` | Autonomous flying combat drone: detection, targeting, state machine, patrol, obstacle avoidance, squad coordination, piloted-vehicle flight mode |
| `vl_drone_model` | Streams the `drone166` model used by `combat_drone` |
| `_framework_patches/` | **Not a resource.** Config changes third-party resources need. See its own README. |

### Retired: the custom weather systems

`vl_sandstorm` (amber sandstorm, `/sandstorm`) and `vl_atmos` (The Last of Us
colour grade, server-synced weather director, clock frozen at 19:00) were both
moved to `resources/[disabled]`. Weather and time are back under
**`Renewed-Weathersync`**, which now lives in `resources/[standalone]` and is
driven with `/weather`.

The folders are intact, so re-enabling either is a move plus a restart — but
only one weather resource may run at a time. They all compete for the same
weather type, clock override and primary timecycle modifier slot, and the loser
is whichever one asserts least often. Stop `Renewed-Weathersync` first.

---

## Dependencies

All must be running **before** `[voidline]`.

| Resource | Needed by | Why |
|---|---|---|
| `qbx_core` | identity, hospital, hud, drone | player data, Login, notifications, statebags |
| `ox_lib` | identity, hospital, hud, drone | dialogs, callbacks, context menus, `lib.print` |
| `oxmysql` | identity | `voidline_id` storage |
| `ox_inventory` | identity | ID card + starter kit items |
| `ox_target` | hospital | doctor NPC interaction |
| `qbx_medical` | hospital | `Revive` / `Heal` exports |
| `illenium-appearance` | identity | appearance creator, skin persistence |
| `MugShotBase64` | identity | ID card photo |
| `spawnmanager` | identity | disabling auto-spawn |
| `qbx_ambulancejob` | hospital *(optional)* | routes death-respawns to the compound clinic |

`vl_mapstyle` and `vl_apocalypse` have **no dependencies** — they are pure
natives and work on any FiveM server.

`vl_loadingscreen` has no hard dependency, but it declares
`loadscreen_manual_shutdown`, so the screen stays up until something calls
`ShutdownLoadingScreen()`. Here that is `vl_identity` in `startFlow()`, which is
why the music and artwork carry through into character selection. On a server
without `vl_identity`, `qbx_core` closes it instead, and `client/failsafe.lua`
forces it down 90s after the session starts if neither one runs.

**Only one loadscreen resource may be active.** The stock `loadscreen` was moved
to `resources/[disabled]` when this was added — starting both will conflict.

---

## server.cfg

One line, placed **after** `[ox]`, `[qbx]` and `[standalone]`:

```cfg
ensure [voidline]
```

Full ordering as used here:

```cfg
ensure ox_lib
ensure qbx_core
ensure ox_target
ensure [ox]
ensure [qbx]
ensure [standalone]
ensure [voice]
ensure [assets]
ensure [maps]
ensure [npwd-apps]

ensure [voidline]

ensure qbx_npwd
ensure npwd
```

### Resources that must be stopped

These conflict directly and must not run alongside VoidLine:

| Resource | Conflicts with | Symptom if left running |
|---|---|---|
| `qbx_hud` | `vl_hud` | two HUDs drawn on top of each other |
| `qbx_idcard` | `vl_identity` | registers the same `id_card` item, shows name/DOB/nationality |

Move them out of a started category folder (this server keeps them in
`resources/[disabled]/`).

`Renewed-Weathersync` is **not** in this list any more — it is the weather and
time authority on this server and runs from `[standalone]`. It conflicts only
with the retired `vl_sandstorm` / `vl_atmos`, which are in `[disabled]`.

It used to also register a `/blackout` command of its own — a **second**,
independent blackout system with its own state key (`GlobalState.blackOut`,
capital O) that could disagree with VoidLine's own about whether the city had
power. That command is deleted; see `_framework_patches/README.md` for the
patch and why. VoidLine's own blackout is `/blackouton` / `/blackoutoff`,
part of `vl_panel` (see its own entry above) — not a separate `vl_blackout`
resource any more.

---

## Database

One migration, applied **automatically** by `vl_identity` on first start:

```sql
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `voidline_id` INT UNSIGNED NULL DEFAULT NULL;
ALTER TABLE `players` ADD UNIQUE INDEX IF NOT EXISTS `voidline_id` (`voidline_id`);
```

Also available as `vl_identity/install.sql` if the automatic migration fails
(the console will say so). No other tables are required — everything else uses
stock Qbox tables.

---

## Items

`vl_identity` hands these out on character creation (1000 coins, 10 water, 10 sandwiches). They must exist in
`ox_inventory/data/items.lua`:

| Item | Status in stock ox_inventory |
|---|---|
| `id_card` | exists |
| `water` | exists |
| `sandwich` | exists but **inert** — must be made edible |
| `core` | **does not exist** — must be added (server currency) |

Both edits are documented in `_framework_patches/README.md`.

---

## Permissions

Uses FiveM ACE. Commands are gated on the `admin` ace, which Qbox's stock
`permissions.cfg` already grants to `group.admin`:

```cfg
add_principal identifier.license2:<their-license> group.admin #Name
```

---

## Commands

| Command | Resource | Permission |
|---|---|---|
| `/vl_panel` (or F6) | vl_panel | anyone opens the UI; every action inside re-checked, admin (ACE) |
| `/blackouton [seconds\|Nm]`, `/blackoutoff` | vl_panel | admin (ACE) |
| `/vl_alert <message>` | vl_panel | admin (`lance.eas` ace) |
| `/pageralert [TITLE \| ]<message>`, `/pageralertto <target> ...` | vl_panel | admin (`lance.eas` ace) |
| `/airraidon`, `/airraidoff` | vl_panel | admin (ACE) |
| `/spawndrone` | combat_drone | anyone (see note) |
| `/deletedrones` | combat_drone | anyone (see note) |
| `blipwipe` | vl_mapstyle | client console (F8) |
| `dronedebug`, `dronefiretest`, `dronedmgtest` | combat_drone | client console (F8) |

> `combat_drone`'s server commands are ungated by default. There is an
> `IsAllowed()` stub in `combat_drone/server.lua` — wire it to
> `IsPlayerAceAllowed(src, 'admin')` before using this on a public server.

---

## Convars

None required. `vl_identity` relies on Qbox's own
`setr qbx:enableBridge "true"` only if you run resources that use the qb-core
bridge; VoidLine itself does not.

---

## Exports

VoidLine consumes exports from others but exposes none of its own — nothing
external needs to call into it. Systems communicate through Qbox events
(`QBCore:Client:OnPlayerLoaded`), statebags and `GlobalState`.

---

## Fresh-server installation

1. Install a stock Qbox server and confirm it boots.
2. Copy `[voidline]` into `resources/`.
3. Stop the conflicting resources listed above (move them out of a started
   category folder).
4. Apply `_framework_patches/` — read that README first, especially if your Qbox
   is newer than this one.
5. Make the two `ox_inventory` item edits.
6. Add `ensure [voidline]` to `server.cfg` after `[standalone]`.
7. Start the server. `vl_identity` runs its own migration on first boot.
8. Connect. You should get the character creation dialog.

### Not included (third-party map content)

The apocalyptic map packs are **not** in this folder — they are large
third-party downloads, not our work:

| Pack | Size | Source |
|---|---|---|
| `assets_map`, `assets_map2`, `assets_map3`, `postapo-interior` | ~470 MB | The Apocalypse Project |
| `vl_apocalypse_map` | 1 MB | Apocalypse_MappingV3 |

Re-download and place them in `resources/[maps]/`. Each needs
`this_is_a_map 'yes'` in its manifest — two of them shipped without it, which
silently stops all their ymaps from loading.

---

## Verifying an install

| Check | Expected |
|---|---|
| Server console | no errors from any `vl_*` resource |
| Connect on a fresh account | Sex + Height dialog, then a 4-digit ID |
| After creation | spawn naked at the compound, ID card + 5 sandwiches + 5 water + notepad |
| Reconnect | no creation prompt, same ID, saved appearance |
| HUD | status icons bottom-right, stamina + noise bottom-left, no minimap |
| In a vehicle | dashboard bottom-left, stamina bar hidden |
| World | no pedestrians, no traffic |
| Weather | stock Renewed-Weathersync cycle, clock running; `/weather` opens the forecast |
| `/spawndrone` | drone spawns, flies, tracks and shoots |
