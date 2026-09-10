VLHud = {}

-- How often the HUD is refreshed (ms). DayZ status changes slowly, so this does
-- not need to be per-frame.
-- VoidLine: raised 250 -> 400 on 2026-08-31 -- resmon flagged vl_hud as a
-- high-cost resource; this thread computes and pushes several stats every
-- tick (health/hunger/thirst/stamina/needs/armour/temperature/etc), so
-- slowing it cuts real ongoing cost. Still updates 2.5x/sec, plenty for
-- values that only change slowly.
VLHud.refreshMs = 400

-- DayZ has no minimap at all. This is the single biggest change to how the game
-- feels, so it is called out rather than buried.
VLHud.minimap = {
    hide = true,           -- hide the radar entirely
    showInVehicle = false, -- gone in vehicles too -- no minimap anywhere, like DayZ
}

-- Which status icons exist at all.
VLHud.icons = {
    health = true,
    hunger = true,
    thirst = true,
    -- This one draws the BOTTLE glyph in the status row. Off: stamina is still
    -- tracked and still shown by the bar at bottom left, which is controlled by
    -- VLHud.stamina below and is not affected by this toggle.
    stamina = false,
    armour = true,      -- not a DayZ stat; only ever shown when you actually have armour
    temperature = false, -- COSMETIC ONLY: driven by weather/wetness, has no gameplay effect
    mic = true,         -- lights up while you transmit on voice
    noise = true,       -- four bars showing how much sound you are making

    -- Lightning bolt, always on screen. Sits dim while the city has power and
    -- flashes bright red for the duration of a blackout. Driven by
    -- GlobalState.blackout, which vl_blackout owns -- with that resource
    -- stopped the key never appears and the icon just stays in its idle state.
    power = true,

    -- Warning triangle, always on screen. Blinks fast and red while anything
    -- is actively hunting you. See VLHud.threat below for the sources.
    threat = true,

    -- Basic needs (from the basic_needs resource). Read defensively: if that
    -- resource is absent these three simply report "fine" and never appear
    -- as a problem, so vl_hud does not depend on it being installed.
    sleep = true,
    poop = true,
    pee = true,
}

-- Threat detection. The icon is lit while ANY registered source is live; see
-- client/threat.lua for how to add one from another resource.
VLHud.threat = {
    -- One-shot signals (took a hit, a countdown expired) hold the icon this
    -- long after the last event, so a burst of fire reads as one continuous
    -- threat rather than a stutter.
    holdMs = 6000,

    -- Sustained signals heartbeat while the threat lasts. Miss beats for this
    -- long and the source is treated as clear. Sized against vl_combat_drone's
    -- 1000ms warning heartbeat, so one dropped beat does not clear the icon.
    staleMs = 2500,

    -- How close a drone running its alert siren has to be to count as YOUR
    -- threat, in metres. Without a distance filter the siren is a server-wide
    -- broadcast and every player would light up whenever anyone was hunted.
    droneAlertRadius = 90.0,

    sources = {
        -- vl_combat_drone. Works off the events that resource already sends,
        -- so nothing in it needs changing. Set false to ignore drones.
        combatDrone = true,

        -- vl_airraid. Reads GlobalState.airraid directly, same as the power
        -- icon reads GlobalState.blackout -- city-wide, not distance-filtered,
        -- since an air raid siren is dramatic precisely because the whole
        -- city is meant to feel it, not just whoever is standing under a
        -- speaker right now. Set false to leave the danger icon alone during
        -- a raid.
        airRaid = true,
    },
}

-- Voice + noise refresh far faster than survival status, since both change in
-- an instant and would look broken at the slower tick.
-- VoidLine: raised 100 -> 200 on 2026-08-31, same resmon-driven pass as
-- refreshMs above. Still 5x/sec -- talking/breath/weapon state won't read as
-- laggy, just slightly less silky than 10x/sec.
VLHud.liveRefreshMs = 200

