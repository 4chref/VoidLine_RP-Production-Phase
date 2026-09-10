local isOpen = false
local ped = nil
local zOffset = nil -- live copy of Config.PedZOffset, used to print pasteable coords

local function closeShop()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openShop()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', categories = Config.Categories, items = Config.Items, label = Config.ShopLabel })
end

RegisterNUICallback('close', function(_, cb)
    closeShop()
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    lib.callback('vl_dailygoods:server:buy', false, function(result)
        cb(result or { success = false })
    end, data.name)
end)

-- Z of the floor directly under the spawn point. Returns nil when nothing is
-- hit, so the caller can fall back to the fixed offset rather than dropping the
-- vendor out of the world.
local function findGroundZ()
    local x, y, z = Config.Coords.x, Config.Coords.y, Config.Coords.z

    local handle = StartShapeTestLosProbe(
        x, y, z + (Config.GroundProbeUp or 1.0),
        x, y, z - (Config.GroundProbeDown or 3.0),
        1 + 16, -- world geometry + objects; peds and vehicles are not floor
        0, 7
    )

    local retval, hit, endCoords
    local guard = 0
    repeat
        retval, hit, endCoords = GetShapeTestResult(handle)
        guard = guard + 1
        if retval == 0 and guard < 20 then Wait(0) end
    until retval ~= 0 or guard >= 20

    -- GetShapeTestResult returns `hit` as a Lua boolean, not 0/1.
    if not (hit == true or hit == 1) or not endCoords then return nil end
    return endCoords.z
end

local function spawnPed()
    local model = joaat(Config.PedModel)
    lib.requestModel(model)

    zOffset = Config.PedZOffset or 1.0
    local z = Config.Coords.z - zOffset

    if Config.SnapToGround then
        local groundZ = findGroundZ()
        if groundZ then
            z = groundZ
            zOffset = Config.Coords.z - groundZ -- keep /dgsave's maths honest
        else
            print('[vl_dailygoods] No floor found under the vendor - falling back to Config.PedZOffset.')
        end
    end

    ped = CreatePed(4, model, Config.Coords.x, Config.Coords.y, z, Config.Coords.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)

    if Config.PedScenario and Config.PedScenario ~= '' then
        TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'vl_dailygoods_open',
            icon = 'fa-solid fa-basket-shopping',
            label = 'Browse ' .. Config.ShopLabel,
            distance = Config.InteractDistance,
            onSelect = openShop,
        },
    })
end

CreateThread(function()
    spawnPed()
end)

-- =============================================================================
-- POSITIONING HELPERS
-- =============================================================================
-- A seated scenario does not put the ped's body where its origin is: the pose
-- lifts the torso onto an implied seat and plants it slightly forward, so the
-- coordinate you stand on is never the coordinate the vendor should spawn at.
-- Getting him onto a specific couch cushion is therefore a nudge-until-it-looks
-- right job, and these commands do that live instead of via restart cycles.
--
-- Everything here is client-side and moves only YOUR copy of the ped. Once it
-- looks right, paste the printed vector4 into Config.Coords so every player
-- gets it.
--
--   /dghere        snap the vendor to where you are standing, facing your way
--   /dgmove f r u  nudge: forward, right, up (metres, relative to HIS facing)
--   /dgturn 15     rotate him 15 degrees
--   /dgsave        print the vector4 to paste into Config.Coords

local function reseat()
    if Config.PedScenario and Config.PedScenario ~= '' then
        -- Moving a ped mid-scenario drops it out of the anim, so the pose has
        -- to be restarted after every reposition.
        TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)
    end
end

local function havePed()
    if ped and DoesEntityExist(ped) then return true end
    print('[vl_dailygoods] Vendor ped does not exist on this client.')
    return false
end

-- What to paste into Config.Coords: the vendor's actual position right now,
-- with PedZOffset added back on because spawnPed() subtracts it again on load.
local function printCoords()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    print(('[vl_dailygoods] Config.Coords = vector4(%.2f, %.2f, %.2f, %.0f)')
        :format(c.x, c.y, c.z + (zOffset or 0.0), h))
end

RegisterCommand('dghere', function()
    if not havePed() then return end
    local me = PlayerPedId()
    local c = GetEntityCoords(me)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(me))
    reseat()
    printCoords()
end, false)

RegisterCommand('dgmove', function(_, args)
    if not havePed() then return end
    local fwd = tonumber(args[1]) or 0.0
    local right = tonumber(args[2]) or 0.0
    local up = tonumber(args[3]) or 0.0

    -- Nudges are relative to the way the vendor faces, so "back a bit" is one
    -- number regardless of which way the couch happens to point.
    local h = math.rad(GetEntityHeading(ped))
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = math.cos(h), math.sin(h)

    local c = GetEntityCoords(ped)
    SetEntityCoordsNoOffset(ped,
        c.x + fx * fwd + rx * right,
        c.y + fy * fwd + ry * right,
        c.z + up, false, false, false)
    reseat()
    printCoords()
end, false)

RegisterCommand('dgturn', function(_, args)
    if not havePed() then return end
    SetEntityHeading(ped, (GetEntityHeading(ped) + (tonumber(args[1]) or 0.0)) % 360.0)
    reseat()
    printCoords()
end, false)

RegisterCommand('dgsave', function()
    if not havePed() then return end
    printCoords()
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if ped and DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end)
