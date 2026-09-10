-- ════════════════════════════════════════════════════════════════════════════
--  BLOOD ORANGE  —  timecycle preset definition
-- ════════════════════════════════════════════════════════════════════════════
--  This is the preset itself: the same content a timecycle_mods_*.xml modifier
--  would hold, expressed as a table so it can be built at runtime with
--  CreateTimecycleModifier / SetTimecycleModifierVar. Runtime creation is used
--  instead of a streamed XML because it cannot be broken by client cache, and
--  every variable name is validated against the running game before it is set
--  (see client/main.lua), so an unknown name is skipped instead of erroring.
--
--  Each entry is { value, value } -- the two floats a timecycle var carries.
--  Colours are linear 0.0-1.0 unless the var is an HDR/intensity multiplier.
--
--  Alternative names: some builds spell an intensity var differently. Listing
--  several keys that mean the same thing is harmless -- whichever one the game
--  actually knows gets applied, the rest are skipped.
-- ════════════════════════════════════════════════════════════════════════════

BO.PresetName = 'bloodorange'
BO.PresetDesc = 'Blood Orange apocalypse'

BO.Preset = {

    -- ── SKY DOME ────────────────────────────────────────────────────────────
    -- No blue anywhere: zenith burns deep red, horizon burns bright orange.
    sky_zenith_col_r                  = 0.760,
    sky_zenith_col_g                  = 0.400,
    sky_zenith_col_b                  = 0.215,
    sky_zenith_transition_col_r       = 0.820,
    sky_zenith_transition_col_g       = 0.470,
    sky_zenith_transition_col_b       = 0.270,
    sky_zenith_transition_position    = 0.700,
    sky_zenith_transition_east_blend  = 1.000,
    sky_zenith_transition_west_blend  = 1.000,

    sky_azimuth_east_col_r            = 0.870,
    sky_azimuth_east_col_g            = 0.530,
    sky_azimuth_east_col_b            = 0.320,
    sky_azimuth_west_col_r            = 0.860,
    sky_azimuth_west_col_g            = 0.510,
    sky_azimuth_west_col_b            = 0.300,
    sky_azimuth_transition_col_r      = 0.880,
    sky_azimuth_transition_col_g      = 0.550,
    sky_azimuth_transition_col_b      = 0.340,
    sky_azimuth_transition_position   = 0.150,

    sky_hdr                           = 1.250,
    sky_plane_r                   = 0.800,
    sky_plane_g                   = 0.470,
    sky_plane_b                   = 0.270,
    sky_plane_inten                   = 1.000,

    -- ── SUN ────────────────────────────────────────────────────────────────
    -- Wide, low-contrast disc smeared through the dust: a glow, not a sun.
    sky_sun_col_r                     = 0.860,
    sky_sun_col_g                     = 0.560,
    sky_sun_col_b                     = 0.340,
    sky_sun_disc_col_r                = 0.850,
    sky_sun_disc_col_g                = 0.540,
    sky_sun_disc_col_b                = 0.330,
    sky_sun_disc_size                 = 0.030,
    sky_sun_hdr                       = 0.200,
    sky_sun_miephase                  = 0.280,
    sky_sun_miescatter                = 0.030,
    sky_sun_mie_intensity_mult        = 0.100,
    sky_sun_influence_radius          = 1.000,
    sky_sun_scatter_inten             = 0.400,
    lensflare_visibility              = 0.000,
    Lensflare_visibility              = 0.000,

    -- ── MOON (night keeps the same cast) ───────────────────────────────────
    sky_moon_col_r                    = 0.900,
    sky_moon_col_g                    = 0.280,
    sky_moon_col_b                    = 0.090,
    sky_moon_disc_size                = 0.060,
    sky_moon_iten                     = 0.700,

    -- ── CLOUDS ─────────────────────────────────────────────────────────────
    -- Kept thin and burnt so they never break the orange field.
    sky_cloud_mid_col_r    = 0.450,
    sky_cloud_mid_col_g    = 0.110,
    sky_cloud_mid_col_b    = 0.030,
    sky_cloud_mid_col_r               = 0.780,
    sky_cloud_mid_col_g               = 0.240,
    sky_cloud_mid_col_b               = 0.070,
    sky_cloud_shadow_strength         = 1.000,
    sky_cloud_density_mult            = 0.300,
    sky_cloud_density_bias            = -0.250,
    sky_cloud_base_strength           = 0.100,
    sky_cloud_edge_strength           = 0.300,
    sky_cloud_fadeout                 = 0.700,
    sky_cloud_hdr                     = 0.300,
    sky_small_cloud_col_r             = 0.700,
    sky_small_cloud_col_g             = 0.200,
    sky_small_cloud_col_b             = 0.060,
    sky_small_cloud_density_mult      = 0.250,

    -- ── FOG / DISTANCE HAZE ────────────────────────────────────────────────
    -- The core of the look. Dense, glowing, orange, starting almost at the
    -- camera so mid-distance geometry collapses into flat silhouettes.
    fog_col_r                         = 0.820,
    fog_col_g                         = 0.470,
    fog_col_b                         = 0.265,
    fog_near_col_r                    = 0.870,
    fog_near_col_g                    = 0.520,
    fog_near_col_b                    = 0.300,
    fog_density                       = 1.000,
    fog_falloff                       = 1.000,
    fog_start                         = 0.000,
    fog_hdr                           = 1.450,
    fog_alpha                         = 1.000,
    fog_horizon_tint_scale            = 1.000,
    fog_base_height            = 1.000,
    fog_shape_bottom                  = -600.000,
    fog_shape_top                     = 2600.000,
    fog_shape_log_10_of_visibility    = 1.342,   -- log10(metres); set via BO.VisibilityMeters
    fog_shadow_amount                 = 0.000,
    fog_shadow_falloff                = 0.000,
    fog_shadow_base_height            = 0.000,
    fog_cut_off                       = 1.000,

    fog_haze_col_r                    = 0.870,
    fog_haze_col_g                    = 0.520,
    fog_haze_col_b                    = 0.300,
    fog_haze_density                  = 1.000,
    fog_haze_alpha                    = 1.000,
    fog_haze_hdr                      = 1.450,
    fog_haze_start                    = 0.000,

    -- Far plane kept high on purpose: a clip plane draws nothing, so using it to
    -- limit sight gives a hard black band, not mist. The fog does the limiting.
    far_clip                          = 1600.000,  -- NOT the visibility lever, see main.lua

    -- ── DIRECTIONAL + AMBIENT LIGHT ────────────────────────────────────────
    -- Strong orange key, crushed ambient: terrain, trees and buildings read as
    -- dark reddish shapes rather than lit surfaces.
    light_dir_col_r                   = 0.880,
    light_dir_col_g                   = 0.560,
    light_dir_col_b                   = 0.340,
    light_dir_mult                    = 0.400,

    light_amb_down_wrap               = 1.000,
    light_natural_amb_down_col_r              = 0.820,
    light_natural_amb_down_col_g              = 0.500,
    light_natural_amb_down_col_b              = 0.300,
    light_natural_amb_down_intensity          = 0.340,
    natural_ambient_multiplier                = 0.350,

    light_natural_amb_up_col_r                = 0.860,
    light_natural_amb_up_col_g                = 0.540,
    light_natural_amb_up_col_b                = 0.330,
    light_natural_amb_up_intensity            = 0.360,
    light_natural_amb_up_intensity_mult       = 0.400,

    -- PED LIGHTING -- deliberately much brighter than the world around it.
    --
    -- These four are the only lighting vars in the game that affect PEDS ONLY,
    -- so raising them makes the player readable without lifting the haze, the
    -- sky or the terrain at all. That matters here because the reason the ped
    -- read as a flat silhouette was the fix for everything else: the sun is
    -- suppressed and ambient is at ~0.34, so there was almost no light landing
    -- on them.
    --
    -- light_amb_occ_mult_ped is lowered rather than raised: it is ambient
    -- OCCLUSION, so less of it means fewer self-shadows crushing the model.
    light_amb_occ_mult_ped            = 0.450,
    ped_light_col_r                   = 0.950,
    ped_light_col_g                   = 0.720,
    ped_light_col_b                   = 0.520,
    ped_light_mult                    = 2.400,
    -- Rim light picks the silhouette's edge out against the haze behind it.
    light_ped_rim_mult                = 1.600,

    -- Warm the artificial/interior light so nothing anywhere reads neutral.
    light_artificial_int_down_col_r   = 1.000,
    light_artificial_int_down_col_g   = 0.520,
    light_artificial_int_down_col_b   = 0.240,
    light_artificial_ext_down_col_r   = 1.000,
    light_artificial_ext_down_col_g   = 0.480,
    light_artificial_ext_down_col_b   = 0.180,

    -- ── SHADOWS / REFLECTIONS ──────────────────────────────────────────────
    dir_shadow_softness               = 3.000,
    reflection_hdr_mult               = 0.500,

    -- ── COLOUR GRADE / POST ────────────────────────────────────────────────
    -- Low exposure (silhouettes), heavy bloom (glowing sky), pushed saturation,
    -- and a full orange gradient so even the shadows carry the cast.
    postfx_exposure                   = -0.550,
    postfx_exposure_min               = -1.000,
    postfx_exposure_max               = 0.100,

    postfx_bright_pass_thresh         = 0.800,
    postfx_bright_pass_thresh_width   = 0.350,
    postfx_intensity_bloom            = 0.250,

    postfx_correct_col_r              = 0.710,  -- #B5651D
    postfx_correct_col_g              = 0.396,
    postfx_correct_col_b              = 0.114,
    postfx_correct_cutoff             = 0.500,
    postfx_desaturation               = 0.120,   -- positive = desaturated. Reference is dusty and muted, not vivid orange.

    postfx_vignetting_intensity       = 0.200,
    postfx_vignetting_radius          = 1.100,
    postfx_vignetting_contrast        = 0.900,
    postfx_vignetting_col_r           = 0.520,
    postfx_vignetting_col_g           = 0.300,
    postfx_vignetting_col_b           = 0.170,

    postfx_grad_top_col_r             = 0.850,
    postfx_grad_top_col_g             = 0.530,
    postfx_grad_top_col_b             = 0.320,
    postfx_grad_middle_col_r          = 0.870,
    postfx_grad_middle_col_g          = 0.560,
    postfx_grad_middle_col_b          = 0.350,
    postfx_grad_bottom_col_r          = 0.800,
    postfx_grad_bottom_col_g          = 0.480,
    postfx_grad_bottom_col_b          = 0.280,
    postfx_grad_midpoint              = 0.500,
    postfx_grad_top_middle_midpoint   = 0.250,
    postfx_grad_middle_bottom_midpoint= 0.750,

    postfx_noise                      = 0.150,
    postfx_noise_size                 = 1.800,
    postfx_scanlineintensity          = 0.000,
    postfx_motionblurlength           = 0.000,

    -- ── MISC ───────────────────────────────────────────────────────────────
    sprite_brightness                 = 0.500,
    sprite_size                       = 1.000,
    water_reflection_lod              = 0.000,
}

