VLPanel = {}

-- =============================================================================
-- WHAT THIS IS
--
-- One resource, four systems that used to be four separate resources
-- (vl_blackout, vl_alert, vl_airraid), all merged in here plus the panel
-- itself, controlled from one NUI:
--
--   Blackout     was vl_blackout       -- VLBlackout below
--   Alert        was vl_alert          -- VLAlertConfig below
--   Pager Alert  was vl_alert's pager commands, same file
--   Air Raid     was vl_airraid        -- VLAirRaid below
--
-- Merged, not reimplemented: every one of those systems' actual client and
-- server logic was moved in as-is (client/blackout.lua, client/alert.lua,
-- client/airraid.lua, server/alert.lua, server/airraid.lua, and their NUI),
-- not rewritten from scratch. The three former resources no longer exist on
-- disk -- there is nothing left to "run separately" any more, this one
-- resource is the whole thing.
--
-- The panel's own buttons call ExecuteCommand() with each system's own
-- command (blackouton, vl_alert, pageralert, airraidon...) rather than
-- calling their internal functions directly. That still works exactly the
-- same now that everything lives in one resource -- ExecuteCommand does not
-- care which resource registered a command -- and it means the panel keeps
-- reusing the exact tested command handlers instead of a second code path
-- that could drift from them. The commands themselves still work from
-- console/chat too, unchanged, for anyone who prefers typing them directly.
-- =============================================================================

-- /vl_panel opens/closes the NUI. Anyone can type it -- same as every command
-- below lets anyone type it -- but every single action inside is re-checked
-- server-side against VLPanel.ace before anything runs. Never trust that the
-- client already checked; it is the client's own copy of this panel, and the
-- server is what actually matters.
VLPanel.command = 'vl_panel'

-- ACE object. permissions.cfg already grants `admin` to group.admin, the same
-- object every merged system below already uses, so no server.cfg change is
-- needed for a server already running any of them.
VLPanel.ace = 'admin'

-- Optional convenience keybind to toggle the panel, registered client-side
-- with RegisterKeyMapping so it shows up in FiveM's own keybind settings and
-- players can freely rebind it. Set to false to disable and rely on the
-- command only.
VLPanel.keybind = {
    enabled = true,
    defaultKey = 'F6',
}

-- =============================================================================
-- LIVE PLAYER RADAR
--
-- Drawn over html/gta_map.png -- a grayscale render YOU supplied, not
-- Rockstar's in-game minimap texture (which this file has no business
-- redistributing inside a paid script on your behalf; a render you already
-- have the rights to use is a different question, and yours to answer).
-- The image is not shipped with this resource -- drop your own file in at
-- exactly that path, same as html/civil-defense-siren.mp3 for the air raid
-- siren. Missing entirely, the radar still works, just as a plain grid.
--
-- CALIBRATION -- this is the part worth understanding before trusting it.
-- There is no tool here that maps this specific image's pixels to GTA world
-- coordinates directly, so these four bounds are a least-squares fit against
-- four landmarks: two already trusted in this codebase (the Downtown site and
-- the LSIA zone vertex from VLAirRaid, both below), two from general
-- knowledge of the map (Mount Chiliad summit, Sandy Shores) -- cross-checked
-- against each other and landing within about 1-4% of the image's size at
-- every one of the four, which is the honest error bar on this, not a
-- guarantee. If a player's dot looks off against a landmark you know well in
-- your own copy of the image, nudge these four numbers -- moving worldMinY
-- down (more negative) shifts everything toward the south edge, etc.
-- =============================================================================

