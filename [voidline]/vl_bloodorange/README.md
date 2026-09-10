# vl_bloodorange — BLOOD ORANGE

A dedicated apocalyptic weather **preset**: deep orange-red sky at every hour, dense
glowing haze, crushed ambient light so terrain, trees and buildings collapse into dark
reddish silhouettes, a sun diffused into a smear rather than a disc, and a saturated
low-exposure blood grade over the whole frame. No blue tones, no rain, no clean daylight.

It is **not** a re-skinned GTA weather type: the atmosphere comes from a real timecycle
modifier built at runtime from `client/preset.lua` (~120 graded variables covering sky
dome, sun, clouds, fog, distance haze, directional + ambient light, exposure, bloom,
saturation, vignette and colour grading), plus per-hour keyframes that replace the
vanilla day/night curves so the world never swings back to blue after dark.

---

## How it reaches /weatherpanel

`vl_dynamicweather` remains the one weather/time authority — this resource never sets a
weather itself, so nothing fights and nothing desyncs.

GTA accepts exactly 15 weather names and the panel is locked to that list, so BLOOD
ORANGE **takes over the `HALLOWEEN` slot**:

| What | Where |
|---|---|
| Panel name → "Blood Orange" | `vl_dynamicweather/locale/en.lua`, `locale/tr.lua` (`weather.HALLOWEEN`) |
| Panel icon → blood sun over a dark ridge | `vl_dynamicweather/html/HALLOWEEN.svg` |
| Default temperature → 47 °C | `vl_dynamicweather/html/index.js`, `web/src/utils/weather.ts` |

Pick **Blood Orange** in `/weatherpanel` — for one zone, for every zone, or as a
scheduled forecast entry — and it syncs server-wide exactly like any other weather.
Each client then sees the synced value and paints the preset on top, so everybody is
looking at the same sky at the same moment.

The 47 °C default is deliberate: `vl_dynamicweather`'s heat-haze shimmer switches on
above `Config.HeatHazeTemp` (35 °C), which adds real desert distortion on top of the
preset. That is the "hot / toxic / dusty" half of the look.

Originals of every patched file are in `vl_dynamicweather/_bloodorange_backup/`.

### Without the panel

```
/bloodorange on      # force it everywhere (optional 2nd arg = temperature)
/bloodorange off     # clear the override, back to the panel setup
```

Allowed for `dynamicweather.admin` holders and for `bloodorange.admin`
(added in `server.cfg`).

---

## Tuning

Everything lives in two files.

**`config/Config.lua`** — the dials you will actually touch:

| Setting | Effect |
|---|---|
| `BO.DustSpacing` | **The sight-distance dial.** Metres between world-anchored emitters — smaller means less clear air between clouds. `10–14` = a wall · `16–22` = heavy with gaps · `28+` = scattered. |
| `BO.DustMaxEmitters` | Hard cap on live clouds. Particles are the expensive part of the preset, so this is the FPS dial. |
| `BO.DustFieldRadius` | How far out cells stay alive. Keep well past your sight distance so the wall has no visible near edge. |
| `BO.DustAlpha` / `BO.DustScale` | Opacity and cloud size. Scale should exceed spacing so neighbours overlap into one mass instead of reading as puffs. |
| `BO.DustColor` | Dust tint, linear RGB. Matches `BO.HazeColor` by default so near dust and far haze read as one storm. |
| `BO.BaseWeather` | The foggy weather each client is switched onto underneath the preset. **This is where the actual fog comes from** — `'FOGGY'` (dense, default), `'SMOG'` (thinner, browner), `''` to disable and lose the fog. |
| `BO.WindSpeed` | Moving air. `1.0` calm · `5.0` default · `11.0` violent. Most of what separates "orange fog" from "sandstorm". |
| `BO.VisibilityMeters` | **The main dial.** How far you can see, in metres. `10` = near blind, `22` = heavy dust storm (default), `60` = thick but drivable. |
| `BO.HazeColor` | Linear RGB the distance grades into — i.e. what the far half of the screen actually looks like. Too dark here and the horizon reads as a black void instead of mist. |
| `BO.HazeBrightness` | How brightly the mist glows. `0.8` dark smoke · `1.3` lit dust (default) · `1.9` blinding. |
| `BO.Exposure` | Global brightness trim in EV stops, negative is darker. `-2.0` default. Push toward `-3.0` if the scene still washes out pale. |
| `BO.Strength` | Overall intensity, `0.0`–`1.0`. Drop to `0.75` if it is too much. |
| `BO.TriggerWeather` | Which weather slot BLOOD ORANGE hijacks. Rename the same key in the locale files if you change it. |
| `BO.ScreenTint` | Extra full-screen blood cast, `0.0` disables. Guarantees the look on low graphics settings. |
| `BO.ScreenVignette` | Soft edge burn on top of the timecycle vignette. |
| `BO.CloudHat` / `BO.CloudOpacity` | Cloud layer. `''` keeps the weather's own. |
| `BO.KillRain` | Keeps roads dry — wet asphalt instantly kills the dusty read. |
| `BO.UseMainSlot` | Take the main timecycle slot too when it is free (≈ double strength). |
| `BO.Debug` | Prints which timecycle variables were applied vs. skipped. |

