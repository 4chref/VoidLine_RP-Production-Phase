local bedOccupants = {} ---@type table<integer, number> bed index -> source
local lastCheckIn = {} ---@type table<number, number> source -> os.time() of last check-in

---@param index integer
---@param requestingSrc number
---@return boolean
local function isBedOccupied(index, requestingSrc)
    local occupant = bedOccupants[index]
    if occupant and occupant ~= requestingSrc then
        if GetPlayerName(tostring(occupant)) then return true end
        bedOccupants[index] = nil -- occupant disconnected without cleanup
    end

    -- Physical check as well, so beds used by other systems (e.g. death
    -- respawns through qbx_ambulancejob) are never double-assigned
    local bed = VLHospital.Beds[index]
    local players = GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i])
        if src ~= requestingSrc then
            local ped = GetPlayerPed(players[i])
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx, dy = coords.x - bed.x, coords.y - bed.y
                if math.sqrt(dx * dx + dy * dy) <= VLHospital.BedOccupiedRadius then
                    return true
                end
            end
        end
    end
    return false
end

---@param source number
---@return integer? bedIndex
local function allocateBed(source)
    for idx, occupant in pairs(bedOccupants) do
        if occupant == source then bedOccupants[idx] = nil end
    end
    for i = 1, #VLHospital.Beds do
        if not isBedOccupied(i, source) then
            bedOccupants[i] = source
            return i
        end
    end
end

---Check in with the doctor: heal/revive server-side and hand out a free bed.
lib.callback.register('vl_hospital:server:checkIn', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    -- Distance check: the player must actually be at the doctor. Triggering
    -- this callback from outside that radius means the client-side
    -- ox_target zone/prompt was bypassed -- treat it as an exploit attempt.
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    if #(coords - VLHospital.Doctor.coords.xyz) > 1.0 then
        DropPlayer(source, 'Kicked for exploiting: triggered hospital check-in while not near the check-in point.')
        return
    end

    local now = os.time()
    if lastCheckIn[source] and now - lastCheckIn[source] < VLHospital.CheckInCooldown then
        return { cooldown = VLHospital.CheckInCooldown - (now - lastCheckIn[source]) }
    end

    local bedIndex = allocateBed(source)
    if not bedIndex then
        return { full = true }
    end

    lastCheckIn[source] = now

    -- Revive clears death/last-stand state and restores health; Heal removes
    -- all ailments and fills hunger/thirst. Together: a complete reset.
    exports.qbx_medical:Revive(source)
    exports.qbx_medical:Heal(source)

    local bed = VLHospital.Beds[bedIndex]
    return { bedIndex = bedIndex, x = bed.x, y = bed.y, z = bed.z, heading = bed.w }
end)

RegisterNetEvent('vl_hospital:server:leftBed', function()
    local src = source
    for idx, occupant in pairs(bedOccupants) do
        if occupant == src then bedOccupants[idx] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastCheckIn[src] = nil
    for idx, occupant in pairs(bedOccupants) do
        if occupant == src then bedOccupants[idx] = nil end
    end
end)
