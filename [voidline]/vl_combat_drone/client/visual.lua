-- =============================================================================
-- combat_drone / client/visual.lua
--
-- Cosmetic shell handling. The drone's AI entity is a PED (it flies and fires
-- genuine ped weapon damage), but drone MODELS are almost always shipped as
-- vehicle add-ons, which CreatePed cannot spawn. So the ped is hidden and the
-- model is attached to it as a visual-only shell.
--
-- The shell is deliberately NOT networked. Every client that knows about the
-- drone spawns its own local copy attached to the shared, networked ped, so:
--   * position/heading sync for free through the ped (no extra sync traffic),
--   * there is no second networked entity with its own ownership/migration,
--   * cleanup is purely local and can never orphan an entity on someone else.
--
-- A per-drone watchdog keeps the shell alive: local vehicles are fair game for
-- the engine's population cleanup, and the ped is teleported every frame by the
-- flight controller, either of which can leave the shell deleted or detached.
-- The ped is only ever hidden WHILE a shell actually exists, so a failed or
-- culled shell degrades to a visible ped rather than an invisible drone.
-- =============================================================================

Visual = {}

local shells = {}   -- ped -> shell entity (local to this client)
local watching = {} -- ped -> true while a watchdog thread is running

local warned = false

local function LoadModel(model)
    if not IsModelValid(model) or not IsModelInCdimage(model) then
        return false
    end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasModelLoaded(model)
end

local function AttachShell(shell, ped)
    local off, rot = Config.Visual.offset, Config.Visual.rotation
    AttachEntityToEntity(shell, ped, 0,
        off.x, off.y, off.z,
        rot.x, rot.y, rot.z,
        false, false, false, false, 2, true)
    -- Collision has to be re-cleared after attaching: the attach re-asserts the
    -- entity's physics state, and a colliding shell shoves the world around.
    SetEntityCollision(shell, false, false)
end

local function CreateShell(ped)
    local model = Config.Visual.model

    if not LoadModel(model) then
        if not warned then
            warned = true
            print('[combat_drone] Visual model is not streamed on this client - is the model resource running? Falling back to the plain ped.')
        end
        return nil
    end

    local coords = GetEntityCoords(ped)
    local shell

    if IsModelAVehicle(model) then
        -- isNetwork = false, netMissionEntity = false -> local-only entity
        shell = CreateVehicle(model, coords.x, coords.y, coords.z, GetEntityHeading(ped), false, false)
    else
        shell = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    end

    SetModelAsNoLongerNeeded(model)

    if not shell or shell == 0 or not DoesEntityExist(shell) then
        return nil
    end

    -- Without this the engine's population cleanup will delete a local,
    -- non-mission vehicle whenever it feels like it, which left the drone
    -- completely invisible because the ped underneath was already hidden.
    SetEntityAsMissionEntity(shell, true, true)

    if IsEntityAVehicle(shell) then
        SetVehicleDoorsLocked(shell, 4)              -- nobody can climb into the cosmetic shell
        SetVehicleEngineOn(shell, true, true, false) -- rotors/lights if the model has them
        SetVehicleRadioEnabled(shell, false)
        SetVehicleIsConsideredByPlayer(shell, false) -- never offered as an "enter vehicle" prompt
    end

    SetEntityInvincible(shell, true)
    SetEntityCanBeDamaged(shell, false) -- damage must reach the ped, which is what actually has health

    AttachShell(shell, ped)

    return shell
end

function Visual.Attach(drone)
    if not Config.Visual.enabled then return end

    local ped = drone.ped
    if not DoesEntityExist(ped) or watching[ped] then return end
    watching[ped] = true

    CreateThread(function()
        while DoesEntityExist(ped) do
            local shell = shells[ped]

            if not shell or not DoesEntityExist(shell) then
                shells[ped] = CreateShell(ped)
            elseif GetEntityAttachedTo(shell) ~= ped then
                AttachShell(shell, ped) -- re-attach if the flight teleport broke it loose
            end

            if Config.Visual.hidePed then
                local haveShell = shells[ped] and DoesEntityExist(shells[ped])
                SetEntityVisible(ped, not haveShell, false)
            end

            Wait(1000)
        end

        Visual.Detach(ped)
    end)
end

function Visual.Detach(ped)
    local shell = shells[ped]
    if shell and DoesEntityExist(shell) then
        DetachEntity(shell, true, true)
        SetEntityAsMissionEntity(shell, true, true)
        DeleteEntity(shell)
    end
    shells[ped] = nil
    watching[ped] = nil
end

function Visual.CleanupAll()
    for ped in pairs(shells) do
        Visual.Detach(ped)
    end
end
