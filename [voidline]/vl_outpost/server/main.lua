-- =============================================================================
-- vl_outpost -- server
-- =============================================================================
-- Reconstructed 2026-09-08 after the resource folder was accidentally
-- deleted. client/*, ui/*, fxmanifest.lua and shared/* were recovered
-- byte-for-byte from FXServer's own resource content cache
-- (txData/.../cache/files/vl_outpost/resource.rpf), which only ever holds
-- files streamed to clients. This file wasn't in that cache -- server
-- scripts never are -- so it's rebuilt here from what the recovered client
-- code and shared/config.lua require it to do. Logic, not bytes: match the
-- callback names/payloads exactly, but treat the internals as new code.

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function removeCurrency(source, amount)
    return exports.ox_inventory:RemoveItem(source, Config.Currency, amount)
end

local function addCurrency(source, amount)
    return exports.ox_inventory:AddItem(source, Config.Currency, amount)
end

local function countCurrency(source)
    return exports.ox_inventory:Search(source, 'count', Config.Currency) or 0
end

-- =============================================================================
-- SHOP / EXCHANGE
-- =============================================================================

lib.callback.register('vl_outpost:server:buy', function(source, shopId, itemName)
    local shop = Config.Shops[shopId]
    -- Suits use this same buy path (see the AddItem below): only their kind
    -- differs from a normal shop, so both are accepted here.
    if not shop or (shop.kind ~= 'shop' and shop.kind ~= 'suit') then return { success = false } end

    local item = shop.itemsByName[itemName]
    if not item then return { success = false } end

    if countCurrency(source) < item.price then
        return { success = false, reason = 'cant_afford' }
    end

    -- ox_inventory:RemoveItem rejects a count of 0 outright ('negative_count'),
    -- so a free item (the suits, price = 0) must skip the charge entirely
    -- rather than "removing" nothing and reading that as a failed payment.
    if item.price > 0 and not removeCurrency(source, item.price) then
        return { success = false, reason = 'cant_afford' }
    end

    -- Suits carry their own model rather than a stack of an ox_inventory
    -- item -- client/suits.lua's useItem export does the model swap, this
    -- just needs the item to exist in the player's inventory to use later.
    local added = exports.ox_inventory:AddItem(source, item.model or item.name, 1)

    if not added then
        addCurrency(source, item.price) -- refund: item couldn't fit
        return { success = false, reason = 'no_space' }
    end

    return { success = true }
end)

lib.callback.register('vl_outpost:server:exchange', function(source, shopId, itemName)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'exchange' then return { success = false } end

    local item = shop.itemsByName[itemName]
    if not item then return { success = false } end

    if not exports.ox_inventory:RemoveItem(source, itemName, 1) then
        return { success = false, reason = 'missing_item' }
    end

    addCurrency(source, item.price)
    return { success = true }
end)

-- =============================================================================
-- REPAIR
-- =============================================================================

--- Price scales linearly from minPrice (full durability) to maxPrice (zero
--- durability); a weapon above `freeAbove`% durability is refused outright.
local function repairPrice(shop, durability)
    if durability >= shop.freeAbove then return nil end
    local brokenFraction = (100 - durability) / 100
    return math.floor(shop.minPrice + (shop.maxPrice - shop.minPrice) * brokenFraction)
end

lib.callback.register('vl_outpost:server:repairables', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'repair' then return {} end

    local weapons = exports.ox_inventory:GetInventoryItems(source)
    local list = {}

    for _, slot in pairs(weapons or {}) do
        if slot.metadata and slot.metadata.durability and slot.metadata.durability < 100 then
            local itemData = exports.ox_inventory:Items(slot.name)
            if itemData and itemData.weapon then
                local price = repairPrice(shop, slot.metadata.durability)
                if price then
                    list[#list + 1] = {
                        name = slot.name,
                        label = slot.metadata.label or (itemData.label or slot.name),
                        durability = slot.metadata.durability,
                        price = price,
                        slot = slot.slot,
                    }
                end
            end
        end
    end

    return list
end)

lib.callback.register('vl_outpost:server:repair', function(source, shopId, slot)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'repair' then return { success = false } end

    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or not item.metadata or not item.metadata.durability then
        return { success = false }
    end

    local price = repairPrice(shop, item.metadata.durability)
    if not price then return { success = false, reason = 'not_damaged' } end

    if countCurrency(source) < price then
        return { success = false, reason = 'cant_afford' }
    end

    if not removeCurrency(source, price) then
        return { success = false, reason = 'cant_afford' }
    end

    exports.ox_inventory:SetMetadata(source, slot, { durability = 100 })
    return { success = true }
end)

-- =============================================================================
-- GARAGE
-- =============================================================================
-- Deliberately not a qbx_garages garage: this NPC talks to qbx_vehicles
-- directly. "Your Vehicles" lists everything the player owns that is not
-- currently spawned anywhere on the map; "Dealer" buys a fresh one and drops
-- it straight onto a free retrieve spot.

local VEHICLES = exports.qbx_core:GetVehiclesByName()

--- True if a vehicle with this plate already exists somewhere in the world.
--- Same check qbx_garages does before letting a garaged car out twice.
local function isPlateSpawned(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if GetVehicleNumberPlateText(vehicles[i]) == plate then
            return true
        end
    end
    return false
end

--- True if some player is currently sitting in a vehicle within `radius` of
--- `point`. An empty parked car left at a spot does not itself count -- only
--- someone actually using that spot does.
local function isSpotOccupied(point, radius)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 then
            local vCoords = GetEntityCoords(veh)
            if #(vCoords - point.xyz) <= radius then
                return true
            end
        end
    end

    return false
end

--- The first retrieve point that isn't occupied (see isSpotOccupied).
local function findFreeSpot(shop)
    for _, point in ipairs(shop.retrievePoints) do
        if not isSpotOccupied(point, shop.spotRadius or 3.0) then
            return point
        end
    end

    return nil
end

lib.callback.register('vl_outpost:server:garageList', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'garage' then return end

    local player = getPlayer(source)
    if not player then return end

    local owned = exports.qbx_vehicles:GetPlayerVehicles({ citizenid = player.PlayerData.citizenid }) or {}
    local vehicles = {}

    -- Every owned vehicle is listed, not just the ones sitting in storage:
    -- one already spawned somewhere shows as "Outside" instead of just
    -- vanishing from the list, so the player can see it's theirs without
    -- being able to double-retrieve it.
    for _, v in ipairs(owned) do
        local def = VEHICLES[v.modelName]
        vehicles[#vehicles + 1] = {
            id = v.id,
            model = v.modelName,
            label = def and def.name or v.modelName,
            plate = v.props.plate,
            outside = isPlateSpawned(v.props.plate),
        }
    end

    return { vehicles = vehicles, dealer = shop.dealer }
end)

lib.callback.register('vl_outpost:server:garageRetrieve', function(source, shopId, vehicleId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'garage' then return { success = false } end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return { success = false } end

    local player = getPlayer(source)
    if not player then return { success = false } end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
    if not playerVehicle then
        return { success = false, reason = 'not_owned' }
    end

    if isPlateSpawned(playerVehicle.props.plate) then
        return { success = false, reason = 'already_out' }
    end

    local spot = findFreeSpot(shop)
    if not spot then
        return { success = false, reason = 'spots_full' }
    end

    local netId, veh = qbx.spawnVehicle({
        spawnSource = spot,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = GetPlayerPed(source),
    })

    Entity(veh).state:set('vehicleid', vehicleId, false)
    exports.qbx_vehicles:SaveVehicle(veh, { garage = shop.garageName, state = 0 }) -- 0 = OUT

    return { success = true }
end)

lib.callback.register('vl_outpost:server:garagePark', function(source, shopId, netId, props)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'garage' or not shop.parkPoint then return { success = false } end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then return { success = false } end

    -- Distance re-checked server-side: the client only offers the prompt
    -- near the disc, but the request itself has to be trusted no further
    -- than that.
    local vCoords = GetEntityCoords(vehicle)
    if #(vCoords - shop.parkPoint.xyz) > (shop.parkRadius or 4.0) + 2.0 then
        return { success = false }
    end

    local player = getPlayer(source)
    if not player then return { success = false } end

    local plate = GetVehicleNumberPlateText(vehicle)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(plate)
    if not vehicleId then return { success = false } end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
    if not playerVehicle then
        return { success = false, reason = 'not_owned' }
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        garage = shop.garageName,
        state = 1, -- GARAGED
        props = props,
    })

    exports.qbx_core:DeleteVehicle(vehicle)

    return { success = true }
end)

lib.callback.register('vl_outpost:server:garageBuy', function(source, shopId, vehicleName)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'garage' then return { success = false } end

    local dealerItem
    for _, v in ipairs(shop.dealer or {}) do
        if v.name == vehicleName then dealerItem = v break end
    end
    if not dealerItem then return { success = false } end

    if countCurrency(source) < dealerItem.price then
        return { success = false, reason = 'cant_afford' }
    end

    -- Checked before taking payment: no point charging for a car with
    -- nowhere to put it.
    local spot = findFreeSpot(shop)
    if not spot then
        return { success = false, reason = 'spots_full' }
    end

    if not removeCurrency(source, dealerItem.price) then
        return { success = false, reason = 'cant_afford' }
    end

    local player = getPlayer(source)
    local vehicleId = exports.qbx_vehicles:CreatePlayerVehicle({
        model = dealerItem.name,
        citizenid = player.PlayerData.citizenid,
        garage = shop.garageName,
    })

    if not vehicleId then
        addCurrency(source, dealerItem.price) -- refund: purchase didn't go through
        return { success = false, reason = 'purchase_failed' }
    end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)

    local netId, veh = qbx.spawnVehicle({
        spawnSource = spot,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = GetPlayerPed(source),
    })

    Entity(veh).state:set('vehicleid', vehicleId, false)
    exports.qbx_vehicles:SaveVehicle(veh, { garage = shop.garageName, state = 0 }) -- 0 = OUT

    return { success = true }
end)

-- =============================================================================
-- HELI DEALER
-- =============================================================================
-- Buy a rustheli: exactly the garage dealer flow above, minus the model
-- picker (there's only one), so it's owned and retrievable later. Rent one:
-- cheaper, but NEVER goes through qbx_vehicles at all -- nothing is saved,
-- so once it's gone (destroyed, abandoned, server restart) renting again is
-- the only way back into one.

lib.callback.register('vl_outpost:server:heliList', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'heli' then return end

    local player = getPlayer(source)
    if not player then return end

    local owned = exports.qbx_vehicles:GetPlayerVehicles({ citizenid = player.PlayerData.citizenid }) or {}
    local vehicles = {}

    for _, v in ipairs(owned) do
        if v.modelName == shop.model then
            vehicles[#vehicles + 1] = {
                id = v.id,
                model = v.modelName,
                label = (VEHICLES[v.modelName] and VEHICLES[v.modelName].name) or v.modelName,
                plate = v.props.plate,
                outside = isPlateSpawned(v.props.plate),
            }
        end
    end

    return { vehicles = vehicles, buyPrice = shop.buyPrice, rentPrice = shop.rentPrice }
end)

lib.callback.register('vl_outpost:server:heliRetrieve', function(source, shopId, vehicleId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'heli' then return { success = false } end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return { success = false } end

    local player = getPlayer(source)
    if not player then return { success = false } end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = player.PlayerData.citizenid })
    if not playerVehicle or playerVehicle.modelName ~= shop.model then
        return { success = false, reason = 'not_owned' }
    end

    if isPlateSpawned(playerVehicle.props.plate) then
        return { success = false, reason = 'already_out' }
    end

    if isSpotOccupied(shop.spawnPoint, shop.spawnRadius or 4.0) then
        return { success = false, reason = 'spots_full' }
    end

    local netId, veh = qbx.spawnVehicle({
        spawnSource = shop.spawnPoint,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = GetPlayerPed(source),
    })

    Entity(veh).state:set('vehicleid', vehicleId, false)
    exports.qbx_vehicles:SaveVehicle(veh, { garage = shop.garageName, state = 0 }) -- 0 = OUT

    return { success = true }
end)

lib.callback.register('vl_outpost:server:heliBuy', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'heli' then return { success = false } end

    if countCurrency(source) < shop.buyPrice then
        return { success = false, reason = 'cant_afford' }
    end

    if isSpotOccupied(shop.spawnPoint, shop.spawnRadius or 4.0) then
        return { success = false, reason = 'spots_full' }
    end

    if not removeCurrency(source, shop.buyPrice) then
        return { success = false, reason = 'cant_afford' }
    end

    local player = getPlayer(source)
    local vehicleId = exports.qbx_vehicles:CreatePlayerVehicle({
        model = shop.model,
        citizenid = player.PlayerData.citizenid,
        garage = shop.garageName,
    })

    if not vehicleId then
        addCurrency(source, shop.buyPrice) -- refund: purchase didn't go through
        return { success = false, reason = 'purchase_failed' }
    end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)

    local netId, veh = qbx.spawnVehicle({
        spawnSource = shop.spawnPoint,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = GetPlayerPed(source),
    })

    Entity(veh).state:set('vehicleid', vehicleId, false)
    exports.qbx_vehicles:SaveVehicle(veh, { garage = shop.garageName, state = 0 }) -- 0 = OUT

    return { success = true }
end)

lib.callback.register('vl_outpost:server:heliRent', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'heli' then return { success = false } end

    if countCurrency(source) < shop.rentPrice then
        return { success = false, reason = 'cant_afford' }
    end

    if isSpotOccupied(shop.spawnPoint, shop.spawnRadius or 4.0) then
        return { success = false, reason = 'spots_full' }
    end

    if not removeCurrency(source, shop.rentPrice) then
        return { success = false, reason = 'cant_afford' }
    end

    -- No qbx_vehicles row at all: this vehicle is never owned, so there is
    -- nothing to retrieve later. A fresh plate keeps it from colliding with
    -- anyone's actual owned rustheli.
    qbx.spawnVehicle({
        spawnSource = shop.spawnPoint,
        model = shop.model,
        props = { model = joaat(shop.model), plate = qbx.generateRandomPlate() },
        warp = GetPlayerPed(source),
    })

    return { success = true }
end)

-- =============================================================================
-- STASH
-- =============================================================================
-- Deliberately shopId-agnostic: stash/stash_2/stash_3/stash_4 all open the
-- SAME account for a given player, keyed by their identifier rather than
-- whichever door they walked through. The one-off price is remembered on
-- the player's own metadata so it survives relogs without needing a table
-- of its own.

lib.callback.register('vl_outpost:server:openStash', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'stash' then return { success = false } end

    local player = getPlayer(source)
    if not player then return { success = false } end

    local citizenid = player.PlayerData.citizenid
    local paid = player.PlayerData.metadata.outpost_stash_paid

    if not paid then
        local price = shop.price or 0
        if price > 0 then
            if countCurrency(source) < price then
                return { success = false, reason = 'cant_afford', price = price }
            end
            if not removeCurrency(source, price) then
                return { success = false, reason = 'cant_afford', price = price }
            end
        end
        player.Functions.SetMetaData('outpost_stash_paid', true)
    end

    local stashId = ('outpost_stash_%s'):format(citizenid)

    exports.ox_inventory:RegisterStash(stashId, 'Outpost Stash', shop.slots, shop.weight)

    return { success = true, stash = stashId }
end)

-- =============================================================================
-- CLOTHING
-- =============================================================================
-- Charged every time the menu opens (unlike the stash's one-off price).

lib.callback.register('vl_outpost:server:openClothing', function(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or shop.kind ~= 'clothing' then return { success = false } end

    local price = shop.price or 0
    if price > 0 then
        if countCurrency(source) < price then
            return { success = false, reason = 'cant_afford' }
        end
        if not removeCurrency(source, price) then
            return { success = false, reason = 'cant_afford' }
        end
    end

    return { success = true }
end)
