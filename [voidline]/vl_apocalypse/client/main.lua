-- =============================================================================
-- vl_apocalypse -- client
--
-- Three jobs, in order of how much they matter:
--
--   1. DELETE ambient vehicles that already exist. Density multipliers stop new
--      spawns; they never remove what is already in the world.
--   2. SUPPRESS the aircraft models that ambient air traffic actually uses.
--      This is the gap that let helicopters through with every traffic density
--      at zero -- aircraft do not come from the traffic system at all.
--   3. Set the persistent world flags (boats, trains, cops, generators).
--
-- It does NOT set the per-frame density multipliers while qbx_density is
-- running, because qbx_density is already doing exactly that at Wait(0). See
-- Config.Density.
-- =============================================================================

local RESOURCE = GetCurrentResourceName()

local function log(fmt, ...)
    if Config.Debug.Enabled then print(('[%s] ' .. fmt):format(RESOURCE, ...)) end
end

-- Live state, mirrored from GlobalState so an admin can switch the whole thing
-- off without a restart.
local active = Config.Enabled

-- Counters for /apocalypse_diag.
local stats = { vehicles = 0, peds = 0, aircraft = 0, sweeps = 0 }


-- =============================================================================
-- POPULATION TYPES
--
-- GetEntityPopulationType is the engine's own record of how an entity came into
-- the world, and it is the only test here that actually matters. Everything
-- else in isDeletable() is a second opinion.
-- =============================================================================

local AMBIENT_POP = {
    [1] = true,   -- RANDOM_PERMANENT
    [2] = true,   -- RANDOM_PARKED
    [3] = true,   -- RANDOM_PATROL
    [4] = true,   -- RANDOM_SCENARIO
    [5] = true,   -- RANDOM_AMBIENT
    -- 0 UNKNOWN, 6 PERMANENT, 7 MISSION, 8 REPLAY, 9 CACHE, 10 TOOL are all
    -- deliberately absent. 6 and 7 are what player and scripted vehicles are.
}

-- GTA vehicle classes. 15 and 16 are the only two this resource cares about.
local CLASS_HELI = 15
local CLASS_PLANE = 16

---@param veh number
---@return boolean
local function isAircraft(veh)
    local class = GetVehicleClass(veh)
    return class == CLASS_HELI or class == CLASS_PLANE
end

---Is any PLAYER inside this vehicle? Checked seat by seat rather than trusting
---the driver seat alone -- a passenger is just as much a reason not to delete.
---@param veh number
---@return boolean
local function hasPlayerInside(veh)
    if not IsVehicleSeatFree(veh, -1) then
        local driver = GetPedInVehicleSeat(veh, -1)
        if driver ~= 0 and IsPedAPlayer(driver) then return true end
    end

    local seats = GetVehicleMaxNumberOfPassengers(veh)
    for seat = 0, seats - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end

    return false
end

---@param veh number
---@return boolean deletable, boolean isAir
local function isDeletable(veh)
    if not DoesEntityExist(veh) then return false, false end

    -- 1. The population type. A player's car is PERMANENT or MISSION and can
    --    never pass this, which is what makes the sweep safe to run on a timer.
    if not AMBIENT_POP[GetEntityPopulationType(veh)] then return false, false end

    -- 2. Mission entities. Anything a script has claimed with
    --    SetEntityAsMissionEntity, even if the engine still calls it ambient.
    if IsEntityAMissionEntity(veh) then return false, false end

    -- 3. Networked. Ambient population is client-local in FiveM, so this only
    --    ever excludes scripted and other players' vehicles.
    if Config.Cleanup.SkipNetworked and NetworkGetEntityIsNetworked(veh) then
        return false, false
    end

    -- 4. Anyone in it, and anything holding it -- a car on a tow truck or a
    --    flatbed is attached, and deleting it under the driver is worse than
    --    leaving it.
    if hasPlayerInside(veh) then return false, false end
    if IsEntityAttached(veh) then return false, false end

    -- The player's own vehicle, belt and braces: a personal vehicle should
    -- already have failed the population-type test, but this costs nothing.
    local ped = PlayerPedId()
    if veh == GetVehiclePedIsIn(ped, false) then return false, false end
    if veh == GetVehiclePedIsUsing(ped) then return false, false end

    -- Past the guards. Now decide whether this is a vehicle we WANT gone.
    local air = isAircraft(veh)
    if air and Config.Cleanup.Aircraft then return true, true end

    if Config.Cleanup.NpcDriven then
        local driver = GetPedInVehicleSeat(veh, -1)
        if driver ~= 0 and not IsPedAPlayer(driver) then return true, air end
    end

    if Config.Cleanup.AllAmbient then return true, air end

    return false, air
