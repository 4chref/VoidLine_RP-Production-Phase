Config = {}

-- Test command
Config.Command = 'nuclearwipe'
Config.ResetCommand = 'nuclearreset'

-- Missile model
Config.MissileModel = 'xm_prop_x17_silo_rocket_01'

-- Launch point: offshore / underwater
-- Change these coordinates later to match the exact launch location you want.
Config.LaunchCoords = vec3(3164.41, -4596.79, -61.99)

-- Target: central Los Santos / Legion Square area
Config.TargetCoords = vec3(179.2318, -967.2136, 36.0904)

-- Event timing in seconds
Config.RiseDuration = 14.0
-- Cruise is ~5.5 km. At the old 35 s that was ~157 m/s, which reads as a dart
-- rather than a ballistic missile; 110 s puts it near 50 m/s so it is genuinely
-- watchable and the arc has time to sell itself.
Config.FlightDuration = 110.0
Config.DescentDuration = 16.0
Config.ImpactRadius = 250.0

-- ─── FLIGHT PATH ────────────────────────────────────────────────────────────

-- Apogee above the launch/target line, in metres.
Config.ArcHeight = 900.0

-- GRAVITY TURN. How sharply the missile pitches over from vertical into the
-- ballistic arc: downrange progress is t raised to this power.
--
--   1.0 = constant ground speed. The missile leaves the water vertically and
--         then instantly snaps to a ~33 degree climb -- a visible kink, which
--         is what it was doing.
--   2.0 = default. Downrange speed is ZERO at the moment of launch, so the
--         cruise begins pointing exactly where the rise left off (straight up)
--         and tips over gradually as it gains altitude. This is how a real
--         launch behaves: vertical off the pad, then a slow arc downrange.
--   3.0 = holds vertical longer, then turns harder.
Config.PitchOverPower = 2.0

-- The cruise ends HERE rather than at the target -- directly above it, at this
-- altitude -- and the descent runs from this point down. Previously the cruise
-- ended exactly on the target and the descent then interpolated the target to
-- itself, so the missile hung motionless over the city for the whole descent.
Config.ApproachAltitude = 420.0

-- NOTE: Config.MissilePitchOffset is gone. Orientation is now built from the
-- flight direction as a quaternion (see pointMissileAt in client.lua), which
-- puts the model's nose on the flight vector directly -- there is no euler
-- offset left to get wrong, and it is what allows a true spin about the
-- missile's own length.

-- Missile visual tuning
Config.MissileScale = 1.0

-- ─── EXHAUST ────────────────────────────────────────────────────────────────

-- Particles attached to the missile's tail. Tried in order; each entry that
-- produces a handle is kept, so listing several gives fire AND smoke together.
-- An effect this build does not have is skipped rather than erroring.
--
-- offsetZ is RELATIVE TO THE MEASURED TAIL, not to the model origin.
--
-- client.lua reads the model's bounding box at spawn and finds the real engine
-- bell, so 0 means "exactly at the bell" and negative trails further behind it.
-- Two earlier passes hardcoded this and both missed, because this prop's origin
-- sits near the nose rather than mid-body -- measuring removes the guess.
--
-- rotX defaults to 180, which turns the emitter to fire BACK along the missile.
-- Without it these effects spray along their own +Z, which is world-up once the
-- missile pitches over -- the plume climbing skyward rather than trailing.
-- `colour` tints a looped particle after it starts (SetParticleFxLoopedColour).
-- This is the reliable way to get black smoke and an orange flame: it works on
-- whatever effect this build actually has, instead of depending on a specific
-- ptfx name existing. `alpha` is applied the same way.
Config.TrailEffects = {
    -- FLAME at the bell: the same trail effect as the smoke, tinted hot orange
    -- and held small and tight. Two earlier attempts used dedicated fire
    -- effects that either are absent on this build or were invisible at size --
    -- tinting one we KNOW loads removes that failure mode entirely.
    { asset = 'core', name = 'exp_grd_rpg_trail', offsetZ =  0.3, scale = 1.6,
      colour = { 255, 140, 20 }, alpha = 1.0 },
    { asset = 'core', name = 'exp_grd_rpg_trail', offsetZ =  0.0, scale = 1.0,
      colour = { 255, 235, 140 }, alpha = 1.0 },   -- white-hot inner core

    -- Real fire effects too, if this build has them. Additive with the above.
    { asset = 'core', name = 'veh_exhaust_afterburner',    offsetZ = 0.2, scale = 3.0 },
    { asset = 'core', name = 'fire_wrecked_plane_cockpit', offsetZ = 0.0, scale = 3.0 },

    -- BLACK SMOKE trailing behind the flame. The effect renders pale by
    -- default, hence the near-black tint and the much larger scale.
    { asset = 'core', name = 'exp_grd_rpg_trail',   offsetZ = -1.0, scale = 7.0,
      colour = { 18, 18, 18 }, alpha = 1.0 },
    { asset = 'core', name = 'exp_grd_bzgas_smoke', offsetZ = -2.5, scale = 6.0,
      colour = { 10, 10, 10 }, alpha = 0.9 },

    -- The thick BLACK plume from the first version. It was dropped for drifting
    -- upward -- that was chimney buoyancy plus the emitter facing world-up. The
    -- rotX 180 applied to every effect now points it back along the missile, so
    -- the look is back without the climb.
    { asset = 'core', name = 'ent_amb_smoke_foundry', offsetZ = -3.5, scale = 8.0,
      colour = { 14, 14, 14 }, alpha = 1.0 },
}

