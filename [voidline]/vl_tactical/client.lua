-- ====================================================================
-- UTILITIES
-- ====================================================================
local GMath = {}

function GMath.GetCameraDirection()
    local rot = GetGameplayCamRot(2)
    local tZ, tX = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(tX))
    return vector3(-math.sin(tZ) * num, math.cos(tZ) * num, math.sin(tX))
end

local function LerpTime(start, target, startTime, duration)
    local elapsed = GetGameTimer() - startTime
    local t = math.min(elapsed / duration, 1.0)
    -- Smootherstep (Perlin's quintic): eases in/out more gradually than the
    -- old cubic smoothstep, so the camera visibly accelerates and decelerates
    -- instead of moving at a near-constant speed through the middle.
    t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
    return start + (target - start) * t
end

-- ====================================================================
-- TACTICAL LEAN SYSTEM
-- ====================================================================
local Lean = {}
Lean.cam = nil
Lean.stance = 0
Lean.PeekingPosition = 0
Lean.activeState = { mode = "NONE", crouch = false }
Lean.lastTickTime = 0

-- Variables for Lerp
local startLerpRot, reversLerpRot, sLerpRot = 0.0, 0.0, 0.0
local initialCamCoords, targetLeanCoords, activeLeanCoords = nil, nil, nil
local CamDidHit, GameplayCameraDidHit = false, false

-- Collision checks are two synchronous raycasts; running them every single
-- frame (previously the case) adds native-call cost every tick for no
-- visible benefit, since a wall isn't going to appear mid-lean. Throttled to
-- ~8/sec, which is still fast enough to catch the camera before it clips.
local COLLISION_CHECK_INTERVAL = 120
local nextCollisionCheck = 0

local function GetCameraPositionX()
    local viewMode = GetFollowPedCamViewMode()
    local multiplier = Lean.PeekingPosition == 1 and 1.0 or -1.0
    local extraRight = Lean.PeekingPosition == 1 and Config.Lean.TPV.extraRightOffset or 0

    if viewMode == 0 then
        return (Config.Lean.TPV.lateralOffsetClose + extraRight) * multiplier
    elseif viewMode == 1 then
        return (Config.Lean.TPV.lateralOffsetMedium + extraRight) * multiplier
    elseif viewMode == 2 then
        return (Config.Lean.TPV.lateralOffsetFar + extraRight) * multiplier
    end
    return 0.0
end

local function GetCameraPositionTranslation(gameplayCamCoords, pedCoords)
    local x = GetCameraPositionX()
    local z = Config.Lean.TPV.verticalOffset
    local forward = GetEntityForwardVector(PlayerPedId())
    local camToPed = gameplayCamCoords - pedCoords
    local yDist = (forward.x * camToPed.x) + (forward.y * camToPed.y)
    return vector3(x, yDist, z)
end

local function CheckCollision(ped, targetPos)
    local pedPos = GetEntityCoords(ped)
    local raycast = StartShapeTestCapsule(pedPos.x, pedPos.y, pedPos.z, targetPos.x, targetPos.y, targetPos.z, 0.2, 511,
        ped, 4)
    local retval, hit = GetShapeTestResult(raycast)
    -- retval 0 = result not resolved yet this tick. Reading `hit` in that case
    -- returns garbage/stale data, which was flickering CamDidHit and jerking
    -- the camera in and out of the wall-avoidance offset. Treat "not ready"
    -- as "no hit" -- it gets re-checked on the next throttled pass anyway.
    if retval == 0 then return false end
    return hit == 1
end

local function CleanupCameraImmediate()
    if Lean.cam then
        RenderScriptCams(false, false, 0, true, true)
        SetCamActive(Lean.cam, false)
        DestroyCam(Lean.cam, false)
        Lean.cam = nil
    end
    Lean.stance = 0
    Lean.PeekingPosition = 0
    Lean.initialCamCoords = nil
    Lean.targetLeanCoords = nil
    Lean.activeLeanCoords = nil
end

local function DrawTacticalReticle()
    DrawRect(0.5, 0.5, 0.0030, 0.0030, 255, 255, 255, 200)
end

---Enters the lean toward `side` (1 = right, 2 = left).
---`redirect` = true means we're already leaning the other way and switching
---directly, so the lerp starts from the camera's CURRENT position instead of
---snapping back to the gameplay cam first -- one continuous motion instead of
---two lerps back to back, which is what made left/right switching feel
---stuttery.
local function BeginLean(ped, isCrouching, side, redirect)
    local anims = side == 1 and Config.Lean.Anims.RIGHT or Config.Lean.Anims.LEFT
    local anim = isCrouching and anims.low or anims.high
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 49, 0, false, false, false)

    Lean.PeekingPosition = side

    if redirect and Lean.cam then
        initialCamCoords = GetCamCoord(Lean.cam)
    else
        initialCamCoords = GetGameplayCamCoord()
        local rot = GetGameplayCamRot(2)

        if not Lean.cam then
            Lean.cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", initialCamCoords.x, initialCamCoords.y,
                initialCamCoords.z, rot.x, rot.y, rot.z, GetGameplayCamFov(), true, 2)
        end
        SetCamActive(Lean.cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    Lean.lastTickTime, Lean.stance = GetGameTimer(), 2
end

function Lean.Update(ped, isAiming, qPressed, ePressed)
    local viewMode = GetFollowPedCamViewMode()
    if viewMode == 4 then -- Disable in First Person
        if Lean.stance ~= 0 then CleanupCameraImmediate() end
        return
    end

    -- Disable in vehicle
    if IsPedInAnyVehicle(ped, false) then
        if Lean.stance ~= 0 then CleanupCameraImmediate() end
        return
    end

    if Lean.stance > 0 then DrawTacticalReticle() end
    local isCrouching = IsPedDucking(ped)
    local targetMode = "NONE"

    if not isAiming then
        if Lean.stance ~= 0 then
            ClearPedSecondaryTask(ped)
            CleanupCameraImmediate()
        end
        return
    end

    -- Input Handling
    if isAiming then
        if Lean.stance == 0 then
            if ePressed then
                BeginLean(ped, isCrouching, 1, false)
            elseif qPressed then
                BeginLean(ped, isCrouching, 2, false)
            end
        elseif Lean.stance >= 1 and Lean.stance <= 3 then
            -- Direct redirect: the other key is down and this one isn't ->
            -- switch sides from wherever the camera currently is, instead of
            -- releasing back to center first.
            if Lean.PeekingPosition == 1 and qPressed and not ePressed then
                BeginLean(ped, isCrouching, 2, true)
            elseif Lean.PeekingPosition == 2 and ePressed and not qPressed then
                BeginLean(ped, isCrouching, 1, true)
            elseif (Lean.PeekingPosition == 1 and not ePressed) or (Lean.PeekingPosition == 2 and not qPressed) then
                ClearPedSecondaryTask(ped)
                Lean.stance = 4
            end
        end

        if Lean.PeekingPosition == 1 then
            targetMode = "RIGHT"
        elseif Lean.PeekingPosition == 2 then
            targetMode = "LEFT"
        end
    end

    -- State Sync (OneSync)
    if Lean.activeState.mode ~= targetMode or Lean.activeState.crouch ~= isCrouching then
        Lean.activeState = { mode = targetMode, crouch = isCrouching }
        LocalPlayer.state:set('TacticalLean', Lean.activeState, true)
    end

    -- Camera Logic
    if Lean.stance == 2 then -- LERPING (BeginLean already created/positioned the cam)
        local camRot = GetGameplayCamRot(2)
        local camFov = GetGameplayCamFov()

        local lerpT = LerpTime(0.0, 1.0, Lean.lastTickTime, Config.Lean.TPV.transitionMs)
        startLerpRot = lerpT * (Lean.PeekingPosition == 1 and 1.0 or -1.0) * Config.Lean.TPV.cameraRoll

        -- Recomputed live every frame (not a one-off snapshot from when the
        -- lean started) so the target tracks the ped if they move or turn
        -- during the transition. Previously this was computed once and the
        -- camera would lerp toward a now-stale point, then SNAP to the
        -- correct spot the instant ACTIVE took over -- that snap was the
        -- main source of the reported stutter.
        local pedCoords = GetEntityCoords(ped)
        local posTrans = GetCameraPositionTranslation(GetGameplayCamCoord(), pedCoords)
        targetLeanCoords = GetOffsetFromEntityInWorldCoords(ped, posTrans.x, posTrans.y, posTrans.z)

        local lX = initialCamCoords.x + (targetLeanCoords.x - initialCamCoords.x) * lerpT
        local lY = initialCamCoords.y + (targetLeanCoords.y - initialCamCoords.y) * lerpT
        local lZ = initialCamCoords.z + (targetLeanCoords.z - initialCamCoords.z) * lerpT

        activeLeanCoords = vector3(lX, lY, lZ)
        SetCamCoord(Lean.cam, lX, lY, lZ)
        SetCamRot(Lean.cam, camRot.x, camRot.y + startLerpRot, camRot.z, 2)
        SetCamFov(Lean.cam, camFov)

        if lerpT >= 0.99 then Lean.lastTickTime, Lean.stance = GetGameTimer(), 3 end
    elseif Lean.stance == 3 then -- ACTIVE
        if Lean.PeekingPosition ~= 0 then
            local gameRot = GetGameplayCamRot(2)
            local gameCamCoord = GetGameplayCamCoord()
            local pedCoords = GetEntityCoords(ped)

            local posTrans = (not CamDidHit or not GameplayCameraDidHit) and
                GetCameraPositionTranslation(gameCamCoord, pedCoords) or vector3(0, 0, 0)
            local offsetPos = GetOffsetFromEntityInWorldCoords(ped, posTrans.x, posTrans.y, posTrans.z)

            activeLeanCoords = offsetPos
            SetCamCoord(Lean.cam, offsetPos.x, offsetPos.y, offsetPos.z)
            local roll = (Lean.PeekingPosition == 1 and 1.0 or -1.0) * Config.Lean.TPV.cameraRoll
            SetCamRot(Lean.cam, gameRot.x, gameRot.y + roll, gameRot.z, 2)
            SetCamFov(Lean.cam, GetGameplayCamFov())

            local now = GetGameTimer()
            if now >= nextCollisionCheck then
                nextCollisionCheck = now + COLLISION_CHECK_INTERVAL
                CamDidHit = CheckCollision(ped, offsetPos)
                GameplayCameraDidHit = CheckCollision(ped, GetOffsetFromEntityInWorldCoords(ped, GetCameraPositionX(), 0, 0))
            end
        end
    elseif Lean.stance == 4 then -- ENDING
        sLerpRot = (Lean.PeekingPosition == 1 and 1.0 or -1.0) * Config.Lean.TPV.cameraRoll
        Lean.lastTickTime, Lean.stance = GetGameTimer(), 5
    elseif Lean.stance == 5 then -- REVERSING
        local lerpT = LerpTime(0.0, 1.0, Lean.lastTickTime, Config.Lean.TPV.transitionMs)
        reversLerpRot = sLerpRot * (1.0 - lerpT)
        local gameplayCam = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)

        local lX = activeLeanCoords.x + (gameplayCam.x - activeLeanCoords.x) * lerpT
        local lY = activeLeanCoords.y + (gameplayCam.y - activeLeanCoords.y) * lerpT
        local lZ = activeLeanCoords.z + (gameplayCam.z - activeLeanCoords.z) * lerpT

        SetCamCoord(Lean.cam, lX, lY, lZ)
        SetCamRot(Lean.cam, camRot.x, camRot.y + reversLerpRot, camRot.z, 2)
        SetCamFov(Lean.cam, GetGameplayCamFov())

        if lerpT >= 0.99 then Lean.stance = 6 end
    elseif Lean.stance == 6 then -- CLEANUP
        CleanupCameraImmediate()
    end