end

---@param veh number
local function removeVehicle(veh)
    -- Occupants first. Deleting the vehicle out from under them leaves NPCs
    -- standing in the road where the car used to be.
    if Config.Cleanup.Occupants then
        local seats = GetVehicleMaxNumberOfPassengers(veh)
        for seat = -1, seats - 1 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                DeletePed(ped)
                stats.peds = stats.peds + 1
            end
        end
    end

    -- A vehicle must be a mission entity before the engine will let a script
    -- delete it. This is the documented requirement on DELETE_VEHICLE, not a
    -- workaround.
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
end

local function sweep()
    local budget = Config.Cleanup.MaxPerSweep
    local removed, air = 0, 0

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if budget <= 0 then break end

        local ok, isAir = isDeletable(veh)
        if ok then
            removeVehicle(veh)
            removed = removed + 1
            if isAir then air = air + 1 end
            budget = budget - 1
        end
    end

    stats.sweeps = stats.sweeps + 1
    stats.vehicles = stats.vehicles + removed
    stats.aircraft = stats.aircraft + air

    if removed > 0 then
        log('sweep removed %d vehicle(s), %d of them aircraft', removed, air)
    end
    return removed
end


-- =============================================================================
-- SUPPRESSION AND WORLD FLAGS
--
-- All persistent natives. Applied once at start and re-asserted on a slow tick
-- purely because another resource can turn them back on.
-- =============================================================================

local function applyWorld()
    local w = Config.World

    for _, model in ipairs(Config.SuppressAircraft) do
        SetVehicleModelIsSuppressed(joaat(model), true)
    end
    for _, model in ipairs(Config.SuppressEmergency) do
        SetVehicleModelIsSuppressed(joaat(model), true)
    end

    for _, name in ipairs(Config.DisableScenarioTypes) do
        SetScenarioTypeEnabled(name, false)
    end
    for _, name in ipairs(Config.DisableScenarioGroups) do
        SetScenarioGroupEnabled(name, false)
    end

    SetRandomBoats(w.RandomBoats)
    SetRandomTrains(w.RandomTrains)
    SetGarbageTrucks(w.GarbageTrucks)
    DistantCopCarSirens(w.DistantSirens)
    SetFarDrawVehicles(w.FarDrawVehicles)

    SetCreateRandomCops(w.RandomCops)
    SetCreateRandomCopsNotOnScenarios(w.RandomCops)
    SetCreateRandomCopsOnScenarios(w.RandomCops)

    if w.NumberOfParkedVehicles then
        SetNumberOfParkedVehicles(w.NumberOfParkedVehicles)
    end
    SetAllLowPriorityVehicleGeneratorsActive(w.LowPriorityGenerators)

    -- nil means "leave the engine's own budget alone", which is why these are
    -- guarded rather than defaulted to 0.
    if w.VehicleBudget then SetVehiclePopulationBudget(w.VehicleBudget) end
    if w.PedBudget then SetPedPopulationBudget(w.PedBudget) end
end

---Undo everything applyWorld() pinned, so stopping the resource genuinely puts
---the world back instead of leaving a half-empty city until reconnect.
---
---Note this also re-enables the ten models and ten scenario types that
---qbx_smallresources/qbx_ignore disables on its own -- there is no way to tell
---"disabled by us" from "disabled by them" through these natives. That resource
---re-asserts its own list every 10 seconds, so its subset heals itself within
---one tick of it; the window is brief and only ever follows an explicit
---/apocalypse off.
local function restoreWorld()
    for _, model in ipairs(Config.SuppressAircraft) do
        SetVehicleModelIsSuppressed(joaat(model), false)
    end
    for _, model in ipairs(Config.SuppressEmergency) do
        SetVehicleModelIsSuppressed(joaat(model), false)
    end

    for _, name in ipairs(Config.DisableScenarioTypes) do
        SetScenarioTypeEnabled(name, true)
    end
    for _, name in ipairs(Config.DisableScenarioGroups) do
        SetScenarioGroupEnabled(name, true)
    end

    SetRandomBoats(true)
    SetRandomTrains(true)
    SetGarbageTrucks(true)
    DistantCopCarSirens(true)
    SetFarDrawVehicles(true)
    SetCreateRandomCops(true)
    SetCreateRandomCopsNotOnScenarios(true)
    SetCreateRandomCopsOnScenarios(true)
    SetNumberOfParkedVehicles(-1)          -- -1 is the engine default, not 0
    SetAllLowPriorityVehicleGeneratorsActive(true)
    SetVehiclePopulationBudget(3)
    SetPedPopulationBudget(3)
