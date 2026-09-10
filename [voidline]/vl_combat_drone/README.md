# combat_drone

An intelligent, networked combat drone for FiveM (OneSync). It flies the
`drone166` add-on vehicle with a hidden pilot, fires **the model's own mounted
weapon** with real GTA bullet damage, avoids buildings, sounds a positional
alert, and gives players a countdown to clear the area before it opens fire.
There are no fake bullets, no particle-effect shooting, and no custom projectile
entities anywhere in this resource.

## Commands

| Command | Effect |
|---|---|
| `/spawndrone` | Spawns a drone a few meters in front of the calling player, hovering. |
| `/deletedrones` | Deletes every drone currently tracked by the server registry. |

Both commands are server-registered in `server.lua`; wire `IsAllowed()` in that
file up to your permission system (ACE, framework job/rank, etc.) before going
to production — by default anyone can use them.

## Resource structure

```text
combat_drone/
├── fxmanifest.lua
├── config.lua
├── server.lua
├── README.md
├── html/
│   ├── index.html      -- 3D siren audio (Web Audio) + warning countdown HUD
│   └── alert.mp3       -- the drone's alert sound
└── client/
    ├── utils.lua        -- math/raycast/text helpers
    ├── obstacle.lua      -- hull-width probing, braking, avoidance steering
    ├── movement.lua       -- simulated flight (velocity integration, facing)
    ├── detection.lua      -- distance/FOV/LOS target scanning + memory
    ├── targeting.lua      -- priority scoring + target lock
    ├── combat.lua          -- burst fire control + attack positioning
    ├── strike.lua           -- airstrike: impact telegraphs + missile salvo
    ├── patrol.lua           -- patrol point cycling
    ├── squad.lua             -- multi-drone role assignment + separation
    ├── audio.lua              -- positional alert siren (streams to the NUI page)
    ├── warning.lua             -- "leave the area" challenge + countdown
    ├── statemachine.lua         -- state machine + per-frame flight tick
    ├── debug.lua                 -- on-screen/3D debug overlay
    └── main.lua                   -- spawn/despawn, networking, event wiring
```

## Why a PED can "fly"

GTA peds have no native flight task. This resource disables the drone's gravity
(`SetEntityHasGravity(ped, false)`) and drives its position every tick with its
own velocity integrator (acceleration/deceleration toward a desired point,
clamped to a max speed — see `client/movement.lua`). This is what makes the
movement smooth instead of teleporting: each tick moves the ped a small
distance along a continuously-updated velocity vector, never a long-distance
snap. Weapon behavior is completely separate from this and uses fully genuine
ped combat natives, so ammo, damage, and hit registration are all standard GTA
weapon mechanics.

**Model note:** `Config.DroneModel` defaults to `mp_m_freemode_01` purely so the
resource works out of the box with base-game assets. For a drone that actually
*looks* like a drone, point this at a robot/drone-styled addon ped from your
server's asset pack — the AI code doesn't care what the model looks like.

## Networking approach

- The drone entity is created client-side and registered as a networked
  mission entity (`SetEntityAsMissionEntity(ped, true, true)`), so OneSync
  replicates its position/health/etc. to every client automatically.
- **Exactly one client drives a drone's AI at a time.** Every client that
  learns about a drone (via server broadcast) runs a lightweight watcher, but
  it only issues movement/combat natives when
  `NetworkHasControlOfEntity(ped)` is true locally. OneSync elects and
  migrates that "control" automatically (generally to whichever client is
  closest), so this resource never has to implement its own ownership
  handshake, and there is no duplicated shooting or duplicated AI decisions.
- The server (`server.lua`) never runs AI. It only relays `/spawndrone` and
  `/deletedrones`, and keeps a registry of network IDs so a client that
  connects mid-session can discover drones that already exist.
- AI *decision state* (current target, search timers, patrol progress) lives
  in a plain Lua table on whichever client currently has control and is not
  synced between clients. If control migrates mid-fight, the new controller
  re-derives the situation within one detection scan
  (`Config.Detection.scanInterval`, default 1s). What players actually see —
  the drone's position, health, and whether it's shooting — stays perfectly
  synced the whole time via OneSync, since that's normal replicated entity
  state, not AI bookkeeping.

## Update intervals (performance)

Nothing in this resource runs a single frame-by-frame loop for every drone.
Each drone has independent threads at independent rates, all tunable in
`Config.Intervals`:

- **Flight tick** (`movementActive`, default every frame while controlling) —
  cheap: seeks a precomputed desired position, no scanning.
- **State machine decision** (`stateMachine`, default 250ms) — evaluates
  transitions, does not touch movement natives.
