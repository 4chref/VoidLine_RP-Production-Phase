--[[
    vl_setped -- client

    Swapping a player model on THIS server is not just SetPlayerModel. Two
    things happen alongside it that both have to be handled, and neither is
    obvious:

      1. SetPlayerModel DESTROYS the old ped and builds a new one. The game
         reports that as a networked entity death, and qbx_medical listens for
         exactly that (client/dead.lua:118, CEventNetworkEntityDamage) -- if the
         player is logged in and currently alive it calls StartLastStand(),
         which sets the death state and DISABLES CONTROLS. Without the revive
         below, /setped leaves the target dead and unable to move. vl_identity
         hit this same wall in its character creation flow.

      2. illenium-appearance owns the ped's appearance. A raw SetPlayerModel is
         invisible to it, so the swap survives only until the next appearance
         refresh and then silently reverts -- and other players, who are handed
         illenium's version, may never see it at all.
]]

--- Put the player back to a living, controllable state after a model swap.
--- See note 1 above for why this is mandatory rather than defensive.
local function ensureAlive()
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
    end

    -- The state bag, not the ped: last stand resurrects the ped and holds it at
    -- full health, so IsEntityDead reads false while the player is still frozen
    -- and stated as dead.
    if LocalPlayer.state.isDead == true then
        TriggerEvent('qbx_medical:client:playerRevived')
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    SetEntityInvincible(ped, false)
end



-- =============================================================================
-- REMOTE PEDS
--
-- Everything the tall-ped treatment does is CLIENT-LOCAL: SetPedMovementClipset
-- and SetPedMoveRateOverride neither replicate nor are visible to anyone else.
-- Applied only on the wearer's machine, they saw a heavy giant striding while
-- every other player saw the same model doing the stock walk.
--
-- So the server broadcasts who is wearing what, and each client applies the
-- clipset to that player's ped itself. Only the CLIPSET is shared -- the move
-- rate is deliberately not applied to remote peds, because a remote ped's
-- position comes from the network and overriding its movement would fight that
-- sync and produce exactly the stutter this is meant to remove.
-- =============================================================================

--- serverId -> model, for other players
local remoteModels = {}

---@param clipset string
---@return boolean loaded
local function ensureClipset(clipset)
    if HasAnimSetLoaded(clipset) then return true end

    RequestAnimSet(clipset)
    local deadline = GetGameTimer() + 1000
    while not HasAnimSetLoaded(clipset) and GetGameTimer() < deadline do
        Wait(0)
    end

    return HasAnimSetLoaded(clipset)
end

RegisterNetEvent('vl_setped:sync', function(serverId, model)
    if serverId == cache.serverId then return end   -- our own ped is handled locally
    remoteModels[serverId] = model
end)

-- Re-applied on a slow loop rather than once on the event.
--
-- A remote ped only exists locally while it is STREAMED IN, and a clipset set
-- on a ped that has since been destroyed and recreated is simply lost -- so a
-- player who walks out of range and back would revert to the stock walk. This
-- costs one pass a second over however many players are in scope.
CreateThread(function()
    while true do
        Wait(1000)

        for serverId, model in pairs(remoteModels) do
            local cfg = VLSetPed.tallPeds and VLSetPed.tallPeds[model]

            if cfg and cfg.clipset then
                local ply = GetPlayerFromServerId(serverId)

                if ply ~= -1 then
                    local ped = GetPlayerPed(ply)

                    if ped ~= 0 and DoesEntityExist(ped) and ensureClipset(cfg.clipset) then
                        SetPedMovementClipset(ped, cfg.clipset, 1.0)
                    end
                end
            end
        end
    end
end)

-- Ask the server for everyone already wearing something. Without this, anyone
-- who joins after a /setped never learns about it.
AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerServerEvent('vl_setped:requestSync')
    end
end)

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('vl_setped:requestSync')
end)

--- Model the player was last set to, so the camera thread can tell when they
--- are no longer on a tall ped.
local currentTallModel = nil

-- =============================================================================
-- TALL PED CAMERA
--
-- See VLSetPed.tallPeds in config.lua for why this exists.
--
-- The trick is that the GAMEPLAY camera keeps tracking mouse input even while a
-- scripted camera is being rendered. So this reads its rotation every frame and
-- rebuilds the scripted camera's position from it -- the player is still
-- steering the normal camera, they are just seeing through one placed correctly
-- for a model nine metres tall.
-- =============================================================================

