-- =============================================================================
-- combat_drone / client/combat.lua
--
-- Owns everything about actually fighting: choosing where to hover relative
-- to the target (orbit / strafe / hold), facing the target, and firing real
-- controlled bursts via TaskShootAtEntity (a genuine ped combat task, not a
-- custom projectile). Never calls a shoot task every single frame -- bursts
-- are started, held for a duration, then cooled down before the next one,
-- and firing stops immediately when line of sight is lost.
-- =============================================================================

Combat = {}

function Combat.Init(drone)
    drone.combat = {
        nextRepositionAt = 0,
        repositionMode = 'hold', -- 'hold' | 'strafe' | 'orbit'
        strafeDir = 1,
        nextBurstAt = 0,
        burstEndsAt = 0,
        nextReissueAt = 0,
        nextShotAt = 0,
        isBursting = false,
        losLostAt = nil,
    }
end

-- The weapon is only handed out by the client that spawned the drone. If
-- control migrates (OneSync hands the entity to a closer player), the new
-- controller must not assume the ped is armed, or it will run the whole
-- combat loop issuing shoot tasks with an empty pair of hands.
function Combat.EnsureArmed(drone)
    local ped = drone.ped
    if not HasPedGotWeapon(ped, Config.Weapon.hash, false) then
        GiveWeaponToPed(ped, Config.Weapon.hash, Config.Weapon.ammo, false, true)
    end
    if GetSelectedPedWeapon(ped) ~= Config.Weapon.hash then
        SetCurrentPedWeapon(ped, Config.Weapon.hash, true)
    end
end

local function PickRepositionMode()
    local r = math.random()
    if r < Config.Combat.orbitChance then
        return 'orbit'
    elseif r < Config.Combat.orbitChance + Config.Combat.strafeChance then
        return 'strafe'
    end
    return 'hold'
end

-- Chooses the desired world position the drone should be flying toward this
-- combat tick: an engagement-range point around the target, varied by mode
-- so the drone doesn't just sit directly overhead.
function Combat.GetDesiredPosition(drone, target, dt)
    local c = drone.combat
    local now = GetGameTimer()
    local targetCoords = GetEntityCoords(target)

    if now >= c.nextRepositionAt then
        c.repositionMode = PickRepositionMode()
        c.strafeDir = math.random() < 0.5 and 1 or -1
        c.nextRepositionAt = now + Config.Combat.repositionInterval + math.random(-800, 800)

        local minD, maxD = Config.Combat.engagementDistanceMin, Config.Combat.engagementDistanceMax
        if Config.Combat.aggressiveness == 'aggressive' then
            minD, maxD = minD * 0.75, maxD * 0.8
        elseif Config.Combat.aggressiveness == 'defensive' then
            minD, maxD = minD * 1.3, maxD * 1.4
        end
        c.engageDistance = Utils.RandomFloat(minD, maxD)
    end

    local hoverZ = targetCoords.z + Config.Combat.hoverHeightOffset

    if c.repositionMode == 'orbit' then
        local center = vector3(targetCoords.x, targetCoords.y, hoverZ)
        return Movement.GetOrbitPoint(drone, center, c.engageDistance, Config.Movement.orbitAngularSpeed, dt)
    elseif c.repositionMode == 'strafe' then
        local droneCoords = GetEntityCoords(drone.ped)
        local toTarget = Utils.Normalize(vector3(targetCoords.x - droneCoords.x, targetCoords.y - droneCoords.y, 0.0))
        local lateral = vector3(-toTarget.y, toTarget.x, 0.0) * c.strafeDir
        local basePoint = targetCoords - (toTarget * c.engageDistance)
        return vector3(basePoint.x + lateral.x * 4.0, basePoint.y + lateral.y * 4.0, hoverZ)
    else -- hold
        local droneCoords = GetEntityCoords(drone.ped)
        local away = Utils.Normalize(vector3(droneCoords.x - targetCoords.x, droneCoords.y - targetCoords.y, 0.0))
        if #away < 0.01 then away = vector3(1.0, 0.0, 0.0) end
        local point = targetCoords + away * c.engageDistance
        return vector3(point.x, point.y, hoverZ)
    end
