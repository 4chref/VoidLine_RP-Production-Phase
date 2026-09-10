-- =============================================================================
-- combat_drone / client/debug.lua
-- Draws AI state, target, distance, health, LKP, radius, task and velocity
-- above each drone when Config.Debug is true. Only runs its per-frame thread
-- while debug mode is on, and only for locally-owned drones (each client
-- draws the drones it's actually simulating).
-- =============================================================================

DebugDraw = {}

local function TargetLabel(drone)
    if not drone.target or not DoesEntityExist(drone.target) then return 'none' end
    if IsPedAPlayer(drone.target) then
        local playerId = NetworkGetPlayerIndexFromPed(drone.target)
        return GetPlayerName(playerId) or ('ped:' .. tostring(drone.target))
    end
    return 'npc:' .. tostring(drone.target)
end

function DebugDraw.Draw(drone)
    if not Config.Debug then return end
    local ped = drone.ped
    if not DoesEntityExist(ped) then return end

    local coords = GetEntityCoords(ped)
    local headPos = coords + vector3(0.0, 0.0, 1.0)

    local dist = 'n/a'
    if drone.target and DoesEntityExist(drone.target) then
        dist = string.format('%.1f m', Utils.Vdist(coords, GetEntityCoords(drone.target)))
    end

    local lkp = drone.lastKnownPos and string.format('%.0f,%.0f,%.0f', drone.lastKnownPos.x, drone.lastKnownPos.y, drone.lastKnownPos.z) or 'none'
    local speed = string.format('%.1f m/s', #(drone.velocity or vector3(0,0,0)))
    local patrolPoint = drone.patrol and drone.patrol.index or 0

    local lines = {
        { text = ('STATE: %s'):format(drone.state or '?'), color = {255, 255, 0} },
        { text = ('TARGET: %s'):format(TargetLabel(drone)), color = {255, 120, 120} },
        { text = ('DIST: %s'):format(dist), color = {255, 255, 255} },
        { text = ('HP: %d / ARM: %d'):format(GetEntityHealth(ped), GetPedArmour(ped)), color = {120, 255, 120} },
        { text = ('LKP: %s'):format(lkp), color = {180, 180, 255} },
        { text = ('DET RADIUS: %.0f'):format(Config.Detection.radius), color = {180, 180, 180} },
        { text = ('SPEED: %s'):format(speed), color = {180, 180, 180} },
        { text = ('PATROL PT: %d'):format(patrolPoint), color = {180, 180, 180} },
    }

    local offset = 0.0
    for _, line in ipairs(lines) do
        Utils.DrawText3D(headPos + vector3(0.0, 0.0, offset), line.text, line.color[1], line.color[2], line.color[3])
        offset = offset + 0.22
    end

    DrawMarker(28, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        Config.Detection.radius * 2.0, Config.Detection.radius * 2.0, 1.0, 255, 255, 0, 20, false, false, 2, false, nil, nil, false)
end
