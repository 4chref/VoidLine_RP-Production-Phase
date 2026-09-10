-- =============================================================================
-- vl_kitchen -- client
--
-- Spawns the chef and offers the ox_target interaction. Holds no authority:
-- the server decides whether the player gets anything.
-- =============================================================================

local chefPed = nil

local function collect()
    local ok, message = lib.callback.await('vl_kitchen:server:collect', false)

    lib.notify({
        title = 'Kitchen',
        description = message,
        type = ok and 'success' or 'error',
    })
end

---Resolve a usable ped model. An invalid name makes CreatePed return nothing
---and the chef never appears, with no error anywhere -- so check first, say so,
---and fall back rather than failing silently.
---@return number|nil hash
local function resolveModel()
    local cfg = VLKitchen.chef

    for _, name in ipairs({ cfg.model, cfg.fallback }) do
        if name then
            local hash = joaat(name)
            if IsModelInCdimage(hash) and IsModelAPed(hash) then
                local ok = pcall(lib.requestModel, hash, 20000)
                if ok and HasModelLoaded(hash) then
                    if name ~= cfg.model then
                        print(('[vl_kitchen] model "%s" is not valid on this build; using fallback "%s"')
                            :format(cfg.model, name))
                    end
                    return hash
                end
            else
                print(('[vl_kitchen] "%s" is not a valid ped model on this build'):format(name))
            end
        end
    end

    print('[vl_kitchen] no usable ped model - chef not spawned. Set VLKitchen.chef.model to a valid ped.')
    return nil
end

local function spawnChef()
    if chefPed and DoesEntityExist(chefPed) then return end

    local cfg = VLKitchen.chef
    local model = resolveModel()
    if not model then return end

    local c = cfg.coords
    -- No -1.0 here: the coords came from /vec4, which already applies it.
    chefPed = CreatePed(4, model, c.x, c.y, c.z, c.w, false, false)
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(chefPed, true)
    FreezeEntityPosition(chefPed, true)
    SetBlockingOfNonTemporaryEvents(chefPed, true)
    -- Marks the chef as script-owned so vl_apocalypse's world clearing and the
    -- engine's own population cleanup both leave it alone.
    SetEntityAsMissionEntity(chefPed, true, true)
    TaskStartScenarioInPlace(chefPed, cfg.scenario, 0, true)

    exports.ox_target:addLocalEntity(chefPed, {
        {
            name = 'vl_kitchen_collect',
            icon = cfg.icon,
            label = cfg.label,
            distance = cfg.distance,
            onSelect = collect,
        },
    })

    print(('[vl_kitchen] chef spawned at %.2f, %.2f, %.2f'):format(c.x, c.y, c.z))
end

-- Console helper: teleports you to the chef so you can confirm placement
-- without walking there. Client-side only, no permission implications.
RegisterCommand('kitchen_tp', function()
    local c = VLKitchen.chef.coords
    SetEntityCoords(PlayerPedId(), c.x, c.y, c.z + 1.0, false, false, false, false)
    print(('[vl_kitchen] teleported to chef. Ped exists: %s')
        :format(tostring(chefPed and DoesEntityExist(chefPed))))
end, false)

local function deleteChef()
    if chefPed and DoesEntityExist(chefPed) then
        exports.ox_target:removeLocalEntity(chefPed, 'vl_kitchen_collect')
        DeleteEntity(chefPed)
    end
    chefPed = nil
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(1000)
    spawnChef()
end)

-- Respawn after a death/reload wipes local peds.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    spawnChef()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deleteChef()
end)
