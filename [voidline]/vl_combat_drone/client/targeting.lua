-- =============================================================================
-- combat_drone / client/targeting.lua
--
-- Scores every currently-known target using Config.TargetPriority and picks
-- the best one, but respects a target-lock cooldown so the drone doesn't
-- flip targets every frame -- it only swaps early if a new candidate clearly
-- outranks the current lock (attacker/damager overriding a random passerby).
-- =============================================================================

Targeting = {}

local function PedHasAnyWeapon(ped, weaponList)
    for _, w in ipairs(weaponList) do
        if HasPedGotWeapon(ped, w, false) then return true end
    end
    return false
end

local function ScoreTarget(drone, target, mem)
    local best = 0

    for _, rule in ipairs(Config.TargetPriority) do
        local matches = false

        if rule.kind == 'attacker' then
            matches = (drone.currentAttacker == target) and (GetGameTimer() - (drone.lastAttackedTime or 0)) < 4000
        elseif rule.kind == 'damager' then
            matches = (drone.lastDamager == target)
        elseif rule.kind == 'weaponHolder' then
            matches = IsPedAPlayer(target) and rule.weapons and PedHasAnyWeapon(target, rule.weapons)
        elseif rule.kind == 'closestHostile' then
            matches = IsPedAPlayer(target)
        elseif rule.kind == 'hostileNpc' then
            matches = Config.Detection.detectNpcs and not IsPedAPlayer(target)
        end

        if matches and rule.weight > best then
            best = rule.weight
        end
    end

    -- Closer visible targets get a small tiebreaker bonus so "closestHostile"
    -- actually prefers the closest among equally-ranked players.
    if mem.distance then
        best = best + math.max(0.0, (Config.Detection.radius - mem.distance)) * 0.1
    end

    if not mem.isVisible then
        best = best * 0.4 -- heavily discount targets we currently can't see
    end

    return best
end

-- Returns the chosen target entity (or nil), applying lock/cooldown rules.
function Targeting.SelectTarget(drone)
    local now = GetGameTimer()
    local bestTarget, bestScore = nil, -1

    for target, mem in pairs(drone.knownTargets) do
        if DoesEntityExist(target) and not IsEntityDead(target) then
            local score = ScoreTarget(drone, target, mem)
            if score > bestScore then
                bestScore = score
                bestTarget = target
            end
        end
    end

    if not bestTarget then
        return drone.target -- keep whatever we had (memory phase decides what happens next)
    end

    if not drone.target then
        drone.target = bestTarget
        drone.targetLockedAt = now
        drone.targetScore = bestScore
        return drone.target
    end

    if bestTarget == drone.target then
        drone.targetScore = bestScore
        return drone.target
    end

    -- Candidate differs from current lock: only switch if cooldown elapsed,
    -- OR the candidate clearly outranks the current target (e.g. someone just
    -- opened fire on the drone).
    local lockedFor = now - (drone.targetLockedAt or 0)
    local scoreDelta = bestScore - (drone.targetScore or 0)

    if lockedFor >= Config.TargetLock.switchCooldown or scoreDelta >= Config.TargetLock.forceSwitchPriorityDelta then
        drone.target = bestTarget
        drone.targetLockedAt = now
        drone.targetScore = bestScore
    end

    return drone.target
end

function Targeting.ClearTarget(drone)
    drone.target = nil
    drone.targetLockedAt = nil
    drone.targetScore = nil
end
