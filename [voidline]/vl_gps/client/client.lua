local isOpen = false        -- device visible on screen
local cursorActive = false  -- mouse cursor + NUI interaction currently granted (toggled by ALT)
local updateThread = nil
local escWatchThread = false
local attackBlockThread = false

-- World coords -> pixel position on the full tile mosaic. Verified
-- community formula (see shared/config.lua) -- deterministic, no
-- per-server calibration needed or possible.
local mosaicScale = 2 ^ Config.Tiles.zoom
local function worldToMapPixel(x, y)
    local proj = Config.MapProjection
    local px = mosaicScale * (proj.scaleX * x + proj.centerX)
    local py = mosaicScale * (-proj.scaleY * y + proj.centerY)
    return px, py
end

local function pushLocation()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(street1)
    local crossName = street2 ~= 0 and GetStreetNameFromHashKey(street2) or nil
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    local mapX, mapY = worldToMapPixel(coords.x, coords.y)

    SendNUIMessage({
        action = 'gps:update',
        data = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = heading,
            street = streetName,
            cross = crossName,
            zone = zone,
            mapX = mapX,
            mapY = mapY,
        },
    })
end

-- =============================================================================
-- Cursor / focus toggle (ALT)
--
-- Separate from isOpen on purpose: the device stays on screen the whole time
-- it's open, but interacting with it (clicking buttons, typing coordinates)
-- only needs the cursor grabbed some of the time. ALT flips that grab on and
-- off without closing the device -- toggle it off and you're back to normal
-- play (WASD, camera, combat) with the GPS still visible, toggle it back on
-- to click something.
-- =============================================================================

local function stopAttackBlock()
    attackBlockThread = false
end

-- keepInput (used while the cursor is active) leaves every game control
-- live, including the mouse-click attack/melee ones, so clicking a button in
-- the NUI (e.g. the zoom controls) would also throw a punch in-game. This
-- blocks just those controls for as long as the cursor is actually up.
--
-- VoidLine 2026-08-31: also blocks movement and camera-look controls now, so
-- the player is fully frozen (camera included) while the GPS cursor is up --
-- previously only attack/melee were blocked, movement/camera stayed live.
-- This has to be done via DisableControlAction, NOT SetNuiFocusKeepInput(false):
-- that native blocks ALL game input uniformly, including the RegisterKeyMapping
-- command below that toggles the cursor off again -- ALT would do nothing
-- while the cursor was active, since its own keybind got silenced along with
-- everything else. keepInput stays true so the toggle keybind keeps firing;
-- this thread is what actually stops the camera/movement instead.
local function startAttackBlock()
    attackBlockThread = true
    CreateThread(function()
        while attackBlockThread do
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 140, true) -- Melee light attack
            DisableControlAction(0, 141, true) -- Melee heavy attack
            DisableControlAction(0, 142, true) -- Melee alternate
            DisableControlAction(0, 257, true) -- Melee attack 1 (unarmed punch)
            DisableControlAction(0, 263, true) -- Melee attack 2
            DisableControlAction(0, 264, true) -- Melee attack alternate
            DisableControlAction(0, 1, true)   -- Look left/right (mouse)
            DisableControlAction(0, 2, true)   -- Look up/down (mouse)
            DisableControlAction(0, 30, true)  -- Move left/right
            DisableControlAction(0, 31, true)  -- Move up/down
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 71, true)  -- Vehicle accelerate
            DisableControlAction(0, 72, true)  -- Vehicle brake/reverse
            DisableControlAction(0, 59, true)  -- Vehicle steer left/right
            DisableControlAction(0, 63, true)  -- Vehicle move left/right (alt)
            DisableControlAction(0, 64, true)  -- Vehicle move up/down (alt)
            Wait(0)
        end
    end)
end

local function setCursorActive(active)
    if not isOpen then return end
    cursorActive = active

    SetNuiFocus(active, active)
    -- Left true (not false) so the af_gps_togglecursor keybind (ALT) below
    -- keeps firing even while the cursor is active -- see the comment on
    -- startAttackBlock above for why. DisableControlAction there is what
    -- actually freezes movement/camera, not this.
    SetNuiFocusKeepInput(true)

    if active then
        startAttackBlock()
    else
        stopAttackBlock()
    end
end

RegisterCommand('af_gps_togglecursor', function()
    if not isOpen then return end
    setCursorActive(not cursorActive)
end, false)
RegisterKeyMapping('af_gps_togglecursor', 'Toggle GPS cursor', 'keyboard', 'LMENU')

-- =============================================================================
-- Open / close
-- =============================================================================

local function closeGps()
    if not isOpen then return end

    -- setCursorActive guards itself on isOpen, so it has to run BEFORE
    -- isOpen flips false below -- otherwise it silently no-ops and
    -- SetNuiFocus never gets released, leaving the cursor stuck on screen.
    setCursorActive(false)

    isOpen = false
    escWatchThread = false

    SendNUIMessage({ action = 'gps:close' })

    updateThread = nil

    lib.notify({ title = Config.Lang.no_signal_title, description = Config.Lang.closed, type = 'inform' })
end

local function openGps()
    if isOpen then return end
    isOpen = true

    SendNUIMessage({
        action = 'gps:open',
        data = {
            device = Config.DeviceName,
            tileFolder = Config.Tiles.folder,
            tileSize = Config.Tiles.tileSize,
            tileGrid = Config.Tiles.grid,
            mapZoom = Config.MapZoom,
            -- Sent so the NUI can convert a manually typed X/Y destination
            -- into the same map-pixel space as the player blip, using the
            -- exact formula worldToMapPixel above, without a round trip.
            mapProjection = Config.MapProjection,
            tileZoomExp = Config.Tiles.zoom,
        },
    })
    lib.notify({ title = Config.Lang.no_signal_title, description = Config.Lang.picked_up, type = 'success' })

    updateThread = true
    CreateThread(function()
        while isOpen do
            pushLocation()
            Wait(Config.UpdateIntervalMs)
        end
    end)

    -- Runs for as long as the device is open regardless of cursor state, so
    -- ESC/Backspace always closes it even with the cursor currently hidden.
    -- A dedicated Wait(0) loop rather than the slower update loop above,
    -- since IsControlJustPressed only catches a single frame and the slower
    -- loop kept missing most presses.
    escWatchThread = true
    CreateThread(function()
        while escWatchThread do
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 202) then -- ESC / Backspace
                closeGps()
                break
            end
            Wait(0)
        end
    end)

    -- Starts interactive so there's no need to press ALT just to use it the
    -- first time; ALT toggles it off/on freely from here.
    setCursorActive(true)
end

RegisterNUICallback('gps:close', function(_, cb)
    closeGps()
    cb({})
end)

RegisterNetEvent('af-gps:client:use', function()
    if isOpen then
        closeGps()
    else
        openGps()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isOpen then closeGps() end
end)