-- ════════════════════════════════════════════════════════════════════════════
--  HOURLY KEYFRAMES
-- ════════════════════════════════════════════════════════════════════════════
--  A timecycle variable is not one value: it is a curve keyframed per hour
--  (00:00, 05:00, 06:00, 07:00, 09:00, 12:00, 16:00 ... 22:00), which is why
--  vanilla light_dir_col swings blue at night and orange at dawn/dusk.
--  A flat modifier value would flatten that curve; instead the variables below
--  are re-written on every in-game hour so the curve is REPLACED with an
--  all-orange one. There is no hour of the day with a blue cast any more --
--  only a hotter or deeper orange.
--
--  Hours listed here are the vanilla keyframe hours from the same strip.
--  Values in between are linearly interpolated. Anything not listed here keeps
--  the flat value from BO.Preset above.
-- ════════════════════════════════════════════════════════════════════════════

BO.Hourly = {
    -- Key light colour. Vanilla swings blue at 00-05 and 21-22; here it stays in
    -- the sand family at every hour, so there is no time of day with a cool cast.
    light_dir_col_r = { [0] = 0.700, [5] = 0.700, [6] = 0.800, [7] = 0.860, [9] = 0.880,
                        [12] = 0.890, [16] = 0.880, [17] = 0.870, [18] = 0.850,
                        [19] = 0.800, [20] = 0.750, [21] = 0.720, [22] = 0.705 },
    light_dir_col_g = { [0] = 0.350, [5] = 0.350, [6] = 0.460, [7] = 0.520, [9] = 0.550,
                        [12] = 0.570, [16] = 0.560, [17] = 0.545, [18] = 0.510,
                        [19] = 0.450, [20] = 0.400, [21] = 0.365, [22] = 0.355 },
    light_dir_col_b = { [0] = 0.180, [5] = 0.180, [6] = 0.255, [7] = 0.300, [9] = 0.325,
                        [12] = 0.345, [16] = 0.335, [17] = 0.320, [18] = 0.295,
                        [19] = 0.250, [20] = 0.215, [21] = 0.190, [22] = 0.183 },
    -- Key light strength stays LOW all day. A strong directional key is what
    -- carves the dark silhouettes we are trying not to have: in a real storm the
    -- sun is a diffuse source somewhere behind the dust, not a spotlight.
    light_dir_mult  = { [0] = 0.080, [5] = 0.080, [6] = 0.200, [7] = 0.320, [9] = 0.390,
                        [12] = 0.430, [16] = 0.400, [17] = 0.360, [18] = 0.300,
                        [19] = 0.190, [20] = 0.120, [21] = 0.090, [22] = 0.082 },

    -- Ambient does nearly all the lighting. High and flat = low contrast.
    -- VoidLine 2026-09-01: scaled to ~0.4 of the original curve. These names were
    -- wrong for build 3095 until now (light_amb_* vs light_natural_amb_*), so
    -- every value here was silently rejected and ambient ran at GTA's own full
    -- daylight level -- which is what kept the scene bright no matter how far
    -- the sun, exposure and grade strength were turned down.
    light_natural_amb_down_intensity = { [0] = 0.070, [6] = 0.210, [9] = 0.340, [12] = 0.380,
                                 [17] = 0.330, [20] = 0.150, [22] = 0.085 },
    light_natural_amb_up_intensity   = { [0] = 0.080, [6] = 0.225, [9] = 0.360, [12] = 0.400,
                                 [17] = 0.350, [20] = 0.170, [22] = 0.090 },

    -- Sky brightness.
    --
    -- VoidLine 2026-09-02: night values cut hard (0.480 -> 0.09 at midnight).
    -- The old comment read "narrow range: the dust is lit even at night", which
    -- was a deliberate choice -- and it is precisely why the world never got
    -- dark. The fog blends into the sky (fog_horizon_tint_scale = 1.0), so a lit
    -- sky keeps the fog lit, and the fog is most of the screen. Daylight values
    -- are untouched.
    sky_hdr = { [0] = 0.090, [6] = 0.420, [9] = 1.100, [12] = 1.380, [17] = 1.050,
                [20] = 0.260, [22] = 0.110 },

    -- Exposure. Bright, not crushed -- the reference is a pale sandy world, and
    -- BO.Exposure in Config.lua shifts this whole curve.
    postfx_exposure = { [0] = -1.500, [6] = -0.900, [9] = -0.550, [12] = -0.450,
                        [17] = -0.560, [20] = -1.000, [22] = -1.400 },

    -- (Haze colour and visibility are NOT keyframed: client/main.lua derives
    --  them from BO.HazeColor / BO.HazeBrightness / BO.VisibilityMeters and
    --  rewrites them after every hourly pass, so the storm stays where you set it.)
}

-- NOTE: every fog_* variable in BO.Preset is a starting point only.
-- client/main.lua's applyAtmosphere() runs after each hourly pass and rewrites the
-- fog colour, brightness, density and log10 visibility from the Config.lua dials,
-- so the storm never drifts with the time of day.