end

-- The weapon hash used by direct fire.
local function DirectWeaponHash()
    if Config.Weapon.fireMethod == 'vehicle' then
        return Config.Weapon.vehicle.weapon
    end
    if Config.Weapon.style == 'laser' then
        return Config.Weapon.laserHash
    end
    return Config.Weapon.hash
end

-- Weapon assets are requested in the background. Firing is deliberately NOT
-- gated on them: an unavailable or mis-named weapon hash would otherwise mean
-- the drone silently never shoots. Worst case the bullet is invisible, and the
-- beam we draw ourselves still shows.
local assetsRequested = {}
local function EnsureWeaponAsset(hash)
    if HasWeaponAssetLoaded(hash) then return true end
    if not assetsRequested[hash] then
        assetsRequested[hash] = true
        RequestWeaponAsset(hash, 31, 0)
    end
    return false
end

-- The hash actually used for damage.
--
-- NEVER returns a hash that hasn't streamed in. This matters much more for
-- vehicle weapons than it did for handheld ones: VEHICLE_WEAPON_DRONE lives in
-- an add-on's weapon blob that may not be loading at all, and
-- ShootSingleBulletBetweenCoords with an unloaded asset silently produces no
-- bullet whatsoever -- a drone that looks alive, aims, and never hurts anyone.
-- So the chain is preferred -> vehicle fallback -> stock handheld, and the last
-- one is guaranteed to exist in every build.
Combat.weaponInUse = nil    -- what actually fired last (surfaced by /dronediag)
local assetWaitStartedAt = {}
local assetWarned = false

local function ResolveDamageWeapon()
    local preferred = DirectWeaponHash()
    if EnsureWeaponAsset(preferred) then
        Combat.weaponInUse = preferred
        return preferred
    end

    -- In vehicle mode the first fallback is another VEHICLE weapon, so a missing
    -- droneweapons.meta degrades to a stock jet cannon rather than to a rifle
    -- held by an invisible pilot.
    if Config.Weapon.fireMethod == 'vehicle' then
        local vehFallback = Config.Weapon.vehicle.fallbackWeapon
        if EnsureWeaponAsset(vehFallback) then
            Combat.weaponInUse = vehFallback
            return vehFallback
        end

        -- Neither vehicle weapon is streaming. Say so once, loudly: this is
        -- almost always vl_drone_model not running or its WEAPONINFO_FILE not
        -- loading, and it is otherwise completely invisible.
        assetWaitStartedAt[preferred] = assetWaitStartedAt[preferred] or GetGameTimer()
        if not assetWarned and (GetGameTimer() - assetWaitStartedAt[preferred]) > 4000 then
            assetWarned = true
            print('[combat_drone] The drone vehicle weapon never streamed in. Falling back to a stock '
                .. 'weapon so the drone can still shoot. Check that vl_drone_model is started and that '
                .. "its droneweapons.meta is loading (data_file 'WEAPONINFO_FILE').")
        end
    end

    EnsureWeaponAsset(Config.Weapon.fallbackHash)
    Combat.weaponInUse = Config.Weapon.fallbackHash
    return Config.Weapon.fallbackHash
end

-- =============================================================================
-- VEHICLE WEAPON MOUNTS
-- =============================================================================
-- The drone add-on carries its own gun (VEHICLE_WEAPON_DRONE, defined in
-- vl_drone_model/data/droneweapons.meta and bound to seat 0 in handling.meta).
-- Firing THAT rather than a generic rifle is what gives the correct muzzle
-- flash (muz_buzzard), jet tracers, turret audio and damage profile.
--
-- Shots are emitted from the model's real weapon bones so the flash appears on
-- the gun instead of floating in front of the hull. Bone names vary between
-- drone models, so a list is tried in order and an offset from the hull is used
-- if the model has none of them.

