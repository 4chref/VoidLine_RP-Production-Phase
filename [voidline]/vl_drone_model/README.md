# vl_drone_model

Streams the Oblivion combat drone add-on model (`drone166`) so `combat_drone`
can attach it as a visual shell. **Installed and ready** - the extracted files
are already in `stream/` and `data/`.

Spawn name: **`drone166`** (matches `Config.Visual.model` in `combat_drone`).

## Contents

```
stream/drone166.yft       1,692,833 B   model
stream/drone166_hi.yft    1,690,794 B   high-detail LOD
stream/drone166.ytd         645,307 B   textures
data/vehicles.meta                      modelName/txdName drone166, handlingId DRONE166
data/carvariations.meta                 colour variations
data/handling.meta                      DRONE166 flying handling
```

FiveM cannot load a `dlc.rpf` directly, which is why these are extracted files
rather than the original archive.

## Deliberately not loaded

The add-on also ships `droneweapons.meta` and `dlctext.meta`, both omitted:

* `droneweapons.meta` is a `WEAPONINFO_FILE` blob named
  "DLC - Turret (Insurgent)", i.e. it reuses the name of a stock Rockstar
  weapon blob and could override it server-wide. It defines
  `VEHICLE_WEAPON_DRONE` for firing the drone *as a driveable vehicle*, which
  this setup never does - the ped inside the shell does the shooting with a
  real ped weapon. Leaving it out avoids the conflict for no loss.
  As a result `handling.meta`'s reference to `VEHICLE_WEAPON_DRONE` doesn't
  resolve; harmless for a cosmetic shell.
* `dlctext.meta` only supplies the DLC display-name table, irrelevant here.

`vehicles.meta` also carries a `<txdRelationships>` entry pointing at `f117`,
left over from the mod author's own build. It refers to a model that isn't in
this pack, so it's a no-op. Left untouched to keep the mod files verbatim.

## Verifying

In-game as admin: `/car drone166` should spawn the drone as a vehicle. If that
works the model is streaming correctly and `combat_drone` will pick it up.
Delete it afterwards - `combat_drone` uses the model only as a cosmetic shell,
never as a driveable vehicle.