- **Detection scan** (`Config.Detection.scanInterval`, default 1000ms) — the
  only "expensive" operation (iterates nearby players + raycasts), and it's
  explicitly decoupled from the flight tick.
- **Patrol/search decisions** are folded into the flight tick's state-specific
  branch but only mutate their own small waypoint index, not a search per
  frame.
- Clients that do **not** currently control a given drone skip nearly all of
  the above (cheap `Wait` polling only), so having many players near a drone
  does not multiply its cost.

## The challenge: warn, then eliminate

The drone does not open fire on sight. On confirming a player it enters
**WARNING**: it sounds its alert, shadows them in a slow standoff orbit with
weapons cold, and puts a countdown on *that player's* screen reading
**"LEAVE THE AREA OR YOU WILL BE ELIMINATED"**. Two outcomes:

- **They leave.** Getting more than `Config.Warning.clearRadius` (55m) from the
  drone cancels the countdown, the siren stops and the drone returns to patrol.
- **They don't.** The countdown hits zero, the panel latches to a solid-red
  **"ELIMINATION AUTHORIZED — MISSILE STRIKE INBOUND"** banner, the drone breaks
  off and leaves, and missiles come down out of the sky (see below). The player
  is also *flagged*: every drone engages them on sight, with no second warning,
  for `Config.Warning.flagDuration` (90s). Without the flag, a player could farm
  warnings forever by stepping in and out of range.

The expired banner latches deliberately — once it is up, a late heartbeat cannot
revert it to a countdown and the drone's own teardown cannot wipe it early. It
clears itself after `Config.Warning.expiredDisplayMs`. Nothing on screen should
ever suggest there is time left while the drone is already shooting.

Anyone who shoots at the drone forfeits the warning and is engaged immediately.
NPCs are never warned (there is nobody to show a countdown to).

**The countdown clock lives on the server.** This is not incidental: the drone's
AI runs on whichever client currently controls the entity, and OneSync can
migrate that control mid-countdown. A client-owned timer would silently restart
on every migration and nobody would ever actually run out of time. The
controlling client only *heartbeats* ("I still want this player warned") and the
server owns `expiresAt`, pushes the remaining time to the target's client, and
declares the expiry to everyone. The heartbeat doubles as a liveness signal — if
the drone is destroyed, loses the target, or the resource stops, the beats stop
and the countdown clears itself from the player's screen.

Briefly breaking line of sight *pauses* rather than cancels: the heartbeat stops
but the server keeps the countdown alive for `staleTimeout` (3s), so ducking
behind a car resumes the original countdown instead of granting a free reset.

## The airstrike

The drone is a **spotter, not the executioner**. When the countdown expires it
enters `WITHDRAWING` — full speed away from the target, gaining
`Config.Strike.withdrawAltitude` metres, siren still blaring — and a salvo of
`Config.Strike.count` missiles falls on the target from `spawnHeight` overhead.

`Config.Strike.delay` is deliberately longer than the drone needs to clear its
own blast radius; the drone leaves *before* the first missile is committed.

**Each missile is aimed when it is fired, not when the strike is called.**
Computing all the impact points up front would make the whole salvo dodgeable by
taking one step, and simultaneously unavoidable for anyone standing still — the
worst of both. Instead every missile reads the target's *current* position, adds
lead and scatter, telegraphs the spot with a ground marker whose ring closes in
and whose flash accelerates for `markerLeadTime`, and only then launches. A
player who sprints and changes direction can beat individual missiles; a player
who stays put cannot survive the salvo. That is what makes "leave the area" a
real instruction rather than a formality.

`leadFactor` is kept well under 1.0 on purpose: it punishes running in a straight
line without making evasion impossible.

The missiles are real GTA projectiles (`WEAPON_AIRSTRIKE_ROCKET`), so the trail,
the impact explosion and the damage are all the game's own — nothing here
simulates a blast. They are networked projectiles, so everyone sees them; only
the ground markers are relayed, so bystanders get the same warning the target
does. If neither rocket asset streams in, the strike falls back to a direct
`AddExplosion` at the impact point rather than silently doing nothing (no
projectile was created, so it cannot double up).

Set **`Config.Strike.enabled = false`** to go back to the drone gunning targets
down itself with its own weapon. If a strike is still on cooldown for that player
(`Config.Strike.cooldown`, 30s) the drone also falls back to engaging directly —
withdrawing without calling anything in would leave it endlessly retreating from
a target it never does anything to.

## The alert sound

`html/alert.mp3` is played **from the drone**, and follows it as it moves.

