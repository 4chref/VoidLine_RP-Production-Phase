local noClipEnabled = false

local freecamVeh = 0
if Config.NoClipType == 1 then
    function toggleFreecam(enabled, isInVis)
        noClipEnabled = enabled
        local ped = PlayerPedId()
        if not isInVis then
            SetEntityVisible(ped, not enabled)
        end
        SetPlayerInvincible(ped, enabled)
        FreezeEntityPosition(ped, enabled)

        if enabled then
            freecamVeh = GetVehiclePedIsIn(ped, false)
            if freecamVeh > 0 then
                NetworkSetEntityInvisibleToNetwork(freecamVeh, true)
                SetEntityCollision(freecamVeh, false, false)
            end
        end

        local function enableNoClip()
            lastTpCoords = GetEntityCoords(ped)

            SetFreecamActive(true)
            StartFreecamThread()

            Citizen.CreateThread(function()
                while IsFreecamActive() do
                    SetEntityLocallyInvisible(ped)
                    if freecamVeh > 0 then
                        if DoesEntityExist(freecamVeh) then
                            SetEntityLocallyInvisible(freecamVeh)
                        else
                            freecamVeh = 0
                        end
                    end
                    Wait(0)
                end

                if not DoesEntityExist(freecamVeh) then
                    freecamVeh = 0
                end
                if freecamVeh > 0 then
                    local coords = GetEntityCoords(ped)
                    NetworkSetEntityInvisibleToNetwork(freecamVeh, false)
                    SetEntityCollision(freecamVeh, true, true)
                    SetEntityCoords(freecamVeh, coords[1], coords[2], coords[3])
                    SetPedIntoVehicle(ped, freecamVeh, -1)
                    freecamVeh = 0
                end
            end)
        end

        local function disableNoClip()
            SetFreecamActive(false)
            SetGameplayCamRelativeHeading(0)
        end

        if not IsFreecamActive() and enabled then
            enableNoClip()
        end

        if IsFreecamActive() and not enabled then
            disableNoClip()
        end
    end
end

if Config.NoClipType == 3 then
local MOVE_UP_KEY = 20
local MOVE_DOWN_KEY = 44
local CHANGE_SPEED_KEY = 21
local MOVE_LEFT_RIGHT = 30
local MOVE_UP_DOWN = 31
local NOCLIP_TOGGLE_KEY = 289
local NO_CLIP_NORMAL_SPEED = 0.5
local NO_CLIP_FAST_SPEED = 2.5
local ENABLE_NO_CLIP_SOUND = true
local eps = 0.01
local RESSOURCE_NAME = GetCurrentResourceName()
local isNoClipping = false
local speed = NO_CLIP_NORMAL_SPEED
local input = vector3(0, 0, 0)
local previousVelocity = vector3(0, 0, 0)
local breakSpeed = 10.0
local offset = vector3(0, 0, 1)
local playerPed = PlayerPedId()
local noClippingEntity = playerPed

local function IsControlAlwaysPressed(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function SetInvincible(val, id)
    SetEntityInvincible(id, val)
    return SetPlayerInvincible(id, val)
end

local function MoveInNoClip()
    SetEntityRotation(noClippingEntity, GetGameplayCamRot(0), 0, false)
    local forward, right, up, c = GetEntityMatrix(noClippingEntity)
    previousVelocity = Lerp(previousVelocity, (((right * input.x * speed) + (up * -input.z * speed) + (forward * -input.y * speed))), Timestep() * breakSpeed)
    c = c + previousVelocity
    SetEntityCoords(noClippingEntity, c - offset, true, true, true, false)
end

local function TriggerParticleEffect()
    UseParticleFxAssetNextCall("core")
    local coords = GetEntityCoords(PlayerPedId())
    local fx = StartParticleFxLoopedAtCoord("ent_dst_electrical", coords.x, coords.y, coords.z, 0,0,0, 1.0, false, false, false, false)
    Citizen.Wait(1000)
    StopParticleFxLooped(fx, false)
end

local function SetNoClip(val)
    if isNoClipping ~= val then
        playerPed = PlayerPedId()
        noClippingEntity = playerPed
        if IsPedInAnyVehicle(playerPed, false) then
            local veh = GetVehiclePedIsIn(playerPed, false)
            if veh ~= 0 then
                noClippingEntity = veh
            end
        end
        local isVeh = IsEntityAVehicle(noClippingEntity)
        isNoClipping = val
        if ENABLE_NO_CLIP_SOUND then
            PlaySoundFromEntity(-1, (isNoClipping and "SELECT" or "CANCEL"), playerPed, "HUD_LIQUOR_STORE_SOUNDSET", 0, 0)
        end
        SetUserRadioControlEnabled(not isNoClipping)
        if isNoClipping then
            TriggerParticleEffect()
            SetEntityAlpha(noClippingEntity, 51, false)
            CreateThread(function()
                SetInvincible(true, noClippingEntity)
                if not isVeh then ClearPedTasksImmediately(playerPed) end
                while isNoClipping do
                    Wait(0)
                    FreezeEntityPosition(noClippingEntity, true)
                    SetEntityCollision(noClippingEntity, false, false)
                    SetEntityVisible(noClippingEntity, false, false)
                    SetLocalPlayerVisibleLocally(true)
                    SetEveryoneIgnorePlayer(playerPed, true)
                    SetPoliceIgnorePlayer(playerPed, true)
                    input = vector3(
                        GetControlNormal(0, MOVE_LEFT_RIGHT),
                        GetControlNormal(0, MOVE_UP_DOWN),
                        (IsControlAlwaysPressed(1, MOVE_UP_KEY) and 1) or ((IsControlAlwaysPressed(1, MOVE_DOWN_KEY) and -1) or 0)
                    )
                    speed = (IsControlAlwaysPressed(1, CHANGE_SPEED_KEY) and NO_CLIP_FAST_SPEED or NO_CLIP_NORMAL_SPEED) * (isVeh and 2.75 or 1)
                    MoveInNoClip()
                end
                FreezeEntityPosition(noClippingEntity, false)
                SetEntityCollision(noClippingEntity, true, true)
                SetEntityVisible(noClippingEntity, true, false)
                SetLocalPlayerVisibleLocally(true)
                ResetEntityAlpha(noClippingEntity)
                SetEveryoneIgnorePlayer(playerPed, false)
                SetPoliceIgnorePlayer(playerPed, false)
                SetInvincible(false, noClippingEntity)
            end)
        else
            ResetEntityAlpha(noClippingEntity)
        end
    end
end

function ToggleNoClip()
    SetNoClip(not isNoClipping)
end

RegisterNetEvent('qb-admin:client:ToggleNoClip', ToggleNoClip)
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == RESSOURCE_NAME then
        SetNoClip(false)
    end
end)

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == ResourceName then
            FreezeEntityPosition(NoClipEntity, false)
            FreezeEntityPosition(PlayerPed, false)
            SetEntityCollision(NoClipEntity, true, true)
            SetEntityVisible(NoClipEntity, true, false)
            SetLocalPlayerVisibleLocally(true)
            ResetEntityAlpha(NoClipEntity)
            ResetEntityAlpha(PlayerPed)
            SetEveryoneIgnorePlayer(PlayerPed, false)
            SetPoliceIgnorePlayer(PlayerPed, false)
            ResetEntityAlpha(NoClipEntity)
            SetPoliceIgnorePlayer(PlayerPed, true)
            SetEntityInvincible(NoClipEntity, false)
        end
    end)
end