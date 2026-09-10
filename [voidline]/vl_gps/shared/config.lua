Config = {}

Config.DeviceName = 'CRT-8000 GPS'
Config.ItemName = 'gps'

-- Handheld prop shown while the GPS is open: vanilla phone model, paired
-- with the cellphone@ anim dict below (no stream dependency on af-pager).
Config.Prop = {
    model = 'prop_phone_ing',
    fallbackModel = 'prop_npc_phone',
    bone = 28422, -- SKEL_L_Hand
    pos = vec3(0.03, 0.02, 0.0),
    rot = vec3(0.0, 0.0, 0.0),
}

Config.Anim = {
    dict = 'cellphone@',
    clip = 'cellphone_text_read_base',
    flag = 49,
}

-- Toggle key while the GPS item is active on screen (INPUT_FRONTEND_PAUSE etc. avoided on purpose)
Config.CloseKey = 200 -- INPUT_FRONTEND_PAUSE_ALTERNATE (ESC/Backspace also closes)

Config.UpdateIntervalMs = 250

-- Real map tiles, extracted from the game's own minimap texture atlas
-- (OpenIV minimap_sea_X_Y export) via the charming-byte/simple-livemap
-- project's public asset pack, at their zoom level 5 (32x32 grid of
-- 256x256 tiles = 8192x8192 total -- their highest available detail).
-- Zoom 4 (4096x4096) looked blurry once CSS-stretched to a usable size on
-- screen; zoom 5 has double the source pixels so the same on-screen zoom
-- level is sharp. Individual tiles stay small/safe either way (256x256).
--
-- The exact world<->pixel formula below is that project's published
-- CustomCRS transform, independently used and confirmed by a second
-- unrelated project (RiceaRaul/gta-v-map-leaflet) with the identical
-- constants -- this is the real, verified community calibration for this
-- exact tile set, not a guess. No manual calibration needed or possible.
Config.Tiles = {
    folder = 'images/tiles/',
    tileSize = 256,
    zoom = 5,
    grid = 32, -- 2^zoom
}

-- world -> full-mosaic pixel: px = 2^zoom * (scaleX*worldX + centerX)
--                              py = 2^zoom * (-scaleY*worldY + centerY)
Config.MapProjection = {
    centerX = 117.3,
    centerY = 172.8,
    scaleX = 0.02072,
    scaleY = 0.0205,
}

-- CSS zoom multiplier applied to the tile mosaic inside the device
-- screen. Higher = more zoomed in. Halved vs the zoom-4 tile set since
-- these source pixels already cover half the world-distance each.
Config.MapZoom = 1.4

Config.Lang = {
    no_signal_title = 'GPS',
    picked_up = 'GPS unit powered on.',
    closed = 'GPS unit powered off.',
}