FiveM cannot play a custom mp3 out of a world entity — `PlaySoundFromEntity`
only plays sounds from a loaded game audio bank, and building a bank needs an
`.awc` that can't be produced at runtime. So the mp3 is played by the resource's
NUI page and spatialised there with the Web Audio API: every drone gets its own
`PannerNode` (HRTF, inverse distance model), giving real distance attenuation
and real stereo panning as the drone circles you — not a faked volume curve.

The page's audio listener never moves. `client/audio.lua` streams each drone's
position *relative to the gameplay camera* (right / up / behind), which is
mathematically identical to moving the listener and means only three numbers per
drone cross the Lua→NUI boundary. Positions are sent at ~15Hz rather than per
frame; the page eases between samples each animation frame so the motion still
sounds smooth.

Everyone nearby hears it, not just whoever's client runs the AI: siren state is
relayed through the server and each client renders the sound locally from its
own copy of the entity, so following the drone costs no ongoing bandwidth.

## AI state machine

`IDLE → PATROL ⇄ INVESTIGATING → WARNING → TRACKING/ENGAGING → LOST_TARGET → SEARCHING → RETURNING → PATROL`,
with `DAMAGED` and `RETREATING` able to interrupt from anywhere based on
health, and `DESTROYED` as a terminal state.

