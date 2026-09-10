local doctorPed
local inBed = false

-- =========================================================================
-- Doctor NPC
-- =========================================================================

local function checkIn()
    if inBed then return end

    local success = lib.progressCircle({
        duration = 2500,
        position = 'bottom',
        label = 'Checking in with the doctor...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 16 },
    })
    if not success then return end

    local result = lib.callback.await('vl_hospital:server:checkIn', false)
    if not result then return end

    if result.cooldown then
        lib.notify({
            title = 'Doctor',
            description = ('You were just treated. Come back in %d seconds.'):format(result.cooldown),
            type = 'error',
        })
        return
    end

    if result.full then
        lib.notify({ title = 'Doctor', description = 'All beds are occupied right now, wait for one to free up.', type = 'error' })
        return
    end

    -- Server already healed/revived us; now rest in the assigned bed
    inBed = true

    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = cache.ped
    SetEntityCoords(ped, result.x, result.y, result.z + VLHospital.BedZOffset, false, false, false, false)
    SetEntityHeading(ped, result.heading)
    Wait(300)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    lib.playAnim(ped, VLHospital.SleepAnim.dict, VLHospital.SleepAnim.clip, 8.0, 1.0, -1, 1, 0, false, false, false)

    DoScreenFadeIn(600)
    lib.notify({ title = 'Doctor', description = 'You have been treated. Rest for a moment.', type = 'success' })

    -- Rest period: keep the sleep animation applied
    local wakeAt = GetGameTimer() + VLHospital.RecoverySeconds * 1000
    while GetGameTimer() < wakeAt do
        if not IsEntityPlayingAnim(ped, VLHospital.SleepAnim.dict, VLHospital.SleepAnim.clip, 3) then
            lib.playAnim(ped, VLHospital.SleepAnim.dict, VLHospital.SleepAnim.clip, 8.0, 1.0, -1, 1, 0, false, false, false)
        end
        Wait(250)
    end

    -- Wake up
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityHeading(ped, result.heading + 90.0)
    lib.playAnim(ped, VLHospital.WakeAnim.dict, VLHospital.WakeAnim.clip, 100.0, 1.0, -1, 8, 0, false, false, false)
    Wait(4000)
    ClearPedTasks(ped)

    inBed = false
    TriggerServerEvent('vl_hospital:server:leftBed')
end

local function spawnDoctor()
    if doctorPed and DoesEntityExist(doctorPed) then return end

    local model = joaat(VLHospital.Doctor.model)
    lib.requestModel(model, 30000)
    local c = VLHospital.Doctor.coords
    doctorPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(doctorPed, true)
    FreezeEntityPosition(doctorPed, true)
    SetBlockingOfNonTemporaryEvents(doctorPed, true)
    -- Marks the doctor as script-owned so world-clearing scripts (vl_apocalypse)
    -- and the engine's own population cleanup both leave it alone.
    SetEntityAsMissionEntity(doctorPed, true, true)
    TaskStartScenarioInPlace(doctorPed, VLHospital.Doctor.scenario, 0, true)

    exports.ox_target:addLocalEntity(doctorPed, {
        {
            name = 'vl_hospital_checkin',
            icon = 'fas fa-user-doctor',
            label = 'Check in (heal & rest)',
            distance = 1.0,
            onSelect = checkIn,
        },
    })
end

local function deleteDoctor()
    if doctorPed and DoesEntityExist(doctorPed) then
        exports.ox_target:removeLocalEntity(doctorPed, 'vl_hospital_checkin')
        DeleteEntity(doctorPed)
    end
    doctorPed = nil
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', spawnDoctor)

AddEventHandler('onResourceStart', function(resourceName)
    if cache.resource ~= resourceName then return end
    if LocalPlayer.state.isLoggedIn then spawnDoctor() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if cache.resource ~= resourceName then return end
    deleteDoctor()
    if inBed then
        FreezeEntityPosition(cache.ped, false)
        SetEntityInvincible(cache.ped, false)
        ClearPedTasks(cache.ped)
        TriggerServerEvent('vl_hospital:server:leftBed')
    end
end)
