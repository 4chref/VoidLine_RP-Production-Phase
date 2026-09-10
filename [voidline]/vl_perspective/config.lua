return {
    enableZoom = true, -- Enable the ability to zoom your camera

    -- VoidLine 2026-09-01: free cam removed at the owner's request.
    --
    -- client/freecam.lua returns early on this flag before registering ANY of
    -- its keybinds, so false takes the whole feature out -- the camera itself
    -- and every key it claimed: F3 (toggle), F4 (lock) and W/A/S/D/Q/E, which
    -- it was binding on top of normal movement. F3 is now free for other
    -- resources.
    --
    -- The `keys` table below is left intact so the feature can be switched back
    -- on in one line if it is ever wanted again; nothing reads those entries
    -- while this is false.
    enableFreeCam = false, -- Enable or disable free cam
    ease = 200, -- Longer ease time just means the longer it takes to ease into the camera. Lower is quicker
    speed = 0.1, -- Movement speed for freecam
    distance = 5.0, -- Max distance the freecam can be from the player
    keys = { -- Default keys
        enableFreeCam = 'F3',
        freeCamForward = 'W',
        freeCamBackward = 'S',
        freeCamLeft = 'A',
        freeCamRight = 'D',
        freeCamUp = 'Q',
        freeCamDown = 'E',
        freeCamLock = 'F4',
        zoom = 'MOUSE_MIDDLE',
    },
}