-- =============================================================================
-- combat_drone / client/squad.lua
--
-- Lightweight coordination so multiple drones engaging the same target don't
-- all fly to the same spot or all pick the same attack pattern. Reads the
-- global `ActiveDrones` registry populated by client/main.lua (only drones
-- this client currently owns/simulates are in there -- coordination between
-- drones owned by different clients is intentionally *not* attempted, since
-- each client only has authority over the drones it owns; this keeps the
-- system trivially safe under OneSync entity migration).
-- =============================================================================

Squad = {}

-- Returns the list of other locally-owned drones currently also targeting `target`.
local function GetSquadmates(drone, target)
    local mates = {}
    if not ActiveDrones then return mates end
    for _, other in pairs(ActiveDrones) do
        if other ~= drone and other.target == target and other.state == 'ENGAGING' then
            mates[#mates + 1] = other
        end
    end
    return mates
end

-- Assigns a role to `drone` for the given target based on a stable ordering
-- (network id) so all squadmates agree on roles without needing to talk to
-- each other every frame.
function Squad.AssignRole(drone, target)
    if not Config.Squad.enabled then
        drone.squadRole = 'engage'
        return drone.squadRole
    end

    local mates = GetSquadmates(drone, target)
    if #mates == 0 then
        drone.squadRole = 'engage'
        return drone.squadRole
    end

    local all = { drone }
    for _, m in ipairs(mates) do all[#all + 1] = m end
    table.sort(all, function(a, b)
        return (NetworkGetNetworkIdFromEntity(a.ped)) < (NetworkGetNetworkIdFromEntity(b.ped))
    end)

    local roles = Config.Squad.roles
    for i, d in ipairs(all) do
        if d == drone then
            drone.squadRole = roles[((i - 1) % #roles) + 1]
            break
        end
    end

    return drone.squadRole
end

-- Adjusts a desired engagement distance based on assigned role.
function Squad.ApplyRoleToEngageDistance(drone, baseDistance)
    if drone.squadRole == 'flank' then
        return baseDistance * 0.85
    elseif drone.squadRole == 'ranged' then
        return baseDistance * 1.4
    end
    return baseDistance
end

-- Extra steering vector to keep locally-owned drones from stacking on top of
-- each other. Added on top of normal obstacle avoidance.
function Squad.GetSeparationVector(drone)
    if not Config.Squad.enabled or not ActiveDrones then
        return vector3(0.0, 0.0, 0.0)
    end

    local coords = GetEntityCoords(Utils.Flyer(drone))
    local push = vector3(0.0, 0.0, 0.0)
    local minSep = Config.Squad.minSeparation

    for _, other in pairs(ActiveDrones) do
        if other ~= drone and DoesEntityExist(other.ped) then
            local otherCoords = GetEntityCoords(other.ped)
            local diff = coords - otherCoords
            local dist = #diff
            if dist > 0.01 and dist < minSep then
                local strength = (minSep - dist) / minSep
                push = push + Utils.Normalize(diff) * strength
            end
        end
    end

    return push
end
