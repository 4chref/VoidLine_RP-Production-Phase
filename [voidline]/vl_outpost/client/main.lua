-- =============================================================================
-- vl_outpost -- client
-- =============================================================================

local isOpen = false
local peds = {}

--- Ground markers: { coords, label, action }. Places rather than people.
local markers = {}
local currentShop = nil

-- Forward declaration: the buy callback below re-opens the repair grid after a
-- successful repair, but openRepair is defined further down. Without this the
-- callback would capture a nil GLOBAL instead of the local, and the refresh
-- would silently do nothing.
local openRepair
local openGarage
local openHeli

local function notify(msg, kind)
    pcall(function() exports.qbx_core:Notify(msg, kind or 'inform') end)
end

-- =============================================================================
-- SHOP NUI  (same markup and stylesheet as vl_campshop / vl_dailygoods)
-- =============================================================================

local function closeShop()
    if not isOpen then return end
    isOpen = false
    currentShop = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'outpost:close' })
end

local function openShop(shop)
    if isOpen then return end
    isOpen = true
    currentShop = shop
    SetNuiFocus(true, true)
    SendNUIMessage({
        -- Namespaced: the marketplace shares this NUI page and reacts to a bare
        -- 'open', so an unprefixed action opened both panels on top of one
        -- another.
        action = 'outpost:open',
        categories = shop.categories,
        items = shop.items,
        label = shop.label,
        layout = shop.layout or 'grid',
    })
end

-- Namespaced: the marketplace shares this resource and registers its own
-- 'close'. Its UI is untouched; the shop grid's callbacks moved instead.
RegisterNUICallback('outpost:close', function(_, cb)
    closeShop()
    cb('ok')
end)

RegisterNUICallback('outpost:buy', function(data, cb)
    local shop = currentShop
    if not shop then return cb({ success = false }) end

    -- The gunsmith's cards are weapons, priced per slot.
    if shop.kind == 'repair' then
        local slot = tonumber(data.slot)
        if not slot then return cb({ success = false }) end

        lib.callback('vl_outpost:server:repair', false, function(result)
            cb(result or { success = false })

            -- Rebuild the grid: the weapon just repaired is no longer damaged
            -- and must drop off the list, or it stays there at its old price.
            if result and result.success then
                closeShop()
                Wait(150)
                openRepair(shop.id)
            end
        end, shop.id, slot)
        return
    end

    -- Garage: a "Your Vehicles" card carries its vehicleId as `slot` (set in
    -- openGarage below), same trick the gunsmith uses for a specific weapon.
    -- A "Dealer" card has no slot, so its presence is what tells the two
    -- columns apart even though both share the same buy path.
    if shop.kind == 'garage' then
        local vehicleId = tonumber(data.slot)
        local event = vehicleId and 'vl_outpost:server:garageRetrieve' or 'vl_outpost:server:garageBuy'
        local arg = vehicleId or data.name

        lib.callback(event, false, function(result)
            cb(result or { success = false })

            -- Refresh either way: a retrieved car drops off "Your Vehicles",
            -- and a bought one is spawned immediately rather than added to
            -- the list, so there is nothing stale to leave on screen either
            -- way -- but re-fetching keeps the two columns honest.
            if result and result.success then
                closeShop()
                Wait(150)
                openGarage(shop.id)
            end
        end, shop.id, arg)
        return
    end

    -- Heli dealer: a "Your Heli" card carries a vehicleId as `slot`, same as
    -- the garage. A dealer card has no slot; `data.name` ('buy' or 'rent')
    -- says which of the two it is.
    if shop.kind == 'heli' then
        local vehicleId = tonumber(data.slot)

        if vehicleId then
            lib.callback('vl_outpost:server:heliRetrieve', false, function(result)
                cb(result or { success = false })
                if result and result.success then
                    closeShop()
                    Wait(150)
                    openHeli(shop.id)
                end
            end, shop.id, vehicleId)
            return
        end

        local event = data.name == 'rent' and 'vl_outpost:server:heliRent' or 'vl_outpost:server:heliBuy'

        lib.callback(event, false, function(result)
            cb(result or { success = false })
            if result and result.success then
                closeShop()
                Wait(150)
                openHeli(shop.id)
            end
        end, shop.id)
        return
    end

    -- One NUI, two directions: a 'shop' takes core and gives an item, an
    -- 'exchange' takes the item and gives core back. The grid looks the same
    -- either way, so the price on a broker's card is what you RECEIVE.
    local event = shop.kind == 'exchange' and 'vl_outpost:server:exchange' or 'vl_outpost:server:buy'

    lib.callback(event, false, function(result)
        cb(result or { success = false })
    end, shop.id, data.name)
end)