--- Give a giant a stride that matches its size.
---
--- A clipset must be STREAMED IN before SetPedMovementClipset takes -- calling
--- it on an unloaded set silently does nothing and the ped keeps the default
--- walk. Same trap as vl_hunters' terminators.
---@param cfg table entry from VLSetPed.tallPeds
local function applyTallMovement(cfg)
    local ped = PlayerPedId()

    if cfg.clipset then
        if not HasAnimSetLoaded(cfg.clipset) then
            RequestAnimSet(cfg.clipset)
            local deadline = GetGameTimer() + 1000
            while not HasAnimSetLoaded(cfg.clipset) and GetGameTimer() < deadline do
                Wait(0)
            end
        end

        if HasAnimSetLoaded(cfg.clipset) then
            SetPedMovementClipset(ped, cfg.clipset, 1.0)
        end
    end
end

local tallCam = nil
local tallToken = 0

local function stopTallCam()
    tallToken = tallToken + 1

    if tallCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(tallCam, false)
        tallCam = nil
    end
end

---@param cfg table entry from VLSetPed.tallPeds
local function startTallCam(cfg)
    stopTallCam()

    tallToken = tallToken + 1
    local token = tallToken

    tallCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(tallCam, true)
    RenderScriptCams(true, false, 0, true, true)

    CreateThread(function()
        while token == tallToken and tallCam do
            local ped = PlayerPedId()

            -- Bail the moment the player is no longer on a tall model -- death
            -- and respawn both put them back on their normal ped, and a camera
            -- left rendering after that strands the view.
            if not DoesEntityExist(ped) or not VLSetPed.tallPeds[currentTallModel or ''] then
                stopTallCam()
                return
            end

            -- Re-asserted every frame, not set once: the engine resets the
            -- move rate on its own whenever the ped changes movement state --
            -- sprinting, landing, coming out of a stagger -- and a giant that
            -- silently drops back to human speed mid-run is the original bug
            -- returning intermittently.
            if cfg.moveRate then
                SetPedMoveRateOverride(ped, cfg.moveRate + 0.0)
            end

            local rot = GetGameplayCamRot(2)
            local rx, rz = math.rad(rot.x), math.rad(rot.z)
            local cosRx = math.cos(rx)

            -- Camera forward, the same rotation-to-vector conversion used in
            -- vl_panel's air raid and vl_hunters.
            local fx = -math.sin(rz) * cosRx
            local fy = math.cos(rz) * cosRx
            local fz = math.sin(rx)

            local base = GetEntityCoords(ped)
            local focus = vector3(base.x, base.y, base.z + cfg.height)

            -- Sit `distance` back ALONG the look direction and `lift` above it,
            -- so the camera orbits the model the way the stock one orbits a
            -- human.
            SetCamCoord(tallCam,
                focus.x - fx * cfg.distance,
                focus.y - fy * cfg.distance,
                focus.z - fz * cfg.distance + cfg.lift)

            -- Point at the focus rather than reusing the gameplay rotation
            -- directly: the lift means the camera is above the aim line, so it
            -- has to tilt down slightly to keep the model centred.
            PointCamAtCoord(tallCam, focus.x, focus.y, focus.z)

            Wait(VLSetPed.tallCamTickMs or 0)
        end
    end)
end

RegisterNetEvent('vl_setped:setPed', function(pedName)
    if type(pedName) ~= 'string' then return end

    local model = joaat(pedName)

    -- IsModelInCdimage is the one that answers "does this model exist on this
    -- client" -- a streamed custom ped only passes it once its resource has
    -- started and the file has actually reached the player.
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        return TriggerEvent('chat:addMessage', {
            args = { '^1Error:', ('Model "%s" is not available on your client.'):format(pedName) }
        })
    end

    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())

    -- Through illenium rather than the raw native, so the resource that owns
    -- the appearance knows the model changed. It requests and releases the
    -- model itself and resets components on freemode peds.
    exports['illenium-appearance']:setPlayerModel(model)

    -- The swap can drop the ped a little; put it back where it stood.
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading)

    ensureAlive()

    if VLSetPed.persist then
        -- Persisting is what makes it stick across a refresh AND what other
        -- players are actually shown.
        local appearance = exports['illenium-appearance']:getPedAppearance(PlayerPedId())
        if appearance then
            TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
        end
    end

    -- Giant models need a camera placed for their size; normal ones keep the
    -- stock camera untouched.
    currentTallModel = pedName
    local tall = VLSetPed.tallPeds and VLSetPed.tallPeds[pedName]

    if tall then
        applyTallMovement(tall)
        startTallCam(tall)
    else
        stopTallCam()
        -- Back to the ped's own default walk and speed.
        ResetPedMovementClipset(PlayerPedId(), 0.0)
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
    end

    TriggerEvent('chat:addMessage', { args = { '^2Success:', 'Ped changed to ' .. pedName } })
end)

-- A scripted camera survives anything that does not explicitly stop it, so it
-- is torn down on resource stop as well -- otherwise stopping vl_setped while a
-- giant ped is active would leave the player stuck looking through a camera
-- nothing is updating any more.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopTallCam() end
end)
