-- =============================================================================
-- vl_panel -- client
--
-- Opens/closes the NUI, forwards every button press to the server (which does
-- the actual permission check and dispatch -- see server/main.lua), and keeps
-- the panel's on/off toggles honest by reading GlobalState directly. Reading
-- GlobalState.blackout/.airraid here costs nothing extra: both are already
-- replicated to every client for vl_hud's own icons, this just reads the same
-- values rather than asking the server for a third copy of them.
-- =============================================================================

local open = false

---@return boolean
local function isBlackoutActive()
    local s = GlobalState.blackout
    return s ~= nil and s.active == true
end

---@return boolean
local function isAirRaidActive()
    local s = GlobalState.airraid
    return s ~= nil and s.active == true
end

local function pushStatus()
    SendNUIMessage({
        action = 'status',
        data = { blackout = isBlackoutActive(), airraid = isAirRaidActive() },
    })
end

-- =============================================================================
-- OPEN / CLOSE
-- =============================================================================

local function openPanel()
    if open then return end
    open = true

    SetNuiFocus(true, true)
    TriggerServerEvent('vl_panel:watchStart')
    SendNUIMessage({ action = 'config', data = VLPanel.radar })
    pushStatus()
    SendNUIMessage({ action = 'open' })
end

local function closePanel()
    if not open then return end
    open = false

    SetNuiFocus(false, false)
    TriggerServerEvent('vl_panel:watchStop')
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(VLPanel.command, function()
    if open then closePanel() else openPanel() end
end, false)

if VLPanel.keybind and VLPanel.keybind.enabled then
    RegisterKeyMapping(VLPanel.command, 'Toggle the admin panel', 'keyboard', VLPanel.keybind.defaultKey)
end

-- Status can change (another admin toggles blackout from console, an
-- automatic blackout rolls, the raid times out) while THIS panel is open --
-- keep it live rather than only correct at the moment it was opened.
AddStateBagChangeHandler('blackout', 'global', function()
    if open then pushStatus() end
end)

AddStateBagChangeHandler('airraid', 'global', function()
    if open then pushStatus() end
end)

-- =============================================================================
-- LIVE PLAYER RADAR
-- =============================================================================

RegisterNetEvent('vl_panel:players', function(players)
    if not open then return end -- stale push arriving just after close
    SendNUIMessage({ action = 'players', data = players })
end)

-- =============================================================================
-- NUI -> SERVER
-- =============================================================================

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb({})
end)

RegisterNUICallback('blackoutOn', function(data, cb)
    TriggerServerEvent('vl_panel:blackoutOn', data and data.duration or '')
    cb({})
end)

RegisterNUICallback('blackoutOff', function(_, cb)
    TriggerServerEvent('vl_panel:blackoutOff')
    cb({})
end)

RegisterNUICallback('alert', function(data, cb)
    TriggerServerEvent('vl_panel:alert', data and data.message or '')
    cb({})
end)

RegisterNUICallback('pagerAlert', function(data, cb)
    TriggerServerEvent('vl_panel:pagerAlert', data and data.title or '', data and data.message or '')
    cb({})
end)

RegisterNUICallback('airraidOn', function(_, cb)
    TriggerServerEvent('vl_panel:airraidOn')
    cb({})
end)

RegisterNUICallback('airraidOff', function(_, cb)
    TriggerServerEvent('vl_panel:airraidOff')
    cb({})
end)

RegisterNUICallback('youtubePlay', function(data, cb)
    TriggerServerEvent('vl_panel:youtubePlay', data and data.url or '')
    cb({})
end)

RegisterNUICallback('youtubeStop', function(_, cb)
    TriggerServerEvent('vl_panel:youtubeStop')
    cb({})
end)

-- =============================================================================
-- YOUTUBE BROADCAST -- fires on EVERY client, not just admins with the panel
-- open (the video itself is not gated by `open`/SetNuiFocus at all: it is a
-- passive fullscreen overlay drawn over the game, not a UI the player needs
-- to interact with, so nobody's mouse/keyboard control is taken away).
-- =============================================================================

RegisterNetEvent('vl_panel:youtubeShow', function(videoId)
    print(('[vl_panel] client received youtubeShow "%s", sending to NUI'):format(tostring(videoId)))
    SendNUIMessage({ action = 'youtubeShow', data = { videoId = videoId } })
end)

RegisterNetEvent('vl_panel:youtubeHide', function()
    print('[vl_panel] client received youtubeHide, sending to NUI')
    SendNUIMessage({ action = 'youtubeHide' })
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    if open then
        SetNuiFocus(false, false)
        TriggerServerEvent('vl_panel:watchStop')
    end
end)