-- Keyed by MODEL, not entity: bone indices are a property of the model, and
-- entity handles get recycled by the engine, so an entity-keyed cache both
-- leaks and eventually hands out bones belonging to something else.
local muzzleCache = {} -- model -> { boneIndex, ... } (empty table = "use the offset")

local function ResolveMuzzles(veh)
    local model = GetEntityModel(veh)
    local cached = muzzleCache[model]
    if cached then return cached end

    local found = {}
    for _, name in ipairs(Config.Weapon.vehicle.muzzleBones) do
        local idx = GetEntityBoneIndexByName(veh, name)
        if idx and idx ~= -1 then
            found[#found + 1] = idx
        end
    end

    muzzleCache[model] = found
    if Config.Debug then
        print(('[combat_drone] drone model %s: %d weapon bone(s) resolved'):format(tostring(model), #found))
    end
    return found
end

-- World position the next round leaves from, alternating between mounts so a
-- twin-gun model visibly fires from both sides.
local function VehicleMuzzlePoint(drone, veh)
    local bones = ResolveMuzzles(veh)

    if #bones > 0 then
        local i
        if Config.Weapon.vehicle.alternateMuzzles then
            drone.muzzleIndex = ((drone.muzzleIndex or 0) % #bones) + 1
            i = drone.muzzleIndex
        else
            i = 1
        end
        return GetWorldPositionOfEntityBone(veh, bones[i])
    end

    local off = Config.Weapon.vehicle.muzzleOffset
    return GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)
end

-- =============================================================================
-- LASER BEAM RENDERING
-- =============================================================================
-- Drawn by us rather than relying on a weapon's tracer, so the laser is
-- guaranteed to appear regardless of which weapon asset resolved.

local beams = {}
local beamThreadRunning = false

-- Unit-circle offsets for the ring segment counts actually used below. These
-- never change, so paying for sin/cos per segment per ring per beam per frame
-- was pure waste.
local ringUnit = {}

local function RingUnit(segments)
    local u = ringUnit[segments]
    if not u then
        u = {}
        for k = 0, segments - 1 do
            local ang = (k / segments) * math.pi * 2.0
            u[k + 1] = { c = math.cos(ang), s = math.sin(ang) }
        end
        ringUnit[segments] = u
    end
    return u
end

local StartBeamRenderer -- forward declaration; defined with the render thread

local function AddBeam(from, to, didHit)
    local cfg = Config.Weapon.laserBeam
    if not cfg.enabled then return end
    local now = GetGameTimer()

    -- The perpendicular basis depends only on the bolt's endpoints, which never
    -- move once it is created -- so derive it once here instead of redoing two
    -- cross products and three normalises for every beam on every frame.
    local dir = Utils.Normalize(to - from)
    local ref = math.abs(dir.z) < 0.9 and vector3(0.0, 0.0, 1.0) or vector3(1.0, 0.0, 0.0)
    local right = Utils.Normalize(Utils.Cross(dir, ref))
    local up = Utils.Normalize(Utils.Cross(right, dir))

    beams[#beams + 1] = {
        from = from, to = to, didHit = didHit,
        right = right, up = up,
        born = now, expires = now + cfg.durationMs,
    }

    StartBeamRenderer()
end

-- Draws a ring of parallel lines around the beam axis. Offsetting perpendicular
-- to the beam (rather than along world axes) keeps thickness uniform from every
-- viewing angle instead of collapsing to a hairline at certain angles.
local function DrawBeamRing(b, right, up, radius, c, alpha, segments)
    local unit = RingUnit(segments)
    local fx, fy, fz = b.from.x, b.from.y, b.from.z
    local tx, ty, tz = b.to.x, b.to.y, b.to.z
    local r, g, bl = c.r, c.g, c.b

    for k = 1, segments do
        local u = unit[k]
        local ox = right.x * (u.c * radius) + up.x * (u.s * radius)
        local oy = right.y * (u.c * radius) + up.y * (u.s * radius)
        local oz = right.z * (u.c * radius) + up.z * (u.s * radius)
        DrawLine(fx + ox, fy + oy, fz + oz, tx + ox, ty + oy, tz + oz, r, g, bl, alpha)
    end
end

-- NOTE: while beams exist this thread must tick EVERY frame, never idle on a
-- long Wait. Beams live only durationMs (~100ms); idling longer than that meant
-- bolts were queued, expired, and got discarded before a single frame ever drew
-- them -- the drone was firing hundreds of rounds completely invisibly.
--
-- PERF: it used to be a permanent Wait(0) thread, started at resource load and
-- spinning every frame on every client for the entire session -- including the
-- overwhelmingly common case of no drone anywhere and nothing to draw. It is
-- now started on demand by AddBeam and exits once the last bolt expires, so an
-- idle client pays nothing. Waking it from AddBeam rather than polling for work
-- keeps the every-frame guarantee above completely intact: the thread exists
-- for exactly as long as there is something to render.
StartBeamRenderer = function()
    if beamThreadRunning then return end
    beamThreadRunning = true

    CreateThread(function()
        while #beams > 0 do
            local now = GetGameTimer()
            local cfg = Config.Weapon.laserBeam
            local c, cc = cfg.color, cfg.coreColor

            for i = #beams, 1, -1 do
                local b = beams[i]
                if now > b.expires then
                    table.remove(beams, i)
                else
                    -- Fade over the bolt's life so it dissipates instead of
                    -- vanishing between one frame and the next.
                    local life = 1.0
                    if cfg.fade then
                        local age = (now - b.born) / math.max(cfg.durationMs, 1)
                        life = Utils.Clamp(1.0 - age, 0.0, 1.0)
                    end

                    local right, up = b.right, b.up

                    -- Outer halo -> inner glow -> white-hot core. Layering dim
                    -- wide passes under a bright thin one is what reads as a
                    -- laser rather than a coloured stick.
                    DrawBeamRing(b, right, up, cfg.outerWidth, c, math.floor(c.a * 0.25 * life), 8)
                    DrawBeamRing(b, right, up, cfg.width, c, math.floor(c.a * 0.7 * life), 8)
                    DrawBeamRing(b, right, up, cfg.coreWidth, cc, math.floor(cc.a * life), 6)
                    DrawLine(b.from.x, b.from.y, b.from.z, b.to.x, b.to.y, b.to.z,
                        cc.r, cc.g, cc.b, math.floor(cc.a * life))

                    if cfg.muzzleLight then
                        DrawLightWithRange(b.from.x, b.from.y, b.from.z,
                            c.r, c.g, c.b, cfg.lightRange, cfg.lightIntensity * life)
                    end
                    if cfg.impactLight and b.didHit then
                        DrawLightWithRange(b.to.x, b.to.y, b.to.z,
                            c.r, c.g, c.b, cfg.lightRange * 0.6, cfg.lightIntensity * life)
                    end
                end
            end

            Wait(0)
        end

        beamThreadRunning = false
    end)
end

-- Applies drone damage to a ped.
--
-- A client can only damage a ped it owns, so damage to ANOTHER player has to be
-- routed through the server to that player's own client. Applying it locally
-- would look right on the shooter's screen and do nothing on the victim's.
function Combat.ApplyDamage(victimPed, damage)
    if victimPed == PlayerPedId() then
        ApplyDamageToPed(victimPed, damage, true) -- armour absorbs first
        return
    end

    if IsPedAPlayer(victimPed) then
        local playerIdx = NetworkGetPlayerIndexFromPed(victimPed)
        if playerIdx and playerIdx ~= -1 then
            TriggerServerEvent('combat_drone:damagePlayer', GetPlayerServerId(playerIdx), damage)
        end
        return
    end

    -- NPCs: whoever is simulating them can damage them directly.
    ApplyDamageToPed(victimPed, damage, true) -- armour absorbs first
end

-- The victim's own client applies the damage to itself.
RegisterNetEvent('combat_drone:takeDamage', function(damage)
    damage = tonumber(damage)
    if not damage or damage <= 0 then return end
    ApplyDamageToPed(PlayerPedId(), math.min(damage, 200), true) -- armour absorbs first
end)

-- Centre-mass aim point. GetEntityCoords on a ped sits at its feet, so aiming
-- there sends rounds into the ground; the spine bone is the real body centre.
local function AimPoint(target)
    local bone = GetPedBoneCoords(target, 24818, 0.0, 0.0, 0.0) -- SKEL_Spine3
    if bone and bone.x ~= 0.0 then return bone end
    return GetEntityCoords(target) + vector3(0.0, 0.0, 0.9)
end

-- Fires one real, damaging round at the target.
--
-- In 'vehicle' mode the round IS the drone model's own mounted weapon --
-- same weapon info, same muzzle flash, tracers, audio and damage profile as the
-- vehicle firing it itself -- but emitted by us rather than by the turret AI.
-- That keeps rate of fire, burst pattern and aim under this resource's control,
-- and means a model whose seat/turret bindings are wrong still shoots correctly.
function FireDirectShot(drone, target)
    local ent = Utils.Flyer(drone)
    local ec = GetEntityCoords(ent)
    local tc = AimPoint(target)

    local dir = Utils.Normalize(vector3(tc.x - ec.x, tc.y - ec.y, tc.z - ec.z))
    if #dir < 0.01 then return false end

    local from
    if Config.Weapon.fireMethod == 'vehicle' and Utils.IsPiloted(drone) then
        -- Straight off the model's gun mount. Nudged toward the target so a
        -- bone that sits flush with the bodywork can't have its round eaten by
        -- the drone's own hull.
        from = VehicleMuzzlePoint(drone, drone.vehicle) + dir * Config.Weapon.vehicle.muzzleClearance
    else
        -- Emit the shot from a point on the side FACING the target rather than a
        -- fixed forward offset: that keeps the muzzle clear of the drone's own hull
        -- whatever way it happens to be pointing, so it can never shoot itself.
        from = ec + dir * Config.Weapon.muzzleDistance
            + vector3(0.0, 0.0, Config.Weapon.muzzleVerticalOffset)
    end

    local spread = Config.Weapon.spread
    local aim = vector3(
        tc.x + Utils.RandomFloat(-spread, spread),
        tc.y + Utils.RandomFloat(-spread, spread),
        tc.z + Utils.RandomFloat(-spread * 0.5, spread * 0.5)
    )

    local hash = ResolveDamageWeapon()
    local beamEnd = aim

    if Config.Weapon.damageMode == 'script' then
        -- We resolve the hit and apply damage ourselves. The ray is extended
        -- past the aim point, because a ray that terminates exactly on a ped's
        -- surface frequently reports no hit at all.
        local probeEnd = from + dir * (#(aim - from) + 2.0)
        local hit, hitCoords, hitEntity = Utils.RaycastPoint(from, probeEnd, ent, 1 + 2 + 4 + 8 + 16)
        if hit then beamEnd = hitCoords end

        if hit and hitEntity and hitEntity ~= 0 and DoesEntityExist(hitEntity) and IsEntityAPed(hitEntity) then
            Combat.ApplyDamage(hitEntity, Config.Weapon.damagePerShot)
            Combat.hitsLanded = (Combat.hitsLanded or 0) + 1
        end

        -- Report only; stopped short of the target so it can never add damage
        -- on top of what we just applied.
        if Config.Weapon.audible then
            local muzzleEnd = from + dir * 0.6
            ShootSingleBulletBetweenCoords(from.x, from.y, from.z,
                muzzleEnd.x, muzzleEnd.y, muzzleEnd.z,
                0, true, hash, drone.ped, true, true, Config.Weapon.bulletSpeed)
        end
    elseif Utils.IsPiloted(drone) then
        -- Same real GTA bullet as below, but explicitly ignoring the drone's own
        -- hull.
        --
        -- This matters far more than it looks. The round leaves a weapon bone
        -- ON the model, and the drone engages from ABOVE its target, so it fires
        -- downward through its own bodywork: without this the drone shoots
        -- itself, takes its own damage until it drops to critical and flees, and
        -- the player never gets hit once. Passing the vehicle here is what makes
        -- post-countdown fire actually reach the target.
        ShootSingleBulletBetweenCoordsIgnoreEntity(
            from.x, from.y, from.z,
            aim.x, aim.y, aim.z,
            Config.Weapon.damagePerShot,
            true,
            hash,
            drone.ped,                 -- owner: kill credit resolves to the drone
            Config.Weapon.audible,
            false,                     -- visible: real tracers
            Config.Weapon.bulletSpeed,
            drone.vehicle,             -- the hull the bullet must pass straight through
            false
        )
        Combat.hitsLanded = (Combat.hitsLanded or 0) + 1 -- shots delivered to the game
    else
        -- A real, visible GTA bullet. The game resolves the hit and applies the
        -- damage itself -- the same path an NPC shooting you goes through, so it
        -- registers on players without any custom networking.
        ShootSingleBulletBetweenCoords(
            from.x, from.y, from.z,
            aim.x, aim.y, aim.z,
            Config.Weapon.damagePerShot,
            true,
            hash,
            drone.ped,                 -- owner: kill credit resolves to the drone
            Config.Weapon.audible,
            false,                     -- visible: real tracers
            Config.Weapon.bulletSpeed
        )
        Combat.hitsLanded = (Combat.hitsLanded or 0) + 1 -- shots delivered to the game
    end

    AddBeam(from, beamEnd, true) -- no-op unless laserBeam.enabled

    Combat.shotsFired = (Combat.shotsFired or 0) + 1
    Combat.lastShotAt = GetGameTimer()
    return true
end

-- Begin/sustain a firing burst. Piloted drones fire the VEHICLE's weapon via
-- the pilot; flying peds fire their own ped weapon. Both tasks need re-issuing
-- periodically, so this is called on a cadence rather than once.
local function IssueFireTask(drone, target)
    if Utils.IsPiloted(drone) then
        -- Vehicle weapon, fired by the pilot from the driver seat. Unlike
        -- TaskShootAtEntity this has no duration -- it runs until cleared,
        -- which is what StopFireTask below is for. SetVehicleShootAtTarget is
        -- issued alongside it because the task alone only makes the pilot
        -- *want* to fire; this is what actually points the mounted gun.
        TaskVehicleShootAtPed(drone.ped, target, 20.0)
        local tc = GetEntityCoords(target)
        SetVehicleShootAtTarget(drone.ped, target, tc.x, tc.y, tc.z)
    else
        TaskShootAtEntity(drone.ped, target, Config.Weapon.burstDuration, Config.Weapon.firingPattern)
    end
end

-- 'direct' and 'vehicle' both fire instantaneous scripted rounds; only 'task'
-- leaves a running ped task behind that has to be cancelled.
local function UsesScriptedFire()
    local m = Config.Weapon.fireMethod
    return m == 'direct' or m == 'vehicle'
end

local function StopFireTask(drone)
    if UsesScriptedFire() then return end -- nothing to cancel, shots are instantaneous
    ClearPedTasks(drone.ped)
end

-- Handles firing logic: bursts with cooldowns, aborted immediately on lost LOS.
function Combat.UpdateFiring(drone, target)
    local ped = drone.ped
    local c = drone.combat
    local now = GetGameTimer()

    local mem = drone.knownTargets[target]
    local hasLos = mem and mem.isVisible

    if not hasLos then
        if not c.losLostAt then c.losLostAt = now end
        local losGraceExpired = (now - c.losLostAt) > Config.Combat.coverBreakLOSGrace
        if losGraceExpired and c.isBursting then
            StopFireTask(drone)
            c.isBursting = false
        end
        return false -- not firing this tick
    else
        c.losLostAt = nil
    end

    -- Don't burn bursts on something far outside the weapon's useful range;
    -- the state machine keeps closing the distance meanwhile.
    local dist = (mem and mem.distance) or Utils.Vdist(GetEntityCoords(Utils.Flyer(drone)), GetEntityCoords(target))
    if dist > Config.Weapon.maxFiringDistance then
        if c.isBursting then
            StopFireTask(drone)
            c.isBursting = false
        end
        return false
    end

    if not Utils.IsPiloted(drone) then
        Combat.EnsureArmed(drone)
        if Config.Weapon.infiniteAmmo then
            SetPedAmmo(ped, Config.Weapon.hash, Config.Weapon.ammo)
        end
    end

    local direct = UsesScriptedFire()

    if c.isBursting then
        if now >= c.burstEndsAt then
            StopFireTask(drone)
            c.isBursting = false
            c.nextBurstAt = now + math.random(Config.Weapon.burstCooldownMin, Config.Weapon.burstCooldownMax)
        elseif direct then
            -- Fire individual rounds across the burst; the flight tick calls us
            -- every frame, so shotInterval sets the actual rate of fire.
            if now >= (c.nextShotAt or 0) then
                FireDirectShot(drone, target)
                c.nextShotAt = now + Config.Weapon.shotInterval
            end
        elseif now >= c.nextReissueAt then
            -- The shoot task doesn't survive on its own: in ped mode the
            -- per-frame teleport wipes it, and in piloted mode steering the
            -- vehicle can knock it out. Re-issue on a short cadence so a burst
            -- actually sustains.
            IssueFireTask(drone, target)
            c.nextReissueAt = now + Config.Weapon.taskReissueInterval
        end
        return true
    end

    if now >= c.nextBurstAt then
        if direct then
            FireDirectShot(drone, target)
            c.nextShotAt = now + Config.Weapon.shotInterval
        else
            IssueFireTask(drone, target)
            c.nextReissueAt = now + Config.Weapon.taskReissueInterval
        end
        c.isBursting = true
        c.burstEndsAt = now + Config.Weapon.burstDuration
        return true
    end

    return false
end

function Combat.ApplyWeaponTuning(drone)
    local ped = drone.ped

    -- Preload the firing weapon so the first shot of an engagement isn't
    -- swallowed while the asset streams in.
    if UsesScriptedFire() then
        EnsureWeaponAsset(DirectWeaponHash())
    end

    if Utils.IsPiloted(drone) then
        -- Piloted drones shoot with the vehicle's weapon, so the pilot needs no
        -- weapon of its own -- just permission to fight and stay put.
        SetPedCombatAttributes(ped, 20, true)  -- BF_AlwaysFight
        SetPedCombatAttributes(ped, 3, true)   -- BF_CanUseVehicles
        SetPedCanBeDraggedOut(ped, false)
        SetPedAccuracy(ped, Config.Weapon.accuracy)
        return
    end

    Combat.EnsureArmed(drone)

    -- Hostile relationship so the ped is willing to treat players as enemies
    -- (a CIVMALE ped hates nobody, which fights the combat natives below).
    AddRelationshipGroup('COMBAT_DRONE')
    SetPedRelationshipGroupHash(ped, `COMBAT_DRONE`)
    SetRelationshipBetweenGroups(5, `COMBAT_DRONE`, `PLAYER`)

    SetPedAccuracy(ped, Config.Weapon.accuracy)
    SetPedShootRate(ped, Config.Weapon.shootRate)
    SetPedCombatAttributes(ped, 0, false)  -- BF_CanUseCover off -- drone repositions in the air instead of hiding
    SetPedCombatAttributes(ped, 5, true)   -- BF_CanFlank
    SetPedCombatAttributes(ped, 20, true)  -- BF_AlwaysFight
    SetPedFiringPattern(ped, Config.Weapon.firingPattern)
    SetPedCombatMovement(ped, 0) -- we drive movement ourselves; keep ped-native combat movement passive
end