-- How loud each action is, 1 (quietest) to 4 (loudest). Evaluated top-down:
-- the first match wins, so shooting always beats movement.
VLHud.noiseLevels = {
    shooting = 4,
    sprinting = 3,
    running = 3,
    walking = 2,
    standing = 1,
    stealth = 1,  -- crouch-walking is as quiet as standing still
    inVehicle = 3,
}

-- Status thresholds (percent).
VLHud.thresholds = {
    fine     = 70, -- above this: bone white
    warning  = 55, -- yellow
    danger   = 35, -- amber
    critical = 18, -- red
    flash    = 5,  -- at or below this the icon fades slowly in and out
}

-- Icons show their level as a bottom-up fill, drawn inset from the outline so
-- both stay readable. Set false for outline-only.
VLHud.iconFill = true

-- Only used when iconFill is true: at or above this percent the fill is dropped.
-- Set above 100 so it never triggers -- the level is always shown, and a full
-- stat reads as a completely filled icon.
VLHud.fillHiddenAt = 101

-- Icons stay on screen permanently and only change colour. Set false for the
-- stricter DayZ behaviour where a healthy stat vanishes entirely and an empty
-- screen means "you're fine".
VLHud.alwaysShow = true

-- Stamina bar, bottom left, next to the runner icon.
VLHud.stamina = {
    alwaysShow = true,     -- false = only appears while stamina is being spent
    hideAbovePercent = 98, -- used only when alwaysShow is false
}

-- DayZ-style vehicle dashboard: two needle gauges (speed / rpm) with small fuel
-- and temperature dials between them. Only drawn while driving.
VLHud.vehicle = {
    enabled = true,
    useMph = false,
    maxSpeed = 200,   -- gauge full-scale, in the unit above
    maxRpm = 80,      -- full-scale for the r/min readout (shown as rpm x100, like DayZ)
    driverOnly = true, -- passengers don't get a dashboard

    -- Dashboard appears only once you are in a vehicle. Set true to keep the
    -- gauges up on foot as well (the speed needle then tracks your own
    -- movement and the other dials sit at zero).
    alwaysShow = false,

    -- GTA exposes no coolant temperature, so the temperature dial is driven by
    -- engine health instead: a healthy engine reads cold, a wrecked one reads
    -- hot. It is an honest proxy, not a real thermometer.
    temperatureFromEngineHealth = true,
}

-- Breath bar. Appears directly above the stamina bar the moment the player goes
-- under, and slides away again on surfacing.
--
-- The air supply is read from the game, not tracked here: GTA reports only
-- "seconds of air left", and the ceiling moves -- qbx_divegear raises it to
-- 2000s with a tank equipped and drops it to 1s without. So the maximum is
-- OBSERVED (resampled while the player is above water, when the lungs are full)
-- rather than assumed, and the bar reads correctly with or without dive gear.
VLHud.breath = {
    enabled = true,

    -- false: the bar exists only while actually submerged, which is the DayZ
    -- reading -- at the surface you are breathing, so there is nothing to show.
    -- true: it also stays up while swimming on the surface, sitting full.
    showWhileSwimming = false,

    lowPercent = 35,      -- bar turns amber at or below this
    criticalPercent = 15, -- red, and pulsing
}

-- Weapon readout. Sits above the breath bar, at the top of the bottom-left
-- stack: gun icon, rounds loaded, and a durability bar drawn exactly like the
-- stamina bar below it.
--
-- Everything here comes from ox_inventory -- the equipped item, its durability
-- and its magazine. With that resource stopped the widget simply never appears
-- rather than showing wrong numbers.
VLHud.weapon = {
    enabled = true,

    -- The vehicle dashboard occupies this same corner, so the widget stands
    -- down while driving rather than drawing on top of the gauges.
    hideInVehicle = true,

    -- Show reserve rounds carried in the inventory after the loaded count,
    -- as "12 / 84". Off shows just the magazine.
    showReserve = true,

    -- Magazine is at or below this many rounds: the count turns amber.
    lowAmmo = 5,

    -- Durability bar colours, matching the stamina bar's own low state.
    lowDurability = 25,
}