-- =============================================================================
-- REPAIR  (ox_lib menu -- a list of the player's own damaged weapons)
-- =============================================================================

--- The gunsmith uses the SAME grid UI as every other shop.
---
--- It is built dynamically rather than from config: the "items" are the
--- player's own damaged weapons, and each price depends on that weapon's
--- durability. `slot` rides along on each card because two of the same gun can
--- be in different condition, so the item name alone cannot identify one.
function openRepair(shopId)
    local shop = Config.Shops[shopId]

    lib.callback('vl_outpost:server:repairables', false, function(list)
        if not list or #list == 0 then
            notify('Nothing you are carrying needs repairing.', 'inform')
            return
        end

        local items = {}
        for _, w in ipairs(list) do
            items[#items + 1] = {
                -- Lowercased for the icon only: ox_inventory's weapon images are
                -- lowercase filenames. The server identifies the weapon by slot,
                -- so this never has to round-trip as a real item name.
                name = w.name:lower(),
                label = w.label,
                sub = ('%.0f%% condition'):format(w.durability),
                price = w.price,
                slot = w.slot,
                category = 'weapons',
            }
        end

        openShop({
            id = shop.id,
            kind = shop.kind,
            label = shop.label,
            coords = shop.coords,
            items = items,
            categories = { { id = 'weapons', label = 'Repairs' } },
        })
    end, shopId)
end

-- =============================================================================
-- GARAGE  (same shop grid, two categories: your vehicles, and the dealer)
-- =============================================================================

--- "Your Vehicles" cards carry the vehicleId as `slot`, exactly like the
--- gunsmith's grid carries a weapon's inventory slot -- outpost:buy tells the
--- two apart by whether that field is set at all.
function openGarage(shopId)
    local shop = Config.Shops[shopId]

    lib.callback('vl_outpost:server:garageList', false, function(result)
        if not result then
            notify('The garage is not available.', 'error')
            return
        end

        local items = {}

        for _, v in ipairs(result.vehicles or {}) do
            items[#items + 1] = {
                name = v.model:lower(), -- ox_inventory-style lowercase icon filename, same trick openRepair uses
                label = v.label,
                sub = v.plate,
                price = 0,
                slot = v.id,
                category = 'vehicles',
                outside = v.outside,
            }
        end

        for _, v in ipairs(result.dealer or {}) do
            items[#items + 1] = {
                name = v.name,
                label = v.label,
                sub = 'Dealer',
                price = v.price,
                category = 'dealer',
            }
        end

        openShop({
            id = shop.id,
            kind = shop.kind,
            label = shop.label,
            coords = shop.coords,
            items = items,
            layout = 'list',
            categories = {
                { id = 'vehicles', label = 'Your Vehicles' },
                { id = 'dealer',   label = 'Dealer' },
            },
        })
    end, shopId)
end

-- =============================================================================
-- HELI DEALER  (same shop grid again: a dealer column and an owned column)
-- =============================================================================

function openHeli(shopId)
    local shop = Config.Shops[shopId]

    lib.callback('vl_outpost:server:heliList', false, function(result)
        if not result then
            notify('The heli dealer is not available.', 'error')
            return
        end

        local items = {}

        for _, v in ipairs(result.vehicles or {}) do
            items[#items + 1] = {
                name = v.model:lower(),
                label = v.label,
                sub = v.plate,
                price = 0,
                slot = v.id,
                category = 'vehicle',
                outside = v.outside,
            }
        end

        items[#items + 1] = {
            name = 'buy',
            label = 'Buy',
            sub = 'Yours to keep -- retrievable here anytime after.',
            price = result.buyPrice,
            category = 'dealer',
        }

        items[#items + 1] = {
            name = 'rent',
            label = 'Rent',
            sub = 'Temporary -- not saved, gone once you\'re done with it.',
            price = result.rentPrice,
            category = 'dealer',
        }

        openShop({
            id = shop.id,
            kind = shop.kind,
            label = shop.label,
            coords = shop.coords,
            items = items,
            layout = 'list',
            categories = {
                { id = 'dealer',  label = 'Dealer' },
                { id = 'vehicle', label = 'Your Heli' },
            },
        })
    end, shopId)
end

-- =============================================================================
-- STASH / CLOTHING / ELEVATOR
-- =============================================================================

local function openStash(shopId)
    lib.callback('vl_outpost:server:openStash', false, function(result)
        if not result or not result.success then
            if result and result.reason == 'cant_afford' then
                notify(('A stash costs %d %s.'):format(result.price or 0, Config.CurrencyLabel), 'error')
            else
                notify('The stash is not available.', 'error')
            end
            return
        end
        exports.ox_inventory:openInventory('stash', result.stash)
    end, shopId)
end

-- Clothing-only equivalent of illenium-appearance's own GetDefaultConfig()
-- (client/defaults.lua), with only components/props switched on. That
-- function is a resource-local global, not an export, so it can't be called
-- from here -- this is its shape, copied by hand. Everything else (ped,
-- headBlend, faceFeatures, headOverlays, tattoos) stays off so the menu never
-- offers face or hair changes.
local function clothesOnlyConfig()
    return {
        ped = false,
        headBlend = false,
        faceFeatures = false,
        headOverlays = false,
        components = true,
        componentConfig = {
            masks = true, upperBody = true, lowerBody = true, bags = true,
            shoes = true, scarfAndChains = true, bodyArmor = true,
            shirts = true, decals = true, jackets = true,
        },
        props = true,
        propConfig = { hats = true, glasses = true, ear = true, watches = true, bracelets = true },
        tattoos = false,
        enableExit = true,
        hasTracker = false,
        automaticFade = false,
    }
end

local function openClothing(shopId)
    -- illenium-appearance owns the menu; this point just opens it.
    if GetResourceState('illenium-appearance') ~= 'started' then
        notify('The clothing service is offline.', 'error')
        return
    end

    local shop = Config.Shops[shopId]

    lib.callback('vl_outpost:server:openClothing', false, function(result)
        if not result or not result.success then
            if result and result.reason == 'cant_afford' then
                notify(('Changing clothes costs %d %s.'):format(result.price or shop.price or 0, Config.CurrencyLabel), 'error')
            else
                notify('The clothing service is not available.', 'error')
            end
            return
        end

        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
            if appearance then
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            end
        end, clothesOnlyConfig())
    end, shopId)