VLPanel.radar = {
    mapImage = 'gta_map.png', -- relative to html/; absent = plain grid fallback

    worldMinX = -6137.9,
    worldMaxX =  8095.3,
    worldMinY = -4421.3,
    worldMaxY =  8357.6,

    -- How often the server pushes fresh player positions to an open panel.
    -- Only pushed to admins who actually have the panel open (see
    -- server/panel.lua's watchers set) -- players who never open it cost
    -- nothing.
    pushIntervalMs = 1500,
}

-- =============================================================================
-- BLACKOUT (was vl_blackout)
-- =============================================================================

VLBlackout = {}

-- Prints what the client is doing to the F8 console. Turn this on if the HUD,
-- the sound or the flicker is not behaving, then read the output.
VLBlackout.debug = true

-- =============================================================================
-- COMMAND + PERMISSION
-- =============================================================================

-- /blackouton          -> on for the default duration
-- /blackouton 300      -> on for 300 seconds
-- /blackouton 5m       -> on for 5 minutes
-- /blackoutoff         -> off
VLBlackout.commands = {
    on  = 'blackouton',
    off = 'blackoutoff',
}

-- ACE object required. permissions.cfg already grants `admin` to group.admin,
-- so no server.cfg change is needed. Server console always passes.
VLBlackout.ace = 'admin'

-- =============================================================================
-- DURATION
-- =============================================================================

-- Default length of a manual blackout, in seconds.
-- 180 = 3 minutes, which lines up with the audio cue and the countdown.
VLBlackout.defaultDuration = 180

-- =============================================================================
-- AUTOMATIC BLACKOUTS
-- =============================================================================

VLBlackout.auto = {
    enabled = false,      -- off by default; turn on for random outages
    intervalMinutes = 30, -- how often the server rolls the dice
    chance = 0.3,         -- 0.0-1.0 probability per roll
    minDuration = 300,    -- seconds
    maxDuration = 600,
}

-- =============================================================================
-- LIGHTS
-- =============================================================================

-- How often the blackout re-asserts the lights-out state while it runs, in ms.
-- 0 = every frame, which is what you want.
--
-- SetArtificialLightsState has no owner and no readback, so anything else that
-- touches it brings the city back mid-blackout with nothing left to notice.
-- Re-asserting is the fix -- but re-asserting on an INTERVAL is visible as a
-- flicker: whatever restores the lights gets to keep them on until the next
-- tick, so at 500 you saw a blink twice a second for the whole outage. Every
-- frame closes that window to nothing and the map just stays dark. Two natives
-- a frame is the standard cost for this and is not measurable.
VLBlackout.holdIntervalMs = 0

VLBlackout.lights = {
    -- When true, vehicle headlights also die during the blackout. Leaving this
    -- false keeps cars usable, which is the usual choice -- a total blackout
    -- with no vehicle lights is genuinely unplayable at night.
    affectVehicles = false,
}

-- =============================================================================
-- DOORS
--
-- ox_doorlock doors that unlock for the duration of a blackout (power to the
-- electronic lock is out) and relock the moment it ends. Matched by name via
-- ox_doorlock's own getDoorFromName export, not a hardcoded row id, so this
-- keeps working if the door is ever deleted and re-created in ox_doorlock's
-- admin tool (which assigns a new id).
-- =============================================================================

VLBlackout.doors = {
    'bunker exit door',
}

-- =============================================================================
-- FLICKER
-- =============================================================================

-- The lights stutter a few times before dropping for good. The countdown, the
-- notification and the audio cue all wait until the flicker has finished, so
-- the whole sequence reads as one power failure instead of two events.
VLBlackout.flicker = {
    enabled = true,

    -- Walked in order, one row at a time, and then the lights drop for good.
    --   dark = how long the lights stay out, in ms
    --   lit  = how long they come back up before the next hit, in ms
    -- Set either to 0 to skip that half of a row.
    sequence = {
        { dark = 500, lit = 400 },   -- opening cut, then the power staggers back
        { dark = 70,  lit = 110 },   -- flick 1
        { dark = 70,  lit = 110 },   -- flick 2
    },

    -- Total here is ~1.26s before the blackout settles. Add or remove rows to
    -- change the number of flicks; there is no count to keep in sync.
    --
    -- Keep every non-zero value above ~35ms. Wait() resolves on frame
    -- boundaries, so anything shorter is two frames or fewer at 30fps and
    -- starts landing differently for players on lower-end machines.
}

-- =============================================================================
-- UNSTABLE GRID
-- =============================================================================

-- After the blackout lands, the grid keeps fighting for a while: random bursts
-- of flicks and the occasional brief recovery, all on top of the countdown.
-- Once this finishes the blackout is silent and total for the rest of the timer.
--
-- RE-ENABLED 2026-09-01: this is the phase that runs while blackout.mp3 plays,
-- and followSound below ends it on the exact moment the track finishes -- which
-- is the "flicker until the mp3 completes, then cut" behaviour that was asked
-- for. It was briefly disabled while chasing the lights-stay-on bug; that bug
-- was the missing hold below, not this.
--
-- Set enabled = false if you would rather the map go dark immediately after the
-- opening flicker sequence, with no grid-fighting during the audio at all.
VLBlackout.unstable = {
    enabled = true,

    -- Stop when the audio cue finishes. The NUI reports the exact moment the
    -- track ends, so this self-adjusts if you swap blackout.mp3 for a longer or
    -- shorter one -- no need to hardcode its length anywhere.
    followSound = true,

    -- Hard cap, and the fallback when followSound is off, when the sound is
    -- disabled, or if the browser never fires its ended event. Also stops the
    -- effect overrunning a blackout that is shorter than the track.
    maxSeconds = 30,

    -- Quiet darkness between events, randomised in this range (ms).
    gapMs = { min = 1500, max = 5000 },

    -- Timing inside a burst. During a blackout the lights are already out, so
    -- a "flick" is a brief snap back ON, the inverse of the opening sequence.
    flashMs    = 110,   -- how long the lights come back for, per flick
    burstGapMs = 90,    -- darkness between flicks within one burst

    -- One row is picked at random per event, proportional to weight. Add rows
    -- or change weights to taste; weights do not need to sum to anything.
    events = {
        { weight = 3, flicks = 2 },        -- two quick flicks
        { weight = 3, flicks = 3 },        -- three quick flicks
        { weight = 2, restoreMs = 2000 },  -- power holds for 2s, then dies again
    },
}

-- =============================================================================
-- SOUND
-- =============================================================================

VLBlackout.sound = {
    enabled = true,
    file = 'blackout.mp3',
    volume = 0.6,         -- 0.0-1.0

    -- The cue plays ONCE at the start of the blackout and then stops; the
    -- countdown keeps running in silence for the rest of it.
    --
    -- This is only a safety cap, in seconds: a track longer than this gets
    -- faded out rather than running past it. Your current blackout.mp3 is ~20s,
    -- so it simply ends on its own and this never fires. It also stops early if
    -- the blackout is ended before the track finishes.
    durationSeconds = 180,

    fadeInSeconds = 2,
    fadeOutSeconds = 4,
}

-- =============================================================================
-- COUNTDOWN
-- =============================================================================

VLBlackout.timer = {
    -- The top-middle label + countdown banner is off: the remaining time is
    -- now shown as a small timer above vl_hud's power icon instead (see
    -- vl_hud/client/main.lua's blackoutRemainingSeconds). Audio and lighting
    -- are untouched by this -- they don't read this table.
    enabled = false,
    label = 'POWER RESTORED IN',

    -- Seconds remaining at which the timer starts pulsing harder.
    urgentAt = 30,
}

-- =============================================================================
-- AIR RAID (was vl_airraid)
-- =============================================================================

VLAirRaid = {}

-- Prints the NUI page's own "I loaded" / "the mp3 failed to decode" reports to
-- the F8 console. Turn this off once the mp3 is in place and confirmed
-- working; leave it on until then, since a missing audio file is silent
-- otherwise -- the commands still print success, nothing ever plays.
VLAirRaid.debug = true

-- =============================================================================
-- COMMAND + PERMISSION
-- =============================================================================

-- /airraidon   -> starts the siren at every site, runs until stopped
-- /airraidoff  -> stops it
VLAirRaid.commands = {
    on  = 'airraidon',
    off = 'airraidoff',
}

-- "Sirens start randomly one by one" -- on /airraidon the server shuffles
-- every site into a random order and staggers them this many ms apart, so the
-- first site sounds immediately, the next one cascadeIntervalMs later, and so
-- on until every site has kicked in (currently 13 sites * 3s = 36s rollout;
-- always (#VLAirRaid.sites - 1) * cascadeIntervalMs, recomputes on its own if
-- sites are added or removed).
-- A site that has not reached its turn yet stays completely silent even if
-- you are standing right on top of it -- see server/main.lua's rollCascade()
-- and client/main.lua's per-site delay check.
VLAirRaid.cascadeIntervalMs = 3000

-- ACE object required. permissions.cfg already grants `admin` to group.admin,
-- so no server.cfg change is needed. Server console always passes.
VLAirRaid.ace = 'admin'

-- =============================================================================
-- SITES
--
-- Fixed siren locations, world coords. `heading` is carried through but not
-- currently used by the audio (a siren is a point source, not directional)
-- or by the blip (a radius blip has no facing) -- it is here so a future siren
-- tower prop has a rotation to spawn with, instead of every site needing to be
-- re-surveyed.
-- =============================================================================

---@class VLAirRaidSite
---@field x number
---@field y number
---@field z number
---@field heading number

-- Replaced wholesale with 13 supplied sites (was 15). These are used EXACTLY as
-- given -- no site was dropped, merged or re-surveyed.
--
-- Spacing, measured rather than assumed: 12 of the 13 sit 595m-1.5km from
-- their nearest neighbour, which is comfortably inside the range the audio
-- falloff is tuned for. The one exception is worth knowing about:
--
--   (-547.8, -2232.6) and (-271.8, -2427.9) are 338m apart.
--
-- That is below the ~550m floor the earlier site list was cleaned up to, and
-- 338m is close enough that the two read as one stuttering source rather than
-- two distinct sirens -- the exact "mix between two sirens" symptom that
-- removing near-duplicates fixed last time. It is left in place because these
-- coordinates were given deliberately; say the word and either one can go.
--
-- Cascade rollout is (#sites - 1) * cascadeIntervalMs, so 12 * 3s = 36s for
-- every siren to be up (was 42s at 15 sites). Nothing to change -- the server
-- recomputes it from the length of this table.
---@type VLAirRaidSite[]
VLAirRaid.sites = {
    { x =  -1270.7969, y =  -2451.2053, z =  78.3059, heading = 349.1154 },
    { x =  -1048.8839, y =  -3389.3066, z =  43.4403, heading = 133.3186 },
    { x =   -547.8412, y =  -2232.6152, z = 126.9625, heading = 329.5002 },
    { x =   -271.8173, y =  -2427.9231, z = 127.3954, heading = 318.2792 },
    { x =    944.8209, y =  -3238.0959, z =  33.4346, heading = 238.9492 },
    { x =    870.8409, y =  -1928.0253, z =  97.6269, heading =  20.7994 },
    { x =    333.1779, y =  -1641.5951, z = 101.9160, heading = 280.7993 },
    { x =   -659.8082, y =  -1103.6904, z =  66.0960, heading = 327.5064 },
    { x =  -1559.8650, y =   -572.2016, z = 124.1162, heading = 343.1070 },
    { x =     36.5775, y =   -698.5074, z = 226.0975, heading = 297.2669 },
    { x =    647.2699, y =  -1136.0105, z =  81.8958, heading =  50.6173 },
    { x =    758.6332, y =   1272.8796, z = 447.5274, heading =   1.0113 },
    { x =   -303.0172, y =    201.8205, z = 178.1232, heading =  95.3421 },
}

-- =============================================================================
-- INTRO SEQUENCE
--
-- /airraidon no longer starts the sirens immediately. It runs a scripted
-- warning first, so the raid arrives as an escalation rather than a noise:
--
--   0s      pager alert        "EMERGENCY -- Evacuate immediately to the NORTH"
--                              (af-pager, via the same /pageralert command the
--                              panel button uses)
--   30s     radio transmission the af-expeditions broadcast panel + its sting
--   35s     blackout           the city goes dark, mid-transmission
--   37s     intruder alarm     at the outposts below, 3D positional, x2
--   ~43.6s  (alarm ends)       37s + plays * clipMs -- see intruderAudio
--   ~47.6s  sirens             4s of silence after the alarm, then the cascade
--
-- Only the pager and the transmission have fixed, deliberate spacing (30s).
-- Everything after hangs off the transmission and keeps its relative gaps, so
-- moving `radio.delayMs` alone leaves the tail bunched at the old times --
-- shift the three below with it.
--
-- Every step is a separate delay so the pacing can be retimed without touching
-- code. Set any `text` to false to skip that step entirely.
-- =============================================================================

VLAirRaid.intro = {
    enabled = true,

    -- Step 1. Routed through the existing /pageralert command rather than
    -- calling af-pager directly, so it inherits exactly the delivery rules
    -- (antenna range, who owns a pager) the panel button already has.
    pager = {
        title = 'EMERGENCY',
        text = 'Evacuate immediately to the NORTH',
        delayMs = 0,
    },

    -- Step 2. The af-expeditions radio broadcast -- a bottom-centre CRT panel
    -- with a tower icon, a wide-tracked channel line and typewriter text.
    -- NOT vl_alert's Vault-13 transmission: that one is full-screen and takes
    -- over, which is wrong for something the player should be reading while
    -- already running.
    radio = {
        channel = 'EMERGENCY BROADCAST',
        text = 'An unknown danger has been detected in the city streets. '
            .. 'Evacuate immediately for your safety. '
            .. 'Failure to evacuate may result in total death.',

        -- Played from af-expeditions rather than copied in: nui:// can read any
        -- file another resource lists in its files{} block, and it publishes
        -- web/build/** wholesale. Set to false for a silent transmission.
        sound = 'nui://af-expeditions/web/build/sounds/radio.mp3',
        volume = 0.7,

        -- How long the panel stays up, and how fast the text types itself in.
        holdMs = 12000,
        typeMs = 28,

        -- 30s after the pager. The pager is a nudge to look at something; the
        -- transmission is the thing worth reading. Half a minute between them
        -- is what makes the second land as an escalation rather than as more
        -- of the same alert.
        delayMs = 30000,
    },

    -- Step 3. A PLAIN full blackout -- the lights go out and stay out until the
    -- raid ends. Nothing else.
    --
    -- Deliberately NOT /blackouton. That command is the panel's blackout
    -- SYSTEM: a "POWER RESTORED IN" countdown HUD, an audio cue, and a
    -- scripted flicker sequence on the way in. All three are wrong here --
    -- the raid already has its own pager, its own transmission and its own
    -- sirens, and a second countdown competing with them reads as a separate
    -- event rather than part of this one. There is also no restore time to
    -- count down to, since the raid has no duration.
    --
    -- So this drives SetArtificialLightsState directly from
    -- client/airraid.lua. vl_blackout is untouched and still does its own
    -- thing when /blackouton is used on its own.
    blackout = {
        -- true also kills vehicle headlights. Left false to match
        -- VLBlackout.lights.affectVehicles, so a city-wide blackout looks the
        -- same however it was triggered.
        affectVehicles = false,

        -- 5s after the transmission starts -- while it is still typing itself
        -- out, so the lights go while the player is mid-sentence.
        delayMs = 35000,
    },

    -- Step 4. See VLAirRaid.outposts below for where.
    intruder = {
        delayMs = 37000,
    },

    -- Step 5. Measured from the END of the outpost alarm -- i.e. after all of
    -- its plays have finished -- not from /airraidon and not from the moment
    -- the alarm started. The server works that out as
    -- intruder.delayMs + (intruderAudio.plays * intruderAudio.clipMs) + this.
    sirenDelayMs = 4000,
}

-- =============================================================================
-- OUTPOSTS
--
-- Where the intruder alarm sounds. Separate from VLAirRaid.sites: the sirens
-- are a city-wide civil-defense network, these are four fixed positions with a
-- different sound and a much shorter reach, so a player only hears one when
-- they are actually near it.
-- =============================================================================

---@type VLAirRaidSite[]
VLAirRaid.outposts = {
    -- NOTE: given as -1823.1465 the first time and 1823.1465 the second. Using
    -- the second (positive) value as supplied. -1823/-1210 is on the west
    -- coast below Chumash; 1823/-1210 is out past Mirror Park toward the east
    -- side -- they are 3.6km apart, so this is worth confirming on the map.
    { x =  1823.1465, y = -1210.0869, z = 28.3209, heading = 320.0019 },
    { x =   231.7196, y =  -781.7037, z = 45.3084, heading = 162.2858 },
    { x =   456.9056, y =  -800.4337, z = 33.5097, heading =   2.4037 },
    { x =  -567.5539, y =  -161.4382, z = 44.0810, heading =  22.7188 },
}

VLAirRaid.intruderAudio = {
    -- NOT SHIPPED -- drop your own file in at exactly this path. Missing, the
    -- alarm is simply silent: the NUI's buffer load fails and the voice is
    -- discarded, nothing errors. Same arrangement as civil-defense-siren.mp3
    -- and html/gta_map.png.
    file = 'intruder.mp3',

    volume = 0.55,

    -- Deliberately much tighter than the sirens (120m ref / ~10x range). An
    -- outpost alarm is a local warning, not a civic one -- if it carried as far
    -- as a siren the two would smear into each other across the whole map.
    refDistance = 35.0,
    maxDistance = 220.0,
    rolloffFactor = 1.4,
    distanceModel = 'inverse',

    fadeInMs = 900,
    fadeOutMs = 1500,

    -- How many times the clip plays at each outpost, then silence.
    plays = 2,

    -- Length of ONE play, in ms.
    --
    -- This has to be configured rather than measured: intruder.mp3 is a file
    -- you supply, so nothing on the server knows its duration, and the sirens
    -- have to start at the SAME INSTANT for every player -- which means the
    -- server schedules them, and the server cannot ask a browser how long a
    -- buffer is. The alarm window is therefore `plays * clipMs`, and the
    -- 4-second wait is measured from the end of it.
    --
    -- SET THIS TO YOUR FILE'S ACTUAL LENGTH. Too short and the sirens start
    -- over the tail of the alarm; too long and there is dead air before them.
    --
    -- 3312 is the MEASURED length of the intruder.mp3 currently in html/ --
    -- 138 MPEG-2 Layer III frames at 160kbps / 24kHz, 576 samples each. If you
    -- replace that file, re-measure; do not assume a round number.
    clipMs = 3312,
}

-- =============================================================================
-- AUDIO
--
-- Real 3D positioning (Web Audio PannerNode, HRTF) rather than the game's own
-- native audio, done in the NUI page (html/app.js) for two reasons: it is the
-- only way to get a smooth, scriptable fade envelope (GTA's native audio has
-- no gain ramp), and Web Audio's AudioListener orientation is driven straight
-- off the camera every tick, which IS head-tracking -- turn your head, the
-- siren pans across your ears in real time, exactly like a real one would.
-- =============================================================================

VLAirRaid.audio = {
    file = 'civil-defense-siren.mp3',

    -- Per-site gain, 0.0-1.0, before distance falloff, before masterVolume,
    -- before the NUI's limiter. Raised back up from an earlier, more
    -- conservative 0.4: that cut was compensating for two actual bugs (the
    -- 'linear' falloff below barely attenuating anything nearby, and four
    -- sites sitting close enough to double up -- both fixed now), not for
    -- this number being wrong. Standing right next to a real air raid siren
    -- is genuinely loud; 0.4 was underselling that once the real problems
    -- were gone.
    volume = 0.75,

    -- Overall trim, applied ONCE on the NUI's master bus after every voice's
    -- own gain -- the single number to turn the whole thing up or down,
    -- rather than re-balancing 15 individual site volumes.
    masterVolume = 0.7,

    fadeInMs = 2500,  -- a real civil defense siren winds UP into its wail slowly
    fadeOutMs = 1800, -- and drops off a bit faster once cut

    -- Web Audio's own PannerNode distance model, used AS THE distance falloff.
    --
    -- NOT 'linear' any more -- that was the actual cause of "still too loud"
    -- and "a mix between two sirens", more than any volume number was. Linear
    -- interpolates STRAIGHT from full volume at refDistance to zero at
    -- maxDistance, which sounds fine on paper but is not how sound in air
    -- actually behaves: over a long span (refDistance 120m to maxDistance
    -- 2400m) it barely attenuates over the first several hundred metres --
    -- at 600m from a site it was still around 79% of full volume. So every
    -- site within a few hundred metres of another sounded almost EQUALLY
    -- loud, which reads as several full-strength sirens fighting each other
    -- rather than one near, dominant siren and others fading into the
    -- background.
    --
    -- 'inverse' is the physically correct model (real point-source sound
    -- follows an inverse-distance law -- this is the same shape as the real
    -- thing, not an approximation of it): steep drop-off close to the source,
    -- long gentle tail at range that never quite hits a hard wall until
    -- maxDistance. With refDistance=120 and rolloffFactor=1.3: full at 120m,
    -- ~42% at 250m, ~20% at 500m, ~10% at 1000m, ~5% at 2000m. That is "loud
    -- standing next to it, clearly present but well in the background a
    -- couple of sites over" -- the actual brief.
    distanceModel = 'inverse', -- 'linear' | 'inverse' | 'exponential'
    rolloffFactor = 1.3,

    -- Full volume out to this many metres from a site, then the 'inverse'
    -- falloff above takes over out to `refDistance * rangeMultiplier`. Used
    -- to be borrowed from the map blip's own radius (the two happened to
    -- share a number, not a real relationship) -- now its own explicit value,
    -- since the blip below is a citywide zone indicator, not a per-site one,
    -- and the two no longer have anything to do with each other.
    refDistance = 120.0,

    -- Sites sit 595m-1.5km from their nearest neighbour, with one 338m pair
    -- (flagged in the sites list above), so a wide
    -- maxDistance no longer means "several full-strength sirens on top of each
    -- other" the way it did with 'linear' -- 'inverse' has already faded a
    -- neighbouring site to a background presence well before you would ever
    -- reach it walking from the one you are standing at.
    --
    -- Raise this further (e.g. 40-60) to make the sirens carry across most of
    -- the map practically all the time, distant ones as a faint city-wide
    -- ambience; lower it to keep them more localised. One number, no other
    -- tuning needed to change "how far you can hear this" for a single site --
    -- see VLAirRaid.zone below for the SEPARATE, citywide version of the same
    -- question.
    rangeMultiplier = 20,
}

-- =============================================================================
-- ZONE
--
-- "The sirens should only be heard in the area I circled" + "the further I
-- move away from that zone the siren should fade away". Per-site distance
-- falloff (above) still drives which DIRECTION a siren pans from and gives
-- nearby sites their own distinct presence -- that answers "where is this
-- sound coming from". This answers a different question entirely: "is this
-- part of the city under the siren AT ALL right now", independent of which
-- individual site is closest.
--
-- Every active site's overall loudness is multiplied by ONE extra factor,
-- computed from your position against this polygon: 1.0 anywhere inside it
-- (no matter how far you are from the NEAREST site -- the whole marked area
-- reads as "under the siren"), then fading linearly to 0.0 over `fadeDistance`
-- metres as you move out past its edge. That is what makes leaving the zone
-- sound like the city fading behind you, rather than each site just quietly
-- running out of its own individual range.
--
-- The polygon is a BEST-EFFORT trace of the circled screenshot into world
-- coordinates, not a pixel-perfect import -- there is no tool here that maps
-- image pixels to GTA world space, so this is read off known landmarks
-- (Pacific Bluffs, Rockford Hills, Vinewood Hills' southern edge, Tataviam
-- Mountains, Port of Los Santos, LSIA) rather than traced automatically.
-- Drive the actual boundary in-game and nudge any vertex that feels off --
-- each is just an {x, y} pair, in the same order as the outline.
VLAirRaid.zone = {
    -- Clockwise from the NW (Pacific Bluffs) corner, following the drawn
    -- outline: along the northern edge past Richman/Rockford Hills and
    -- Vinewood Hills, east past Tataviam Mountains and Palomino Highlands,
    -- south along East Los Santos, around Port of Los Santos and LSIA at the
    -- southern tip, then back up the west coast through Chumash/Pacific
    -- Bluffs to close the loop.
    polygon = {
        { x = -2900, y =   700 }, -- Pacific Bluffs, NW corner
        { x = -1900, y =   950 }, -- Richman / north Rockford Hills
        { x =  -700, y =   700 }, -- Vinewood Hills, southern edge
        { x =   700, y =   950 }, -- north-east, toward Tataviam Mountains
        { x =  1500, y =   550 }, -- Palomino Highlands
        { x =  1700, y = -1600 }, -- East Los Santos, east border
        { x =  1500, y = -2900 }, -- toward Port of Los Santos
        { x =   700, y = -3300 }, -- Port of Los Santos, south tip
        { x =  -500, y = -3100 }, -- LSIA, south-west
        { x = -1400, y = -2600 }, -- Chumash
        { x = -1900, y = -1200 }, -- west coast, heading north
        { x = -2900, y =     0 }, -- back up toward Pacific Bluffs
    },

    -- How many metres beyond the polygon edge it takes to fade to nothing.
    -- Not the per-site rangeMultiplier's job to answer this -- that controls
    -- one site's own bubble; this controls the whole city's edge.
    fadeDistance = 1500.0,
}

-- =============================================================================
-- MAP BLIP
--
-- ONE blip for the whole zone, not one per site -- once the sirens read as
-- "this part of the city", fifteen little circles would fight the very
-- picture that prompted this (a single outlined area), and would misrepresent
-- the actual shape now that audibility is zone-based rather than per-site.
--
-- `display = 4`: BOTH the minimap and the full map -- reversed from an
-- earlier version of this feature, which deliberately kept it map-only.
-- Confirmed in this exact install (ox_fuel, qbx_ambulancejob both use
-- display=4 for blips that stay on the minimap during normal driving), not
-- guessed from native docs alone.
--
-- The blip is a circle (AddBlipForRadius has no other shape), auto-fitted
-- from VLAirRaid.zone.polygon at runtime -- centred on the polygon's average
-- vertex and sized to reach its farthest corner, so it comfortably covers the
-- zone. This is an APPROXIMATION of the drawn outline, the same way the
-- polygon itself is: GTA blips cannot draw an arbitrary irregular shape, only
-- a circle, so the minimap indicator will show a rounder area than the actual
-- audible zone. Good enough to answer "is a raid on and roughly where", not
-- meant as a precise boundary -- the polygon above is the real boundary.
-- =============================================================================

VLAirRaid.zoneBlip = {
    display = 4, -- both minimap and full map
    colour = 1,  -- red
    alpha = 90,  -- kept low: this circle can cover a large fraction of the minimap
    flashIntervalMs = 500,
}

-- =============================================================================
-- PERFORMANCE
--
-- "Optimized for minimal impact" is two separate cuts, not one:
--   1. Per-siren audio nodes only exist for sites within earshot (maxDistance
--      above) of the player RIGHT NOW -- 13 sites do not mean 13 concurrent
--      decoders. checkIntervalMs is how often that "which sites are in range"
--      set is recomputed; it is cheap (13-point distance check, plus one
--      point-in-polygon test for the zone factor) so it does not need to be
--      fast.
--   2. Listener position/orientation -- what actually needs to feel smooth for
--      head-tracking to read as real-time -- updates far more often
--      (orientationIntervalMs), since that is one SendNUIMessage of numbers,
--      not new audio nodes.
-- =============================================================================

VLAirRaid.performance = {
    checkIntervalMs = 1000,     -- range membership recompute
    orientationIntervalMs = 50, -- listener position/orientation push (20Hz)
}

-- (Old per-site blip config lived here. Replaced by VLAirRaid.zoneBlip above --
-- see its header comment for why one zone blip replaced fifteen site blips.)

-- =============================================================================
-- ALERT (was vl_alert) -- client-visible half. See server/alert_config.lua for
-- the admin allowlist, which stays server-only same as it always did.
-- =============================================================================

VLAlertConfig = {}
VLAlertConfig.EAS = {}

-- Playback volume for the transmission sound (0.0 - 1.0)
VLAlertConfig.EAS.Volume = 1 --(0.2 = 20% Volume)

-- How long a transmission stays fully readable on screen, in milliseconds
-- (this is on top of the short signal-acquisition sequence and the typing reveal)
VLAlertConfig.EAS.Duration = 18000

-- Whether the terminal sound plays on receipt
VLAlertConfig.EAS.SoundEnabled = true

-- Sound file played when a transmission is received (must be listed in __resource.lua)
VLAlertConfig.EAS.SoundFile = 'alert.mp3'

-- Typewriter speed for the message reveal, in milliseconds per character
VLAlertConfig.EAS.TypeSpeed = 19

-- Whether the short "SIGNAL DETECTED / ESTABLISHING CONNECTION / RECEIVING..."
-- acquisition sequence plays before the message is revealed
VLAlertConfig.EAS.Sequence = true

-- Default severity applied to messages sent via the existing commands.
-- One of: 'public', 'notice', 'warning', 'priority', 'emergency'
VLAlertConfig.EAS.Severity = 'emergency'