end


-- =============================================================================
-- DENSITY
--
-- The one thing here that needs a per-frame loop, and the one thing this
-- resource tries hardest not to do -- qbx_density already runs it. 'auto' only
-- takes over when qbx_density is not actually started.
-- =============================================================================

---@return boolean
local function shouldOwnDensity()
    local mode = Config.Density.Mode
    if mode == 'never' then return false end
    if mode == 'always' then return true end
    -- 'auto'
    return GetResourceState('qbx_density') ~= 'started'
end

local densityRunning = false

local function startDensityLoop()
    if densityRunning then return end
    densityRunning = true

    log('taking over the density multipliers (qbx_density is %s)',
        GetResourceState('qbx_density'))

    CreateThread(function()
        local d = Config.Density
        while densityRunning and active do
            SetParkedVehicleDensityMultiplierThisFrame(d.Parked)
            SetVehicleDensityMultiplierThisFrame(d.Vehicle)
            SetRandomVehicleDensityMultiplierThisFrame(d.RandomVehicles)
            SetPedDensityMultiplierThisFrame(d.Peds)
            SetScenarioPedDensityMultiplierThisFrame(d.Scenario, d.Scenario)
            Wait(0)
        end
        densityRunning = false
    end)
end


-- =============================================================================
-- LIFECYCLE
-- =============================================================================

local function setActive(state)
    if active == state then return end
    active = state

    if active then
        applyWorld()
        if shouldOwnDensity() then startDensityLoop() end
        log('ACTIVE')
    else
        densityRunning = false
        restoreWorld()
        log('OFF -- world restored')
    end
end

AddStateBagChangeHandler('vlApocalypse', 'global', function(_, _, value)
    if type(value) ~= 'table' then return end
    setActive(value.active == true)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end

    local state = GlobalState.vlApocalypse
    if type(state) == 'table' then
        active = state.active == true
    end

    if not active then
        log('starting inactive')
        return
    end

    applyWorld()
    if shouldOwnDensity() then startDensityLoop() end

    -- Two cadences, one thread: the sweep runs often, the world flags are
    -- re-asserted rarely. Re-asserting suppression every second would be ~90
    -- wasted natives per second to rewrite values that never change.
    CreateThread(function()
        local sweepMs = math.max(250, Config.Cleanup.IntervalMs)
        local elapsed = 0

        while true do
            if active then
                sweep()

                elapsed = elapsed + sweepMs
                if elapsed >= Config.ReassertMs then
                    elapsed = 0
                    applyWorld()
                end
            end
            Wait(sweepMs)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    densityRunning = false
    if active then restoreWorld() end
end)


-- =============================================================================
-- DIAGNOSTICS
--
-- Local only. /apocalypse itself is the server command and is ACE gated.
-- =============================================================================

RegisterCommand('apocalypse_diag', function()
    local pool = GetGamePool('CVehicle')
    local ambient, player, aircraft = 0, 0, 0

    for _, veh in ipairs(pool) do
        if AMBIENT_POP[GetEntityPopulationType(veh)] then
            ambient = ambient + 1
            if isAircraft(veh) then aircraft = aircraft + 1 end
        else
            player = player + 1
        end
    end

    print(('[%s] active=%s density=%s sweeps=%d'):format(RESOURCE,
        tostring(active),
        densityRunning and 'ours' or (shouldOwnDensity() and 'pending' or 'qbx_density'),
        stats.sweeps))
    print(('[%s] removed so far: %d vehicles (%d aircraft), %d peds'):format(
        RESOURCE, stats.vehicles, stats.aircraft, stats.peds))
    print(('[%s] vehicles in world right now: %d total, %d ambient (%d aircraft), '
        .. '%d player/scripted'):format(RESOURCE, #pool, ambient, aircraft, player))

    if ambient > 0 then
        print(('[%s] %d ambient left -- they are either inside the MaxPerSweep '
            .. 'budget for the next sweep, or excluded by Config.Cleanup')
            :format(RESOURCE, ambient))
    end
end, false)

-- Force one immediate sweep, ignoring the interval. Useful right after changing
-- config values to see the effect without waiting.
RegisterCommand('apocalypse_sweep', function()
    local n = sweep()
    print(('[%s] manual sweep removed %d vehicle(s)'):format(RESOURCE, n))
end, false)

exports('IsActive', function() return active end)
exports('Sweep', sweep)
exports('IsAmbient', function(entity)
    return AMBIENT_POP[GetEntityPopulationType(entity)] == true
end)