end

local function useElevator(fromId)
    local options = {}

    for _, floor in ipairs(Config.Elevator.floors) do
        if floor.id ~= fromId then
            options[#options + 1] = {
                title = floor.label,
                icon = 'elevator',
                onSelect = function()
                    local fade = Config.Elevator.fadeMs or 500
                    DoScreenFadeOut(fade)
                    while not IsScreenFadedOut() do Wait(0) end

                    local ped = cache.ped
                    SetEntityCoords(ped, floor.coords.x, floor.coords.y, floor.coords.z - 0.9, false, false, false, false)
                    SetEntityHeading(ped, floor.coords.w)

                    -- Wait for the destination to stream in before fading back,
                    -- or the player lands in an empty world and falls.
                    local deadline = GetGameTimer() + 5000
                    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
                        Wait(50)
                    end

                    DoScreenFadeIn(fade)
                end,
            }
        end
    end

    lib.registerContext({ id = 'vl_outpost_elevator', title = Config.Elevator.label, options = options })
    lib.showContext('vl_outpost_elevator')
end

-- =============================================================================
-- WORLD
-- =============================================================================

local function spawnPed(shop)
    local model = joaat(shop.ped)
    if not IsModelValid(model) then
        print(('[vl_outpost] %s: ped model "%s" is not valid'):format(shop.id, tostring(shop.ped)))
        return nil
    end

    lib.requestModel(model)

    local z = shop.coords.z - (Config.PedZOffset or 1.0)
    local ped = CreatePed(4, model, shop.coords.x, shop.coords.y, z, shop.coords.w, false, true)

    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)

    if shop.scenario and shop.scenario ~= '' then
        TaskStartScenarioInPlace(ped, shop.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    return ped
end

---What interacting with this shop does.
local function actionFor(shop)
    if shop.kind == 'suit' then
        -- Suits are free: the original vl_suitshop charged nothing.
        return function() openShop(shop) end
    end
    if shop.kind == 'repair' then return function() openRepair(shop.id) end end
    if shop.kind == 'garage' then return function() openGarage(shop.id) end end
    if shop.kind == 'heli' then return function() openHeli(shop.id) end end
    if shop.kind == 'stash' then return function() openStash(shop.id) end end
    if shop.kind == 'clothing' then return function() openClothing(shop.id) end end
    return function() openShop(shop) end
end

local function build()
    for _, shop in pairs(Config.Shops) do
        local action = actionFor(shop)

        local option = {
            name = 'vl_outpost_' .. shop.id,
            icon = shop.icon or 'fa-solid fa-store',
            label = shop.label,
            distance = Config.InteractDistance,
            onSelect = action,
        }

        if shop.ped then
            local ped = spawnPed(shop)
            if ped then
                peds[#peds + 1] = ped
                exports.ox_target:addLocalEntity(ped, { option })
            end
        else
            -- No ped: a marker on the ground instead of a target zone. These
            -- are PLACES, not people -- see Config.Marker.
            markers[#markers + 1] = {
                coords = shop.coords.xyz,
                label = shop.label,
                action = action,
            }
        end
    end

    if Config.Elevator.enabled then
        for _, floor in ipairs(Config.Elevator.floors) do
            markers[#markers + 1] = {
                coords = floor.coords.xyz,
                label = ('%s (%s)'):format(Config.Elevator.label, floor.label),
                action = function() useElevator(floor.id) end,
            }
        end
    end
end

-- =============================================================================
-- GARAGE PARKING
-- =============================================================================
-- A red disc on the ground next to the garage NPC. Drive onto it and press
-- the prompt to store whatever you're driving back into this garage -- any
-- vehicle you own, not just ones bought/retrieved through this NPC.
--
-- Not hardcoded to one spot: runs for every garage shop that sets a
-- parkPoint, same "loop over matching shops" approach as the ped/marker
-- spawner above.

local function garageParkShops()
    local shops = {}
    for _, shop in pairs(Config.Shops) do
        if shop.kind == 'garage' and shop.parkPoint then
            shops[#shops + 1] = shop
        end
    end
    return shops
end

CreateThread(function()
    local shops = garageParkShops()
    if #shops == 0 then return end

    while true do
        local sleep = 500
        local ped = cache.ped
        local me = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        local isDriver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

        for _, shop in ipairs(shops) do
            local point = shop.parkPoint
            local radius = shop.parkRadius or 4.0

            -- The disc itself is visible on foot too, from a bit further out,
            -- so it reads as a landmark before you're already sitting on it.
            if #(me - point.xyz) <= radius + 20.0 then
                sleep = 0

                -- A tall marker (even a "short" 1.0 one) reads as a glowing
                -- wall rather than a ground decal, because the cylinder fades
                -- top-to-bottom over its whole height. Flattened almost to
                -- nothing so it hugs the ground like a paint ring instead.
                DrawMarker(
                    1,
                    point.x, point.y, point.z - (Config.PedZOffset or 1.0),
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    radius * 2.0, radius * 2.0, 0.1,
                    255, 0, 0, 150,
                    false, false, 2, false, nil, nil, false
                )

                if isDriver and #(GetEntityCoords(veh) - point.xyz) <= radius then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to store the vehicle')
                    EndTextCommandDisplayHelp(0, false, true, -1)

                    if IsControlJustReleased(0, 38) then -- INPUT_CONTEXT (E)
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        local props = lib.getVehicleProperties(veh)

                        lib.callback('vl_outpost:server:garagePark', false, function(result)
                            if result and result.success then
                                notify('Vehicle stored.', 'success')
                            else
                                notify('That vehicle cannot be stored here.', 'error')
                            end
                        end, shop.id, netId, props)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- =============================================================================
-- MARKER LOOP
-- =============================================================================
-- One thread for every marker rather than one each: DrawMarker has to run every
-- frame to persist, and a thread per point would mean several full-rate loops
-- for what is a single distance test.
--
-- It sleeps at 500 ms whenever nothing is in range, so standing anywhere else
-- in the world costs one cheap check twice a second.
CreateThread(function()
    local cfg = Config.Marker

    while true do
        local sleep = 500
        local me = GetEntityCoords(cache.ped)
        local closest, closestDist = nil, math.huge

        for _, m in ipairs(markers) do
            local d = #(me - m.coords)

            if d <= cfg.drawDistance then
                sleep = 0

                DrawMarker(
                    cfg.type,
                    m.coords.x, m.coords.y, m.coords.z + cfg.zOffset,
                    0.0, 0.0, 0.0,      -- direction
                    0.0, 0.0, 0.0,      -- rotation
                    cfg.size.x, cfg.size.y, cfg.size.z,
                    cfg.colour.r, cfg.colour.g, cfg.colour.b, cfg.colour.a,
                    cfg.bobUpAndDown, false, 2, cfg.rotate,
                    nil, nil, false
                )

                if d < closestDist then closest, closestDist = m, d end
            end
        end

        -- Only the nearest marker offers its prompt, so two points close
        -- together cannot both claim the key.
        if closest and closestDist <= cfg.interactDistance then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(('Press ~%s~ for %s'):format(cfg.keyLabel, closest.label))
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustReleased(0, cfg.key) then
                closest.action()
            end
        end

        Wait(sleep)
    end
end)

CreateThread(build)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