-- ─── RIDER ──────────────────────────────────────────────────────────────────

-- A ped strapped to the missile for the ride down.
Config.Rider = {
    enabled = true,
    model = 'a_c_rat',

    -- Offset in the MISSILE's local space. Z runs along the rocket's length
    -- (nose is +Z), so `alongBody` is measured from the nose backwards and
    -- resolved against the model's real measured bounds at spawn -- the same
    -- way the exhaust is placed, rather than hardcoding a figure that only
    -- suits this one prop.
    alongBody = 2.0,   -- metres back from the nose
    sideways = 0.0,    -- + / - across the body
    lift = 0.55,       -- clear of the hull, so it sits ON the skin not inside it

    -- Rotation within the missile's local space. The rocket's long axis is its
    -- +Z, but a ped's own "up" is +Z too -- so without pitching it 90 degrees
    -- the rat would stand perpendicular, sticking straight out of the fuselage.
    -- This lays it along the body facing the nose.
    rotation = vec3(-90.0, 0.0, 0.0),

    -- It rides all the way in and is destroyed with the missile on impact.
    -- There is no survival path and no ragdoll: it is attached, not simulated.
}

-- ─── SPIN ───────────────────────────────────────────────────────────────────

-- Roll the missile about its own axis once it clears the water, the way a real
-- one spins for stability.
Config.Spin = {
    enabled = true,
    startHeight = 10.0,   -- world Z at which it begins (sea level is 0)
    speed = 120.0,        -- degrees per second
    rampSeconds = 3.0,    -- eased in over this long, so it does not snap on

    -- (The old `axis` switch is gone: the roll is now applied about the
    -- missile's own length directly, so there is nothing to choose between.)
}


Config.TrailFallbacks = {
    { asset = 'core', name = 'exp_grd_grenadelauncher_smoke', offsetZ = -0.5, scale = 3.0 },
    { asset = 'core', name = 'ent_sht_steam',                 offsetZ = -0.5, scale = 3.0 },
}

-- Aftermath
Config.AftermathWeather = 'HALLOWEEN'
Config.AftermathTime = 0 -- 00:00
Config.AftermathDuration = 300 -- 5 minutes

-- Player effects
Config.PlayerDamage = 35
Config.PlayerEffectRadius = 250.0
Config.PlayerRagdollRadius = 100.0
Config.ShakeDuration = 12000

-- Explosion tuning. Multiple explosions/effects make it feel much larger than
-- a single GTA explosion.
Config.ExplosionType = 29
Config.ExplosionDamageScale = 3.0
Config.ExplosionAudible = true
Config.ExplosionInvisible = false

-- Set false while testing if you only want to see the missile.
Config.EnableGlobalWeather = true
Config.EnablePlayerEffects = true
Config.EnableExplosion = true
Config.EnableFireRing = true

-- Debug messages
Config.Debug = true
