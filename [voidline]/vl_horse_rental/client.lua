local ox_lib = exports.ox_lib

local rentalPed = nil
local spawnedMount = nil
local isRiding = false

local PED_COORDS = vec4(2833.8660, 3670.5864, 49.7347, 183.8716)
local PED_MODEL = `a_m_m_farmer_01`
local MOUNT_MODEL = `a_c_deer`

local ANIM_DICT = "rcmjosh2"
local ANIM_NAME = "josh_sitting_loop"

local function showNotify(data)
    if lib and lib.notify then
        lib.notify(data)
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(data.description or data.title)
        DrawNotification(false, true)
    end
end

local function startRiding()
    local playerPed = PlayerPedId()

    RequestAnimDict(ANIM_DICT)
    while not HasAnimDictLoaded(ANIM_DICT) do Wait(10) end

    local spineBone = GetEntityBoneIndexByName(spawnedMount, "SKEL_Spine3")
    AttachEntityToEntity(playerPed, spawnedMount, spineBone, 0.0, 0.0, 0.25, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
    TaskPlayAnim(playerPed, ANIM_DICT, ANIM_NAME, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    isRiding = true

    showNotify({
        title = 'Mount Rental',
        description = 'Mounted! Use [WASD] to drive and press [F] to dismount.',
        type = 'success'
    })

    CreateThread(function()
        while isRiding and DoesEntityExist(spawnedMount) do
            Wait(0)
            
            if isRiding and not IsEntityPlayingAnim(playerPed, ANIM_DICT, ANIM_NAME, 3) then
                TaskPlayAnim(playerPed, ANIM_DICT, ANIM_NAME, 8.0, -8.0, -1, 1, 0, false, false, false)
            end

            if IsControlJustPressed(0, 75) then
                TriggerEvent('horse_rental:dismount')
                break
            end

            local heading = GetEntityHeading(spawnedMount)

            if IsControlPressed(0, 34) then
                SetEntityHeading(spawnedMount, heading + 2.0)
            elseif IsControlPressed(0, 35) then
                SetEntityHeading(spawnedMount, heading - 2.0)
            end

            if IsControlPressed(0, 32) then
                TaskGoStraightToCoord(spawnedMount, GetOffsetFromEntityInWorldCoords(spawnedMount, 0.0, 3.0, 0.0), 3.5, -1, heading, 0.0)
            elseif IsControlPressed(0, 33) then
                TaskGoStraightToCoord(spawnedMount, GetOffsetFromEntityInWorldCoords(spawnedMount, 0.0, -2.0, 0.0), 1.5, -1, heading, 0.0)
            else
                ClearPedTasks(spawnedMount)
            end
        end
    end)
end

CreateThread(function()
    RequestModel(PED_MODEL)
    while not HasModelLoaded(PED_MODEL) do Wait(50) end

    rentalPed = CreatePed(4, PED_MODEL, PED_COORDS.x, PED_COORDS.y, PED_COORDS.z, PED_COORDS.w, false, false)
    SetEntityHeading(rentalPed, PED_COORDS.w)
    FreezeEntityPosition(rentalPed, true)
    SetEntityInvincible(rentalPed, true)
    SetBlockingOfNonTemporaryEvents(rentalPed, true)

    exports.ox_target:addBoxZone({
        coords = vec3(PED_COORDS.x, PED_COORDS.y, PED_COORDS.z),
        size = vec3(2.5, 2.5, 3.0),
        rotation = PED_COORDS.w,
        debug = false,
        options = {
            {
                name = 'rent_horse',
                icon = 'fa-solid fa-horse',
                label = 'Rent a Horse (Free)',
                onSelect = function()
                    TriggerEvent('horse_rental:spawnHorse')
                end
            },
            {
                name = 'return_horse',
                icon = 'fa-solid fa-hand-holding',
                label = 'Return Mount',
                onSelect = function()
                    TriggerEvent('horse_rental:returnHorse')
                end
            }
        }
    })
end)

local function startFleeMonitor()
    CreateThread(function()
        local lastHealth = GetEntityHealth(spawnedMount)
        
        while DoesEntityExist(spawnedMount) do
            Wait(100)
            local currentHealth = GetEntityHealth(spawnedMount)

            if HasEntityBeenDamagedByAnyPed(spawnedMount) 
               or currentHealth < lastHealth 
               or IsPedInCombat(spawnedMount, 0) 
               or IsPedHurt(spawnedMount) then

                if isRiding then
                    TriggerEvent('horse_rental:dismount')
                end

                SetEntityInvincible(spawnedMount, false)
                SetBlockingOfNonTemporaryEvents(spawnedMount, false)
                SetPedFleeAttributes(spawnedMount, 0, 0)
                SetPedCombatAttributes(spawnedMount, 17, 1)

                local attacker = GetPedSourceOfDamage(spawnedMount)
                if not DoesEntityExist(attacker) or attacker == 0 then
                    attacker = PlayerPedId()
                end

                TaskSmartFleePed(spawnedMount, attacker, 200.0, -1, false, false)
                
                showNotify({ title = 'Mount Rental', description = 'Your horse got spooked and fled!', type = 'error' })
                break
            end
            
            lastHealth = currentHealth
        end
    end)
end

RegisterNetEvent('horse_rental:spawnHorse', function()
    if DoesEntityExist(spawnedMount) then
        showNotify({ title = 'Mount Rental', description = 'You already have an active rental!', type = 'error' })
        return
    end

    RequestModel(MOUNT_MODEL)
    while not HasModelLoaded(MOUNT_MODEL) do Wait(50) end

    local spawnPos = GetOffsetFromEntityInWorldCoords(rentalPed, 0.0, 2.5, 0.0)
    spawnedMount = CreatePed(28, MOUNT_MODEL, spawnPos.x, spawnPos.y, spawnPos.z, PED_COORDS.w, true, true)
    
    if DoesEntityExist(spawnedMount) then
        SetEntityAsMissionEntity(spawnedMount, true, true)
        SetBlockingOfNonTemporaryEvents(spawnedMount, true)

        SetEntityInvincible(spawnedMount, true)
        SetPedCanRagdoll(spawnedMount, false)
        SetEntityProofs(spawnedMount, true, true, true, true, true, true, true, true)

        exports.ox_target:addLocalEntity(spawnedMount, {
            {
                name = 'mount_horse',
                icon = 'fa-solid fa-horse-head',
                label = 'Mount Horse',
                canInteract = function()
                    return not isRiding
                end,
                onSelect = function()
                    TriggerEvent('horse_rental:mountHorse')
                end
            }
        })

        startFleeMonitor()
        startRiding()
    end
end)

RegisterNetEvent('horse_rental:mountHorse', function()
    if not DoesEntityExist(spawnedMount) then
        showNotify({ title = 'Mount Rental', description = 'You do not have a horse spawned!', type = 'error' })
        return
    end

    if isRiding then
        showNotify({ title = 'Mount Rental', description = 'You are already riding!', type = 'error' })
        return
    end

    SetBlockingOfNonTemporaryEvents(spawnedMount, true)
    ClearPedTasks(spawnedMount)

    startRiding()
end)

RegisterNetEvent('horse_rental:dismount', function()
    local playerPed = PlayerPedId()
    isRiding = false

    DetachEntity(playerPed, true, true)
    ClearPedTasksImmediately(playerPed)
    StopAnimTask(playerPed, ANIM_DICT, ANIM_NAME, 3.0)
    RemoveAnimDict(ANIM_DICT)
    
    SetEntityCollision(playerPed, true, true)

    if DoesEntityExist(spawnedMount) then
        ClearPedTasks(spawnedMount)
    end

    showNotify({ title = 'Mount Rental', description = 'You dismounted.', type = 'info' })
end)

RegisterNetEvent('horse_rental:returnHorse', function()
    if DoesEntityExist(spawnedMount) then
        TriggerEvent('horse_rental:dismount')
        Wait(100)
        
        exports.ox_target:removeLocalEntity(spawnedMount)
        DeleteEntity(spawnedMount)
        spawnedMount = nil
        
        showNotify({ title = 'Mount Rental', description = 'You returned your mount.', type = 'info' })
    else
        showNotify({ title = 'Mount Rental', description = 'No active rental found.', type = 'error' })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if DoesEntityExist(rentalPed) then DeleteEntity(rentalPed) end
        if DoesEntityExist(spawnedMount) then DeleteEntity(spawnedMount) end
    end
end)