**`client/dust.lua`** — the world-anchored particle dust field (occlusion).
**`client/preset.lua`** — the preset itself. `BO.Preset` is the flat grade;
`BO.Hourly` holds the per-hour curves (built on the vanilla keyframe hours
00/05/06/07/09/12/16/17/18/19/20/21/22, interpolated in between).

Quick pulls, if you want to push it further:

- Thicker haze → lower `BO.VisibilityMeters` (do **not** hand-edit
  `fog_shape_log_10_of_visibility` / `far_clip`; the client rewrites both from that dial).
- Darker silhouettes → lower `BO.Exposure`, then `light_amb_down_intensity`.
- Washed-out pale frame → that is bloom, not fog: raise `postfx_bright_pass_thresh`
  and lower `postfx_intensity_bloom`, `sky_hdr`, `fog_hdr`, `fog_haze_hdr`, `light_dir_mult`.
- More saturation → push `postfx_desaturation` further negative.
- Softer sun → raise `sky_sun_disc_size`, lower `sky_sun_hdr`.

### Dialling it in live

With `BO.Debug = true`, three client-side commands retune without a restart
(gated behind the flag so players cannot use them to see through the storm):

```
/bodust 13 0.75 8     # dust spacing, alpha, scale  (the sight-distance dial)
/bodustmax 24 55      # max live emitters, field radius
/bodustfx core exp_grd_bzgas_smoke
/bobase FOGGY         # base weather: FOGGY, SMOG, or off
/bowind 5             # wind strength
/bovis 22             # visibility in metres
/bohaze 1.3           # how brightly the mist glows
/bohazecol 0.92 0.37 0.11   # mist colour, linear RGB
/boexp -2.5           # exposure in EV, negative is darker
/botint 0.07          # screen tint strength
```

Two traps worth knowing:

- `fog_shape_log_10_of_visibility` is the **log10 of visibility in metres** — 10 m is
  `1.0`, 100 m is `2.0`, vanilla clear weather sits near `4.0`. A negative value there
  does nothing at all.
- **Dust is anchored to the world, never to the player.** Emitters sit on a fixed
  global lattice and you walk *through* them. Attaching them to the ped drags a ring
  of clouds around with you, and rebuilding that ring whenever one handle is culled
  makes the whole field flicker in and out. Cells that are already alive are now left
  strictly alone. Positions and jitter derive from world coordinates only — never from
  the player, and never from `math.random()` — so every client computes an identical
  field and players standing together see the same clouds. There is no server-spawned
  ptfx in FiveM; a deterministic world field is how you get a server-consistent result.
- **Timecycle `fog_*` vars recolour fog, they do not create it.** They grade fog the
  weather already produces, and on some builds several of them are dropped entirely
  (turn on `BO.Debug` to see which). That is why sight distance is enforced with
  particles instead — `BO.DustRadius` is the real dial, and it works everywhere.
- **GTA's distance fog lives in the weather, not in timecycle vars.** Grading
  `fog_*` alone gives an orange world you can still see clean across; the fog
  itself has to come from a foggy base weather underneath (`BO.BaseWeather`),
  which the preset then repaints orange. This is done with vl_dynamicweather's
  `setLocalWeather`, the sanctioned deviation that its self-heal leaves alone —
  and since every client does it off the same synced value, it stays consistent.
- **`far_clip` is not a visibility lever.** A clip plane does not draw fog, it draws
  *nothing* — pull it in and you get a hard black band across the horizon instead of a
  mist wall. It stays pinned at `1600` so geometry always reaches the fog and dissolves
  into it. All limiting is done by fog density and the log10 visibility above.

### Why runtime instead of a streamed `timecycle_mods_*.xml`

A streamed XML can be silently defeated by a stale client cache or by data-file load
order. Building the modifier with `CreateTimecycleModifier` / `SetTimecycleModifierVar`
cannot. Every variable name is also checked against the running game's own variable
dictionary first (`GetTimecycleVarCount` / `GetTimecycleVarNameByIndex`), so a name a
given build spells differently is skipped instead of erroring — turn on `BO.Debug` once
after install to see the applied/skipped list in the client console (F8).

---

## Slot handling

The preset always occupies the **extra** timecycle slot, and additionally takes the
**main** slot while nothing else owns it — stepping straight back out when another
script (heat haze, an interior, a cutscene) claims it. It re-applies every 500 ms, so
anything that clears it gets it back immediately.

## Exports

```lua
-- client
exports['vl_bloodorange']:isActive()          -- boolean
exports['vl_bloodorange']:getPresetName()     -- 'bloodorange'
exports['vl_bloodorange']:setLocal(true)      -- force it for THIS client only
AddEventHandler('bloodorange:onStateChange', function(active) end)

-- server
exports['vl_bloodorange']:setGlobal(47)       -- force it everywhere
exports['vl_bloodorange']:clearGlobal()
exports['vl_bloodorange']:getTriggerWeather() -- 'HALLOWEEN'
```
