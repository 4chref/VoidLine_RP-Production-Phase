# vl_apocalypse

Stops NPC-driven traffic and ambient aircraft, and removes the ones already in
the world.

**Standalone.** `qbx_core` is used only for the notification on the admin
command, and every call is guarded, so this runs on a bare FiveM server.

---

## Why this exists when `qbx_density` is already at 0.0

Because density multipliers do not cover what you were seeing. Three separate
gaps, and the helicopters were the first two:

**1. Aircraft are not traffic.** The five `SetXDensityMultiplierThisFrame`
natives control ground vehicles, parked cars and pedestrians. Ambient
helicopters and planes come from vehicle generators and scenario points and
ignore traffic density entirely — which is why the sky still had a Maverick in
it with every multiplier at zero.

**2. `qbx_ignore`'s suppression list is short.** It suppresses ten models —
`SHAMAL`, `LUXOR`, `LUXOR2`, `JET`, `LAZER`, `TITAN`, `CRUSADER`, `RHINO`,
`AIRTUG`, `RIPLEY`, `BLIMP`. It does not list `MAVERICK` or `POLMAV`, which are
the two helicopters GTA V flies over Los Santos by default. This resource
suppresses **61 models, 33 of them aircraft that nothing else on the server
covers.**

**3. Density 0.0 stops spawns, it does not delete.** Anything that spawned
before you arrived, or before the resource started, simply stays.

`qbx_density`'s config already said *"vl_apocalypse reinforces this and also
clears entities that are already spawned"* — but that resource was no longer in
`[voidline]`. This restores it.

### What it deliberately does not do

It does **not** set the density multipliers while `qbx_density` is running.
Those natives are per-frame, meaning a `Wait(0)` loop, and `qbx_density` already
runs exactly that with every value at `0.0`. Running a second one would be pure
waste. `Config.Density.Mode = 'auto'` checks whether `qbx_density` is actually
started and only takes over if it is not.

---

## How entities are judged safe to delete

`GetEntityPopulationType`, not guesswork. The engine tags every entity with how
it came into the world:

| | | | |
|---|---|---|---|
| 0 `UNKNOWN` | 1 `RANDOM_PERMANENT` | 2 `RANDOM_PARKED` | 3 `RANDOM_PATROL` |
| 4 `RANDOM_SCENARIO` | 5 `RANDOM_AMBIENT` | **6 `PERMANENT`** | **7 `MISSION`** |
| 8 `REPLAY` | 9 `CACHE` | 10 `TOOL` | |

Only **1–5** are ever touched. A player's car, a job vehicle and a garage spawn
are `PERMANENT` or `MISSION` and can never match — that is what makes the sweep
safe to run on a timer.

Three more guards sit on top, so a player vehicle is protected by four
independent tests rather than one:

* `IsEntityAMissionEntity` — anything a script has claimed
* `NetworkGetEntityIsNetworked` — ambient population is client-local in FiveM,
  so this only ever excludes scripted and other players' vehicles
* a player in **any** seat, and `IsEntityAttached` — a car on a tow truck

Verified against a stub world covering all eleven cases:

| Case | Result |
|---|---|
| Ambient car, NPC driver | **deleted** |
| Ambient Maverick, no pilot spawned yet | **deleted** |
| Ambient plane, NPC pilot | **deleted** |
| Player's car (`MISSION`, networked) | kept |
| Ambient car with a **player** driving | kept |
| `PERMANENT` scripted vehicle with an NPC driver | kept |
| Ambient but networked | kept |
| Ambient on a tow truck (attached) | kept |
| Ambient claimed as a mission entity | kept |
| Ambient parked and empty | kept (`AllAmbient = false`) |
| Ambient with an NPC passenger but no driver | kept |

`vl_combat_drone` is safe by three of those four at once: it creates its drone
with `CreateVehicle(..., true, true)` and an explicit
`SetEntityAsMissionEntity`.

---

## Configuration

`config.lua`, heavily commented. The parts that matter:

```lua
Config.Cleanup = {
    IntervalMs  = 1000,   -- how often to sweep the vehicle pool
    NpcDriven   = true,   -- cars with a non-player ped at the wheel
    Aircraft    = true,   -- ambient helicopters and planes (classes 15, 16)
    AllAmbient  = false,  -- also empty parked ambient cars
    Occupants   = true,   -- delete the NPCs inside, not just the car
    MaxPerSweep = 24,     -- ceiling per sweep, so arriving somewhere dense
                          -- does not delete 100 entities in one frame
}
```

`AllAmbient` ships **off**. It is a bigger change than was asked for, and an
entirely carless street reads as a film set rather than an abandoned city — a
few dead vehicles at the kerb sell the look. Turn it on for a genuinely
swept-clean world.

`Config.World` holds the persistent flags: boats, trains, garbage trucks, random
cops, distant sirens, far-draw vehicles, parked-vehicle generators and the
population budgets. `Config.SuppressAircraft` / `SuppressEmergency` hold the
model lists, and `Config.DisableScenarioTypes` / `DisableScenarioGroups` the
scenario spawns.

`Config.RoutingBuckets` exposes `SetRoutingBucketPopulationEnabled`, a
server-side global kill for ambient population. It ships **off** and honestly
so: it is a blunter hammer than everything above and its exact interaction with
client-local ambient spawning was not verified here. The client-side path is
proven and sufficient on its own. Turn it on only if something still leaks
through.

---

## Commands

Server, ACE-gated on `admin` (already granted to `group.admin` in
`permissions.cfg`):

```bash
/apocalypse              # toggle
/apocalypse on | off     # force
/apocalypse status       # report
```

Client, local only:

```bash
/apocalypse_diag         # what is in the world right now, and what was removed
/apocalypse_sweep        # force one sweep, ignoring the interval
```

`/apocalypse_diag` reports the vehicle pool split into ambient and
player/scripted, so *"three ambient aircraft still in the world"* is a fact you
can read rather than a guess.

### Exports

| Client | |
|---|---|
| `IsActive()` | state |
| `Sweep()` | force one sweep, returns the count removed |
| `IsAmbient(entity)` | population-type test, for any entity |

| Server | |
|---|---|
| `SetApocalypse(bool)` | toggle for everyone |
| `IsApocalypseActive()` | state |

---

## Performance

The sweep walks `GetGamePool('CVehicle')` once per second and does nothing else.
Everything in section 3 of the config is a persistent native, applied at start
and re-asserted every 30 s only because another resource can clear it — so
suppression is roughly 60 native calls per *half minute*, not per frame.

There is no per-frame loop unless `qbx_density` is stopped, in which case this
takes over the one that resource was already running. Never two.

State is synced through `GlobalState` and survives a restart in
`apocalypse_state.json`. Turning it off restores every flag, un-suppresses every
model and re-enables every scenario — the world comes back without a reconnect.

---

## Interaction with `qbx_ignore`

Turning this off also re-enables the ten models and ten scenario types
`qbx_smallresources/qbx_ignore` disables on its own — the natives give no way to
tell *"disabled by us"* from *"disabled by them"*. That resource re-asserts its
list every 10 seconds, so its subset heals itself within one tick, and the
window only ever follows an explicit `/apocalypse off`.

Nothing in `[qbx]` was edited. `vl_apocalypse` re-asserts everything itself, so
a Qbox update cannot silently revert this the way a patched config would.