end

-- Sync Handler for other players
AddStateBagChangeHandler('TacticalLean', nil, function(bagName, key, value, _unused, replicated)
    local ply = GetPlayerFromStateBagName(bagName)
    if not ply or ply == PlayerId() then return end
    local remotePed = GetPlayerPed(ply)
    if not DoesEntityExist(remotePed) then return end

    if not value or value.mode == "NONE" then
        ClearPedSecondaryTask(remotePed)
    else
        local animData = value.crouch and Config.Lean.Anims[value.mode].low or Config.Lean.Anims[value.mode].high
        lib.requestAnimDict(animData.dict)
        TaskPlayAnim(remotePed, animData.dict, animData.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end)

-- ====================================================================
-- QUICK THROW SYSTEM
-- ====================================================================
local Grenade = {}
Grenade.lastThrowTime = 0
Grenade.isThrowing = false
local R_HAND_BONE = 28422
local ANIM_DICT = "weapons@projectile@aim_throw_rifle"
local ANIM_NAME = "aim_throw_m"

local function GetBestThrowable()
    for _, cfg in ipairs(Config.QuickThrow.Throwables) do
        local count = exports.ox_inventory:Search('count', cfg.item) or 0
        if count > 0 then return cfg end
    end
    return nil
end

local function FireNetworkedProjectile(ped, hash, speed)
    local camDir = GMath.GetCameraDirection()
    local spawnPos = GetPedBoneCoords(ped, R_HAND_BONE, 0.0, 0.0, 0.0)
    local finalSpawn = spawnPos + (camDir * 0.8)
    local finalTarget = finalSpawn + (camDir * 50.0)

    ShootSingleBulletBetweenCoords(
        finalSpawn.x, finalSpawn.y, finalSpawn.z,
        finalTarget.x, finalTarget.y, finalTarget.z,
        100, true, hash, ped, true, true, speed
    )
end

local function CanUseTactical()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false end
    return IsPlayerFreeAiming(PlayerId())
end

local function ProcessQuickThrow()
    local ped = PlayerPedId()
    if Grenade.isThrowing or not Config.QuickThrow.Enabled or not CanUseTactical() then return end
    if not IsPlayerFreeAiming(PlayerId()) or IsPedInAnyVehicle(ped, false) then return end

    local throwable = GetBestThrowable()
    if not throwable then
        return lib.notify({ type = 'error', description = 'ไม่มีอาวุธขว้างในตัว!' })
    end

    local now = GetGameTimer()
    if now - Grenade.lastThrowTime < Config.QuickThrow.Cooldown then return end

    Grenade.isThrowing = true
    Grenade.lastThrowTime = now

    LocalPlayer.state:set('isTacticalThrowing', true, true)

    CreateThread(function()
        -- Validate with server FIRST before doing anything
        local canThrow = lib.callback.await('tactical_lite:canThrow', false, throwable.item)

        if not canThrow then
            lib.notify({ type = 'error', description = 'ไม่สามารถขว้างได้!' })
            Grenade.isThrowing = false
            LocalPlayer.state:set('isTacticalThrowing', false, true)
            return
        end

        RequestAnimDict(ANIM_DICT)
        RequestWeaponAsset(throwable.hash)
        while not (HasAnimDictLoaded(ANIM_DICT) and HasWeaponAssetLoaded(throwable.hash)) do Wait(10) end

        TaskPlayAnim(ped, ANIM_DICT, ANIM_NAME, 2.0, -2.0, -1, 48, 0, false, false, false)
        Wait(400) -- Wait for throw point

        FireNetworkedProjectile(ped, throwable.hash, throwable.speed)

        Wait(200)
        StopAnimTask(ped, ANIM_DICT, ANIM_NAME, 1.0)
        Grenade.isThrowing = false
        LocalPlayer.state:set('isTacticalThrowing', false, true)
        RemoveAnimDict(ANIM_DICT)
    end)
end

RegisterCommand('quick_throw', ProcessQuickThrow, false)
RegisterKeyMapping('quick_throw', 'Quick Tactical Throw', 'keyboard', Config.QuickThrow.Key)

-- ====================================================================
-- MAIN LOOP
-- ====================================================================
local isLeanLeftPressed, isLeanRightPressed = false, false

RegisterCommand('+lean_left', function() isLeanLeftPressed = true end, false)
RegisterCommand('-lean_left', function() isLeanLeftPressed = false end, false)
RegisterCommand('+lean_right', function() isLeanRightPressed = true end, false)
RegisterCommand('-lean_right', function() isLeanRightPressed = false end, false)
RegisterKeyMapping('+lean_left', 'Tactical Lean Left', 'keyboard', Config.Lean.LKey)
RegisterKeyMapping('+lean_right', 'Tactical Lean Right', 'keyboard', Config.Lean.RKey)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        local isAiming = IsPlayerFreeAiming(PlayerId()) or IsControlPressed(0, 25)

        -- Cleanup if in vehicle
        if inVehicle then
            if Lean.stance ~= 0 then
                Lean.Update(ped, false, false, false)
            end
            Wait(500)
        elseif isAiming then
            Lean.Update(ped, true, isLeanLeftPressed, isLeanRightPressed)
            Wait(0)
        else
            if Lean.stance ~= 0 then
                Lean.Update(ped, false, false, false)
            end
            Wait(200)
        end
    end
end)