- **INVESTIGATING** — a freshly-spotted target that isn't yet confirmed
  hostile (hasn't attacked/damaged the drone) is approached cautiously for
  `Config.Detection.confirmDuration` before the drone commits to combat.
- **WARNING** — confirmed player, countdown running. Slow standoff orbit at
  `Config.Warning.standoffDistance`, siren sounding, **weapons cold**.
- **WITHDRAWING** — the countdown expired and a strike has been called. The
  drone leaves at full speed while the missiles come down. Checked *before*
  target selection each tick, so normal targeting can't drag it back toward the
  target it is deliberately flying away from.
- **TRACKING** — target confirmed and visible, but outside engagement range;
  the drone closes distance.
- **ENGAGING** — target confirmed, visible, and in range; full combat
  controller (`client/combat.lua`) takes over positioning and firing.
- **LOST_TARGET → SEARCHING** — losing line of sight during
  WARNING/TRACKING/ENGAGING/INVESTIGATING drops into a brief transitional state, then
  the drone flies to the last known position and checks a ring of nearby
  waypoints (`Config.Search`) before giving up and **RETURNING** to patrol.
- **DAMAGED** — reactive, entered immediately on taking damage (via the
  `CEventNetworkEntityDamage` game event) to re-prioritize the attacker; the
  very next decision tick moves it into TRACKING/ENGAGING/SEARCHING as
  appropriate.
- **RETREATING** — triggered below `Config.Damage.criticalHealthPercent`;
  gains distance and altitude, optionally alerts nearby drones
  (`Config.Damage.callBackupOnCritical`).

## The weapon: the drone model's own gun

`Config.Weapon.fireMethod = 'vehicle'` fires **`VEHICLE_WEAPON_DRONE`** — the
weapon defined in `vl_drone_model/data/droneweapons.meta` and bound to seat 0 in
`handling.meta` — out of the model's real weapon bones. That is what gives the
correct muzzle flash (`muz_buzzard`), jet tracers, turret audio and damage
profile, instead of a generic rifle firing from a point in front of the hull.

Rounds are emitted with `ShootSingleBulletBetweenCoords` rather than
`TaskVehicleShootAtPed` alone. This still fires the vehicle's own weapon with all
of its metadata, but the rate of fire, burst pattern and aim stay under this
resource's control, and it cannot be silently broken by a seat or turret binding
that a given model happens to get wrong. Damage is genuine GTA bullet damage
resolved by the game, exactly as an NPC shooting you.

Rounds are fired with `ShootSingleBulletBetweenCoordsIgnoreEntity`, passing the
drone's own hull as the ignored entity. This is not cosmetic: the round leaves a
weapon bone *on* the model and the drone engages from *above* its target, so it
fires downward through its own bodywork. Without the ignore, the drone shoots
itself, bleeds health until it hits critical and flees, and the player never
takes a hit — a drone that tracks you perfectly and is somehow harmless.

Bones are resolved once per model from `Config.Weapon.vehicle.muzzleBones` (the
first names the model actually has are used, alternating between them so a
twin-gun model fires from both sides); models with none of them fall back to
`muzzleOffset`. If `droneweapons.meta` didn't load, the weapon falls back to
`VEHICLE_WEAPON_PLAYER_LAZER` — still a vehicle weapon, not a handheld one.

`'direct'` (handheld weapon hash) and `'task'` (pure native turret AI) remain
available in `config.lua`.

## Flight and collision avoidance

Drones used to fly into buildings. Four things fix that, and they are separate
mechanisms because steering alone cannot solve it — steering only changes *where*
the drone is heading, never how fast it arrives:

1. **Hull-width probes.** Every obstacle probe is a capsule sized to the model's
   real dimensions (`GetModelDimensions` + `hullPadding`), not a hairline ray. A
   thin ray happily threads a gap the drone cannot fit through, which is exactly
   how it used to steer "clear" straight into a corner.
2. **Speed-scaled look-ahead and braking.** The probe distance scales with
   current speed (`lookaheadTime`), and a brake factor caps speed as obstacles
   close in. Probing a fixed 12m ahead at 9m/s with 4m/s² of deceleration is
   physically not enough runway to stop.
3. **Wall sliding, not bouncing.** The surface normal is used to remove the
   into-the-wall component of travel and slide *along* the obstruction, plus a
   fan search for the genuinely clearest way around (biased toward the desired
   heading, and toward climbing — over a city, up is almost always the way out).
   `CancelIntoSurface` is a hard guarantee: velocity pointing into a surface the
   drone is already touching is stripped regardless of what the steering decided.
4. **Stuck escape.** "Commanded to move but not actually moving" — wedged in an
   alley, caught under an awning — is detected by displacement sampling and
   forces a vertical escape, since no amount of steering fixes a drone whose
   every desired direction is the one it is stuck against.

Two supporting fixes: altitude clamping is now **roof-aware** (a downward probe,
not just `GetGroundZFor_3dCoord`, which only knows about *ground* — a drone
crossing a tower block believed it had 60m of clearance while the roof was 2m
below it), and destinations chosen by combat/patrol logic are lifted out of solid
geometry before the drone flies at them. `Config.Movement.collisionProof` also
makes scraping scenery non-lethal while leaving the drone fully shootable.

Probes are cached per drone and refreshed on `Config.ObstacleAvoidance
.updateInterval` (100ms) rather than every frame — shape tests are the most
expensive thing this resource does, and in 100ms a 9m/s drone has moved 0.9m
against a 5m emergency margin. The previous code ran nine shape tests *per frame
per drone* and ignored its own `updateInterval` setting entirely.

## Multiple drones / squad behavior

`Config.Squad` lets drones that are simultaneously engaging the *same* target
(and are locally controlled by the same client) agree on roles — `engage`,
`flank`, `ranged` — via a stable sort so they don't need to negotiate every
frame, plus a small separation vector so they don't stack on top of each
other. Coordination is intentionally scoped to drones the local client
controls; see the networking section for why cross-client AI coordination is
out of scope by design.

## Known limitations / native reliability notes

- **No native ped flight task.** As explained above, flight is simulated via
  gravity-disable + manual velocity integration. This is the standard,
  reliable approach used by most "flying ped" FiveM scripts; there is no GTA
  native that gives a ped genuine aerodynamic flight.
- **Combat attribute flag numbers** (`SetPedCombatAttributes`) are sparsely
  and inconsistently documented across the community; the ones used here
  (`0` = can't use cover, `5` = can flank, `20` = always fight) are the
  widely-agreed-upon values, but if your game build behaves differently,
  tune them in `client/combat.lua` / `client/main.lua`.
- **Shape test natives are asynchronous.** `client/utils.lua` polls
  `GetShapeTestResult` until it reports ready (bounded to 10 ticks) instead
  of trusting a single immediate read, which is a common source of
  intermittent "sees through walls" bugs in less careful implementations.
- **Ownership migration and AI memory.** As noted above, a drone's tactical
  memory (current target, search progress) is not synced across the
  ownership handoff. In practice this is very rarely noticeable — it only
  matters if control migrates mid-search, in which case the new controller
  just starts a fresh scan.
- **`TaskShootAtEntity` accuracy** is governed by `SetPedAccuracy`, which is a
  GTA-native RNG-based spread, not a literal hit-chance; at very high
  accuracy values peds still occasionally miss, and at very low values they
  can still land shots. This is a limitation of the underlying native, not
  this resource. (Only relevant to `fireMethod = 'task'`; the default
  `'vehicle'` mode controls spread itself via `Config.Weapon.spread`.)
- **NUI audio needs the resource's own page.** The siren plays through
  `ui_page`, not a DUI — DUI browsers in FiveM have no audio output at all. If
  another resource takes NUI focus the siren keeps playing normally; it only
  stops if the resource itself is stopped.
- **Weapon bone names vary by drone model.** If you swap `Config.Visual.model`
  for a different drone, check `Config.Weapon.vehicle.muzzleBones` — with
  `Config.Debug = true` the console prints how many bones resolved on spawn. A
  model with none of them still fires correctly, just from `muzzleOffset`
  rather than from the gun itself.

## Configuration

Every tunable mentioned above (and more — weapon, health/armor, detection
radius/FOV, accuracy, fire rate/burst timing, engagement distance, altitude
bounds, movement speed/acceleration, search duration, target memory,
patrol points, aggressiveness, retreat health %, obstacle avoidance distance,
debug mode) lives in `config.lua` with inline comments.

The most likely things you'll want to change:

| Setting | Effect |
|---|---|
| `Config.Warning.duration` | How long the player has to leave (default 12s). |
| `Config.Warning.message` | The text on the countdown. |
| `Config.Warning.clearRadius` | How far they must get to be let off (default 55m). |
| `Config.Warning.flagDuration` | How long a non-complier is shot on sight (default 90s). |
| `Config.Warning.enabled = false` | No challenge at all — the drone engages on sight, as before. |
| `Config.Strike.count` / `interval` | Missiles per salvo and how fast they land. |
| `Config.Strike.markerLeadTime` | The player's reaction window per missile. Lower = harsher. |
| `Config.Strike.spread` / `leadFactor` | How accurate the salvo is, and how hard it is to outrun. |
| `Config.Strike.enabled = false` | The drone guns targets down itself instead of calling a strike. |
| `Config.Alert.volume` / `maxDistance` | Siren loudness and audible range. |
| `Config.Alert.enabled = false` | Silence the drone. |
| `Config.ObstacleAvoidance.hullPadding` | Raise if the drone still clips scenery; lower if it flies too timidly. |
| `Config.Movement.maxSpeed` | Slower drones have more time to avoid things. |

To use a different alert sound, drop your own file in `html/` and point
`Config.Alert.sound` at it (it must also be listed in `files{}` in
`fxmanifest.lua`).

## Troubleshooting

Run **`/dronediag`** in F8. It drives the NUI page, the weapon and the AI
separately and prints which link is broken, rather than leaving you to infer it
from "nothing happens".

| Symptom | Most likely cause |
|---|---|
| `attempt to index a nil value (global 'Warning' / 'Audio')` | The client is holding a stale copy of the resource's **script list**. FiveM sends that list at connect time, so changing a file's *contents* propagates on `restart`, but **adding a new file to `client_scripts` needs the client to reconnect**. Type `reconnect` in F8. main.lua detects this at startup and prints the fix rather than spraying nil-index errors. |
| No countdown **and** no sound | The NUI page never loaded. Adding `ui_page` to a resource needs a full `restart vl_combat_drone` **and a client reconnect** — a `refresh`/`ensure` on an already-running resource does not create the NUI frame. `/dronediag` says this outright if the page never reported in. |
| Countdown shows, no sound | The mp3 failed to load or decode. The F8 console prints the exact error (the page reports it back to Lua). |
| Drone follows you but nothing happens | Expected for the first ~12s — that *is* the warning. After that it breaks off and the missiles come down. `/dronestrike` fires a salvo at you immediately with no drone involved; `/droneengage` skips the countdown. |
| Markers appear but no missiles | The rocket asset didn't stream in. `/dronediag` prints whether `WEAPON_AIRSTRIKE_ROCKET` and its fallback are loaded. With `Config.Strike.explosionFallback` on you still get the blast. |
| Drone never reacts to you at all | It never detected you. `/dronediag` prints distance, line of sight and field-of-view checks against your ped. Note the default `Config.PatrolPoints` are at map coordinates `(100,100,50)` — set them near where you actually spawn drones, or the drone flies off across the map. |
| Shots visible but no damage | Run `/dronedmgtest` — if your health doesn't move, godmode is absorbing it and the drone is not at fault. |

The drone's decision to open fire is made **locally** on the controlling client
(`Config.Warning.localGrace`), so a broken server relay or NUI page degrades the
warning presentation but never leaves the drone unable to shoot. Likewise the
weapon resolver never fires an unloaded asset — if `VEHICLE_WEAPON_DRONE` isn't
streaming it says so once in the console and falls back to a stock weapon, so a
misconfigured `vl_drone_model` costs you the muzzle flash, not the gun.

## Debug mode

Set `Config.Debug = true` to draw, above every locally-controlled drone: its
current state, current target, target distance, health/armor, last known
position, detection radius (as a ground marker), current speed, and current
patrol point index.
