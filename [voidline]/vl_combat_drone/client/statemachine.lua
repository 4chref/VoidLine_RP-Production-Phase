-- =============================================================================
-- combat_drone / client/statemachine.lua
--
-- Two responsibilities, kept deliberately separate for performance:
--
--   StateMachine.Decide(drone)   -- runs every Config.Intervals.stateMachine ms.
--       Cheap, high-level logic only: reads target/detection memory built by
--       Detection.Scan, checks health, checks search timers, and decides
--       which state the drone should be in. Never touches movement natives.
--
--   StateMachine.FlightTick(drone, dt) -- runs every high-frequency movement
--       tick (see client/main.lua). Given the *current* state, computes the
--       desired position/facing/firing for this instant and hands off to
--       Movement/Combat. This is what makes flight look smooth: the target
--       position it seeks can change every tick (e.g. orbiting), even though
--       the *decision* of which state to be in only re-evaluates a few times
--       a second.
-- =============================================================================

StateMachine = {}

local STATES = {
    'IDLE', 'PATROL', 'SEARCHING', 'INVESTIGATING', 'WARNING', 'TRACKING',
    'ENGAGING', 'WITHDRAWING', 'LOST_TARGET', 'RETURNING', 'RETREATING',
    'DAMAGED', 'DESTROYED',
}

-- States during which the drone runs its alert siren. Kept as a set so the
-- siren rule is one edit away from any behaviour change.
--
-- WITHDRAWING is in here deliberately: the drone leaving with its alarm still
-- blaring is the cue that something has been called in, and cutting the sound
-- the instant it turns away would read as it simply losing interest.
local SIREN_STATES = {
    WARNING = true,
    TRACKING = true,
    ENGAGING = true,
    WITHDRAWING = true,
}

function StateMachine.Init(drone)
    drone.state = 'IDLE'
    drone.stateEnteredAt = GetGameTimer()
    drone.lastKnownPos = nil
    drone.searchStartedAt = nil
    drone.searchWaypoints = nil
    drone.searchWaypointIndex = 1
    drone.searchWaypointReachedAt = nil
    Warning.Init(drone)
end

local function SetState(drone, newState)
    if drone.state == newState then return end
    if Config.Debug then
        print(('[combat_drone] drone %s: %s -> %s'):format(tostring(drone.ped), drone.state, newState))
    end
    drone.state = newState
    drone.stateEnteredAt = GetGameTimer()
end

-- In piloted mode the VEHICLE is what soaks incoming fire, so its body health
-- is the drone's health; the pilot inside is incidental.
local function HealthPercent(drone)
    local ent = Utils.Flyer(drone)
    local max = GetEntityMaxHealth(ent)
    if max <= 0 then return 0 end
    return (GetEntityHealth(ent) / max) * 100.0
end

local function BuildSearchWaypoints(center)
    local points = {}
    local n = Config.Search.waypoints
    for i = 1, n do
        local angle = (i / n) * math.pi * 2.0
        local x = center.x + math.cos(angle) * Config.Search.radius
        local y = center.y + math.sin(angle) * Config.Search.radius
        points[#points + 1] = vector3(x, y, center.z)
    end
    return points
end

-- =============================================================================
-- DECISION PHASE (low frequency)
-- =============================================================================

function StateMachine.Decide(drone)
    local ped = drone.ped
    if not DoesEntityExist(ped) then return end

    local flyer = Utils.Flyer(drone)
    if IsEntityDead(ped) or IsEntityDead(flyer) then
        Warning.Cancel(drone, 'destroyed')
        Audio.RequestSiren(drone, false)
        SetState(drone, 'DESTROYED')
        return
    end

    local healthPct = HealthPercent(drone)

    -- Critical health always wins, regardless of what else is happening.
    if healthPct <= Config.Damage.criticalHealthPercent and drone.state ~= 'RETREATING' then
        if Config.Damage.callBackupOnCritical then
            StateMachine.CallForBackup(drone)
        end
        Warning.Cancel(drone, 'retreating')
        SetState(drone, 'RETREATING')
        StateMachine.UpdateSiren(drone)
        return
    end

    if drone.state == 'RETREATING' then
        -- Stay retreating until far enough from any threat and no longer critical.
        local safe = healthPct > Config.Damage.criticalHealthPercent
        local threatNear = drone.target and DoesEntityExist(drone.target)
            and Utils.Vdist(GetEntityCoords(flyer), GetEntityCoords(drone.target)) < Config.Combat.engagementDistanceMax * 1.5
        if safe and not threatNear then
            SetState(drone, 'RETURNING')
        end
        StateMachine.UpdateSiren(drone)
        return
    end

    -- Withdrawal runs to completion on its own timer and is checked BEFORE
    -- target selection: the drone is deliberately flying away from the target it
    -- just called a strike on, so letting normal targeting run would drag it
    -- straight back in and it would never leave.
    if drone.state == 'WITHDRAWING' then
        local done = GetGameTimer() >= (drone.withdrawUntil or 0)

        -- A stationed drone is also finished the moment it actually gets home,
        -- rather than circling its own post until the timer runs out.
        if not done and drone.station then
            local coords = GetEntityCoords(Utils.Flyer(drone))
            if Utils.Vdist(coords, Patrol.GetHoldDestination(drone)) < 8.0 then
                done = true
            end
        end

        if done then
            Targeting.ClearTarget(drone)
            SetState(drone, 'RETURNING')
        end
        StateMachine.UpdateSiren(drone)
        return
    end

    if drone.state == 'DESTROYED' then return end

    -- Refresh which target we should care about.
    local target = Targeting.SelectTarget(drone)

    if target and DoesEntityExist(target) and not IsEntityDead(target) then
        local mem = drone.knownTargets[target]
        local dist = mem and mem.distance or Utils.Vdist(GetEntityCoords(flyer), GetEntityCoords(target))

        if mem and mem.isVisible then
            drone.lastKnownPos = mem.lastSeenCoords

            local isUrgent = (drone.currentAttacker == target) or (drone.lastDamager == target)
            local confirmed = isUrgent or (GetGameTimer() - (mem.firstSeenTime or 0)) >= Config.Detection.confirmDuration

            if not confirmed then
                -- Freshly spotted and not (yet) hostile-confirmed: approach
                -- cautiously to get a better look before committing to combat.
                Warning.Pause(drone, 'unconfirmed')
                SetState(drone, 'INVESTIGATING')
            elseif Warning.Evaluate(drone, target, isUrgent) == 'warn' then
                -- Challenge before killing: hold fire, sound the alert and give
                -- the player a countdown to clear the area. The server owns the
                -- clock and tells everyone when it runs out (see warning.lua).
                -- The escape check only applies once a countdown is actually
                -- running: "leave the area" is measured from the moment the
                -- drone starts challenging, so a player spotted at the very
                -- edge of detection still gets approached and warned rather
                -- than being treated as having already complied.
                if drone.warning and Warning.HasEscaped(drone, target) then
                    Warning.Cancel(drone, 'escaped')
                    Targeting.ClearTarget(drone)
                    -- Forget them too, or the next scan re-selects them from
                    -- memory and the drone never actually stands down.
                    drone.knownTargets[target] = nil
                    SetState(drone, 'RETURNING')
                else
                    Warning.Sustain(drone, target)
                    SetState(drone, 'WARNING')
                end
            else
                -- The countdown has run out. Either the drone is a spotter and
                -- breaks off to call a strike in, or (strike disabled, or one
                -- already landed on this player recently) it does the job itself.
                Warning.Cancel(drone, 'countdown expired')

                if Config.Strike.enabled and StateMachine.BeginWithdrawal(drone, target) then
                    -- Withdrawing; the strike thread runs independently now.
                elseif dist <= Config.Combat.engagementDistanceMax then
                    SetState(drone, 'ENGAGING')
                else
                    SetState(drone, 'TRACKING')
                end
            end
            drone.searchStartedAt = nil
        else
            -- We have a target identity but can't currently see it.
            if drone.state == 'ENGAGING' or drone.state == 'TRACKING'
                or drone.state == 'INVESTIGATING' or drone.state == 'WARNING' then
                Warning.Pause(drone, 'lost line of sight')
                SetState(drone, 'LOST_TARGET')
            end
        end
    end

    if drone.state == 'LOST_TARGET' then
        drone.searchStartedAt = drone.searchStartedAt or GetGameTimer()
        drone.searchWaypoints = BuildSearchWaypoints(drone.lastKnownPos or GetEntityCoords(flyer))
        drone.searchWaypointIndex = 1
        drone.searchWaypointReachedAt = nil
        SetState(drone, 'SEARCHING')
    end

    if drone.state == 'SEARCHING' then
        local elapsed = GetGameTimer() - (drone.searchStartedAt or GetGameTimer())
        if elapsed > Config.Search.duration then
            Targeting.ClearTarget(drone)
            drone.searchStartedAt = nil
            SetState(drone, 'RETURNING')
        end
        StateMachine.UpdateSiren(drone)
        return
    end

    if not target and drone.state ~= 'SEARCHING' then
        Warning.Pause(drone, 'no target')
        SetState(drone, 'PATROL')
    end

    StateMachine.UpdateSiren(drone)
end

-- The siren follows the state, and Audio.RequestSiren is a no-op unless the
-- state actually changed, so this is safe to call on every decision tick.
function StateMachine.UpdateSiren(drone)
    Audio.RequestSiren(drone, SIREN_STATES[drone.state] == true)
end

-- Breaks the drone off and calls the airstrike in. Returns false if no strike
-- was actually called (already on cooldown for this player), so the caller can
-- fall back to engaging instead -- withdrawing without calling anything in would
-- leave the drone endlessly retreating from a target it never does anything to.
--
-- The escape heading is fixed once, here, rather than recomputed each tick: the
-- target is about to be under fire and may move anywhere, and a drone that kept
-- re-deriving "away from them" would visibly wander instead of leaving.
function StateMachine.BeginWithdrawal(drone, target)
    if drone.state == 'WITHDRAWING' then return true end
    if not Strike.Call(drone, target) then return false end

    local coords = GetEntityCoords(Utils.Flyer(drone))
    local away = Utils.Normalize(coords - GetEntityCoords(target))
    if #away < 0.01 then
        away = GetEntityForwardVector(Utils.Flyer(drone))
    end

    drone.withdrawDir = vector3(away.x, away.y, 0.0)
    drone.withdrawUntil = GetGameTimer() + Config.Strike.withdrawTime

    SetState(drone, 'WITHDRAWING')
    return true
end

-- =============================================================================
-- REACTIVE HOOKS (called from main.lua's damage event handler)
-- =============================================================================

function StateMachine.OnDamaged(drone, attacker)
    drone.lastDamager = attacker
    drone.currentAttacker = attacker
    drone.lastAttackedTime = GetGameTimer()
    if drone.state ~= 'RETREATING' and drone.state ~= 'DESTROYED' then
        SetState(drone, 'DAMAGED')
    end
end

function StateMachine.CallForBackup(drone)
    if not ActiveDrones then return end
    local coords = GetEntityCoords(Utils.Flyer(drone))
    for _, other in pairs(ActiveDrones) do
        if other ~= drone and DoesEntityExist(other.ped) and other.state ~= 'DESTROYED' then
            local d = Utils.Vdist(coords, GetEntityCoords(Utils.Flyer(other)))
            if d <= Config.Damage.backupCallRadius and drone.target then
                other.target = drone.target
                other.targetLockedAt = GetGameTimer()
                other.knownTargets[drone.target] = other.knownTargets[drone.target] or {
                    lastSeenCoords = GetEntityCoords(drone.target),
                    lastSeenTime = GetGameTimer(),
                    isVisible = false,
                    firstSeenTime = GetGameTimer(),
                }
            end
        end
    end
end

-- =============================================================================
-- FLIGHT TICK (high frequency)
-- =============================================================================

-- Extra altitude to add to a target-following destination while something is in
-- the way. Grinding along a wall at the target's height rarely restores line of
-- sight in a city; going over the obstruction almost always does.
local function BlockedClimb(drone)
    if drone.sense and drone.sense.blocked then
        return Config.Movement.blockedClimbBoost
    end
    return 0.0
end

function StateMachine.FlightTick(drone, dt)
    -- In piloted mode, do nothing until the vehicle has been resolved. Moving
    -- the drone before then would drive the PILOT ped instead, and teleporting
    -- a ped that's sitting in a vehicle rips it out of the seat.
    if Config.FlightMode == 'piloted' and not Utils.IsPiloted(drone) then return end

    local ped = Utils.Flyer(drone) -- positional queries below refer to whatever is flying
    local state = drone.state

    if state == 'DESTROYED' then
        return
    elseif state == 'IDLE' then
        -- Hold current position/altitude.
        local coords = GetEntityCoords(ped)
        local groundZ = Utils.GetGroundZ(coords)
        Movement.SeekPosition(drone, vector3(coords.x, coords.y, groundZ + Config.Movement.patrolHoverHeight), dt, 0.3)

    elseif state == 'PATROL' then
        Patrol.Update(drone)
        local dest = Patrol.GetHoldDestination(drone)
        Movement.SeekPosition(drone, dest, dt, Config.PatrolSpeedFactor)

        -- On station and settled: hold the configured heading. FaceVelocity has
        -- nothing to work with once the drone has stopped moving, so a hovering
        -- drone would otherwise keep whatever facing it arrived with.
        if drone.stationHeading and Utils.Vdist(GetEntityCoords(ped), dest) < 6.0 then
            Movement.FaceHeading(drone, drone.stationHeading, dt)
        else
            Movement.FaceVelocity(drone, dt)
        end

    elseif state == 'INVESTIGATING' then
        local target = drone.target
        if target and DoesEntityExist(target) then
            local tCoords = GetEntityCoords(target)
            -- Approach cautiously and a little higher than combat hover height
            -- so it can visually confirm the target without immediately
            -- committing to an attack run.
            local dest = vector3(tCoords.x, tCoords.y,
                tCoords.z + Config.Combat.hoverHeightOffset + 3.0 + BlockedClimb(drone))
            Movement.SeekPosition(drone, dest, dt, 0.6)
            Movement.FacePoint(drone, tCoords, dt)
        end

    elseif state == 'WARNING' then
        local target = drone.target
        if target and DoesEntityExist(target) then
            local tCoords = GetEntityCoords(target)
            -- Shadow the player at standoff range while the countdown runs:
            -- close enough to be unmistakably about them, far enough that it
            -- reads as a challenge rather than an attack. Weapons stay cold --
            -- there is deliberately no Combat.UpdateFiring in this branch.
            local center = vector3(tCoords.x, tCoords.y,
                tCoords.z + Config.Warning.hoverHeightOffset + BlockedClimb(drone))
            local dest = Movement.GetOrbitPoint(drone, center, Config.Warning.standoffDistance,
                Config.Warning.orbitSpeed, dt)
            Movement.SeekPosition(drone, dest, dt, Config.Warning.speedFactor)
            Movement.FacePoint(drone, tCoords, dt)
        end

    elseif state == 'TRACKING' then
        local target = drone.target
        if target and DoesEntityExist(target) then
            local tCoords = GetEntityCoords(target)
            local dest = vector3(tCoords.x, tCoords.y,
                tCoords.z + Config.Combat.hoverHeightOffset + BlockedClimb(drone))
            Movement.SeekPosition(drone, dest, dt, 1.0)
            Movement.FacePoint(drone, tCoords, dt)
            -- Closing the distance is no reason to hold fire: shoot anything
            -- visible inside weapon range while still moving in.
            Combat.UpdateFiring(drone, target)
        end

    elseif state == 'ENGAGING' then
        local target = drone.target
        if target and DoesEntityExist(target) then
            Squad.AssignRole(drone, target)
            local dest = Combat.GetDesiredPosition(drone, target, dt)
            local sep = Squad.GetSeparationVector(drone)
            dest = dest + sep * 3.0
            Movement.SeekPosition(drone, dest, dt, 1.0)
            Movement.FacePoint(drone, GetEntityCoords(target), dt)
            Combat.UpdateFiring(drone, target)
        end

    elseif state == 'WITHDRAWING' then
        local dest

        if drone.station and Config.Strike.withdrawToStation ~= false then
            -- A stationed drone withdraws by GOING HOME, not by climbing away.
            -- Its post is somewhere else entirely, so heading straight there
            -- clears the blast radius just as well and it ends up back where it
            -- belongs instead of hanging in the sky waiting for a timer.
            dest = Patrol.GetHoldDestination(drone)
        else
            -- No station: clear the area fast and high. The altitude gain keeps
            -- it out of its own blast radius as the salvo comes down.
            local coords = GetEntityCoords(ped)
            local away = drone.withdrawDir or GetEntityForwardVector(ped)
            dest = coords + away * 30.0 + vector3(0.0, 0.0, Config.Strike.withdrawAltitude)
        end

        Movement.SeekPosition(drone, dest, dt, 1.0)
        Movement.FaceVelocity(drone, dt)

    elseif state == 'SEARCHING' then
        local wps = drone.searchWaypoints
        if wps and #wps > 0 then
            local point = wps[drone.searchWaypointIndex]
            local groundZ = Utils.GetGroundZ(point)
            local dest = vector3(point.x, point.y, groundZ + Config.Movement.patrolHoverHeight * 0.6)
            local dist = Movement.SeekPosition(drone, dest, dt, 0.7)
            Movement.FaceVelocity(drone, dt)

            if dist < 3.0 then
                if not drone.searchWaypointReachedAt then
                    drone.searchWaypointReachedAt = GetGameTimer()
                elseif GetGameTimer() - drone.searchWaypointReachedAt > Config.Search.waypointDwell then
                    drone.searchWaypointIndex = drone.searchWaypointIndex + 1
                    drone.searchWaypointReachedAt = nil
                    if drone.searchWaypointIndex > #wps then
                        drone.searchWaypointIndex = 1
                    end
                end
            end
        end

    elseif state == 'RETURNING' then
        local dest = Patrol.GetHoldDestination(drone)
        local dist = Movement.SeekPosition(drone, dest, dt, 0.6)
        Movement.FaceVelocity(drone, dt)
        if dist < 4.0 then
            SetState(drone, 'PATROL')
        end

    elseif state == 'RETREATING' then
        local coords = GetEntityCoords(ped)
        local away = vector3(0.0, 0.0, 0.0)
        if drone.target and DoesEntityExist(drone.target) then
            away = Utils.Normalize(coords - GetEntityCoords(drone.target))
        elseif #drone.velocity > 0.1 then
            away = Utils.Normalize(drone.velocity)
        else
            away = GetEntityForwardVector(ped)
        end
        local dest = coords + away * 15.0 + vector3(0, 0, Config.Damage.criticalAltitudeBoost)
        Movement.SeekPosition(drone, dest, dt, 1.0)
        Movement.FaceVelocity(drone, dt)

    elseif state == 'DAMAGED' then
        -- Transient reactive state: face the attacker briefly, then Decide()
        -- will move us into TRACKING/ENGAGING/SEARCHING next tick based on
        -- whether we can actually see them.
        if drone.currentAttacker and DoesEntityExist(drone.currentAttacker) then
            Movement.FacePoint(drone, GetEntityCoords(drone.currentAttacker), dt)
        end
        local coords = GetEntityCoords(ped)
        local groundZ = Utils.GetGroundZ(coords)
        Movement.SeekPosition(drone, vector3(coords.x, coords.y, math.max(coords.z, groundZ + Config.Movement.minAltitudeAboveGround + 2.0)), dt, 0.5)
    end
end
