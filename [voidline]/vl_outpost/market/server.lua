-- =============================================================================
-- vl_outpost -- marketplace server
-- =============================================================================
-- Rebuilt 2026-09-08 after the resource folder was accidentally deleted.
-- FRESH CODE, not a recovered original: this file and sql/marketplace.sql
-- never touch the game client, so neither FXServer's resource cache nor any
-- prior conversation had a copy to restore from. Every event name and NUI
-- payload shape below is matched exactly against the recovered
-- market/client.lua and ui/market.js so the front end needs zero changes --
-- the *internal* logic (escrow, fees, pickups) is new, not restored.
--
-- Currency is Config.Currency (the 'core' item, see shared/config.lua), same
-- as the rest of vl_outpost -- NOT money.cash.

local CURRENCY = Config.Currency

-- Applies sql/marketplace.sql on start so a fresh server (or one restoring
-- this resource after deletion, like this one) doesn't need a manual import.
-- CREATE TABLE IF NOT EXISTS everywhere in that file makes this idempotent.
CreateThread(function()
    local path = GetResourcePath(GetCurrentResourceName()) .. '/sql/marketplace.sql'
    local file = io.open(path, 'r')
    if not file then return end
    local sql = file:read('*a')
    file:close()

    for statement in sql:gmatch('[^;]+') do
        if statement:match('%S') then
            MySQL.query.await(statement)
        end
    end
end)

-- =============================================================================
-- HELPERS
-- =============================================================================

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getPlayerByCitizenId(citizenid)
    return exports.qbx_core:GetPlayerByCitizenId(citizenid)
end

local function playerName(player)
    local info = player.PlayerData.charinfo
    if info and info.firstname then
        return ('%s %s'):format(info.firstname, info.lastname or '')
    end
    return player.PlayerData.name or 'Unknown'
end

local function notify(source, kind, message)
    TriggerClientEvent('bs_market:notification', source, kind, message)
end

local function now()
    return os.time()
end

local function addHistory(entry)
    entry.timestamp = now()
    MySQL.insert.await('INSERT INTO vl_outpost_history (type, item, quantity, price, totalPrice, sellerName, buyerName, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        entry.type, entry.item, entry.quantity or 0, entry.price or 0, entry.totalPrice or 0,
        entry.sellerName, entry.buyerName, entry.timestamp,
    })
end

--- Whether an item name is sellable/orderable at all. Empty whitelist means
--- everything is (see shared config comment on Config.AvailableItems).
local function isAvailable(item)
    if not Config.AvailableItems or #Config.AvailableItems == 0 then return true end
    for _, name in ipairs(Config.AvailableItems) do
        if name == item then return true end
    end
    return false
end

local function clampPrice(price)
    local settings = Config.Settings
    if price < settings.minPrice then return settings.minPrice end
    if price > settings.maxPrice then return settings.maxPrice end
    return price
end

-- =============================================================================
-- QUERIES  (re-fetched fresh on every open/refresh -- no server-side cache,
-- so two players never see a stale copy of each other's listings)
-- =============================================================================

--- Resolves each row's owner citizenid to THEIR CURRENT server id, because
--- ui/market.js decides "is this mine" with `row.seller === GetPlayerServerId()`
--- -- a citizenid would never match that comparison. Offline owners resolve to
--- -1, which no real server id equals, so their own row just looks like
--- everyone else's to other players (and to themselves, until they reconnect).
local function resolveSource(citizenid)
    local player = getPlayerByCitizenId(citizenid)
    return player and player.PlayerData.source or -1
end

local function getListings()
    local rows = MySQL.query.await('SELECT * FROM vl_outpost_listings ORDER BY id DESC') or {}
    for _, row in ipairs(rows) do
        row.seller = resolveSource(row.seller)
        if row.metadata and row.metadata ~= '' then
            row.metadata = json.decode(row.metadata)
        else
            row.metadata = {}
        end
    end
    return rows
end

local function getBuyOrders()
    local rows = MySQL.query.await('SELECT * FROM vl_outpost_buy_orders ORDER BY id DESC') or {}
    for _, row in ipairs(rows) do
        row.buyer = resolveSource(row.buyer)
    end
    return rows
end

local function getPickups(citizenid)
    return MySQL.query.await('SELECT * FROM vl_outpost_pickups WHERE owner = ? ORDER BY id DESC', { citizenid }) or {}
end

local function getHistory()
    -- Client re-filters `currentHistory` locally (see ui/market.js
    -- applyHistoryFilters) -- this just caps how much ever goes over the
    -- wire so the table doesn't grow unbounded.
    return MySQL.query.await('SELECT * FROM vl_outpost_history ORDER BY id DESC LIMIT 300') or {}
end

local function getInventoryItemsFor(source)
    local slots = exports.ox_inventory:GetInventoryItems(source) or {}
    local list = {}
    for _, slot in pairs(slots) do
        if slot.name ~= CURRENCY and isAvailable(slot.name) then
            list[#list + 1] = { name = slot.name, label = slot.label, count = slot.count, metadata = slot.metadata }
        end
    end
    return list
end

local function getAllAvailableItems()
    local items = exports.ox_inventory:Items() or {}
    local list = {}
    for name, def in pairs(items) do
        if name ~= CURRENCY and isAvailable(name) then
            list[#list + 1] = { name = name, label = def.label or name }
        end
    end
    return list
end

--- Pushes each open-market player their own view (seller/buyer resolved
--- against THEM being online right now doesn't matter -- resolveSource looks
--- up the row owner, not the recipient -- but pickups are per-owner so those
--- still need a per-player query).
local openMarketPlayers = {}

local function broadcastRefresh()
    local listings, buyOrders = getListings(), getBuyOrders()
    for source in pairs(openMarketPlayers) do
        local player = getPlayer(source)
        local pickups = player and getPickups(player.PlayerData.citizenid) or {}
        TriggerClientEvent('bs_market:refreshData', source, listings, buyOrders, pickups)
    end
end

-- =============================================================================
-- OPEN / CLOSE
-- =============================================================================

RegisterNetEvent('bs_market:openMarket', function()
    local source = source
    local player = getPlayer(source)
    if not player then return end

    openMarketPlayers[source] = true

    TriggerClientEvent('bs_market:openUI', source,
        getListings(),
        getBuyOrders(),
        getInventoryItemsFor(source),
        getAllAvailableItems(),
        Config.AvailableItems,
        getPickups(player.PlayerData.citizenid)
    )
end)

AddEventHandler('playerDropped', function()
    openMarketPlayers[source] = nil
end)

-- =============================================================================
-- LISTINGS  (sell for core, or barter for another item)
-- =============================================================================

RegisterNetEvent('bs_market:listItem', function(item, quantity, price, metadata, tradeItem, tradeQuantity)
    local source = source
    local player = getPlayer(source)
    if not player then return end

    quantity = tonumber(quantity)
    if not quantity or quantity < 1 or not isAvailable(item) then
        return notify(source, 'error', 'That item cannot be listed.')
    end

    local citizenid = player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM vl_outpost_listings WHERE seller = ?', { citizenid }) or 0
    if count >= Config.Settings.maxListingsPerPlayer then
        return notify(source, 'error', ('You can only have %d active listings.'):format(Config.Settings.maxListingsPerPlayer))
    end

    if tradeItem then
        tradeQuantity = tonumber(tradeQuantity)
        if not tradeQuantity or tradeQuantity < 1 or not isAvailable(tradeItem) then
            return notify(source, 'error', 'Invalid trade item.')
        end
        price = 0
    else
        price = clampPrice(tonumber(price) or 0)
    end

    -- Escrow: the item leaves the seller's inventory the moment it's listed,
    -- not when it sells -- otherwise they could list something, drop/use it,
    -- and still have it "for sale".
    local removed = exports.ox_inventory:RemoveItem(source, item, quantity, metadata)
    if not removed then
        return notify(source, 'error', "You don't have that many.")
    end

    MySQL.insert.await(
        'INSERT INTO vl_outpost_listings (seller, sellerName, item, quantity, price, metadata, tradeItem, tradeQuantity, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { citizenid, playerName(player), item, quantity, price, metadata and json.encode(metadata) or nil, tradeItem, tradeQuantity, now() }
    )

    addHistory({ type = 'listing', item = item, quantity = quantity, price = price, sellerName = playerName(player) })
    notify(source, 'success', 'Listing created.')
    broadcastRefresh()
end)

RegisterNetEvent('bs_market:cancelListing', function(listingId)
    local source = source
    local player = getPlayer(source)
    if not player then return end

    local listing = MySQL.single.await('SELECT * FROM vl_outpost_listings WHERE id = ?', { listingId })
    if not listing or listing.seller ~= player.PlayerData.citizenid then
        return notify(source, 'error', 'That listing is not yours.')
    end

    local metadata = listing.metadata and listing.metadata ~= '' and json.decode(listing.metadata) or nil
    exports.ox_inventory:AddItem(source, listing.item, listing.quantity, metadata)

    MySQL.query.await('DELETE FROM vl_outpost_listings WHERE id = ?', { listingId })
    addHistory({ type = 'listingCancel', item = listing.item, quantity = listing.quantity, sellerName = playerName(player) })
    notify(source, 'success', 'Listing cancelled and returned to your inventory.')
    broadcastRefresh()
end)

RegisterNetEvent('bs_market:purchaseItem', function(listingId, quantity)
    local source = source
    local buyer = getPlayer(source)
    if not buyer then return end

    local listing = MySQL.single.await('SELECT * FROM vl_outpost_listings WHERE id = ?', { listingId })
    if not listing then return notify(source, 'error', 'That listing no longer exists.') end
    if listing.seller == buyer.PlayerData.citizenid then
        return notify(source, 'error', "You can't buy your own listing.")
    end

    quantity = math.min(tonumber(quantity) or 1, listing.quantity)
    if quantity < 1 then return end

    local metadata = listing.metadata and listing.metadata ~= '' and json.decode(listing.metadata) or nil
    local seller = getPlayerByCitizenId(listing.seller)

    if listing.tradeItem then
        local tradeQty = listing.tradeQuantity * quantity
        if not exports.ox_inventory:RemoveItem(source, listing.tradeItem, tradeQty) then
            return notify(source, 'error', "You don't have the item this trade wants.")
        end
        if not exports.ox_inventory:AddItem(source, listing.item, quantity, metadata) then
            exports.ox_inventory:AddItem(source, listing.tradeItem, tradeQty) -- refund
            return notify(source, 'error', 'Not enough inventory space.')
        end

        if seller and exports.ox_inventory:AddItem(seller.PlayerData.source, listing.tradeItem, tradeQty) then
            -- delivered directly
        else
            MySQL.insert.await(
                'INSERT INTO vl_outpost_pickups (owner, sellerName, item, quantity, metadata, price, totalPrice, fulfilledTimestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                { listing.seller, playerName(buyer), listing.tradeItem, tradeQty, nil, 0, 0, now() }
            )
        end
    else
        local totalPrice = listing.price * quantity
        if not exports.ox_inventory:RemoveItem(source, CURRENCY, totalPrice) then
            return notify(source, 'error', ("You need %d %s."):format(totalPrice, Config.CurrencyLabel))
        end
        if not exports.ox_inventory:AddItem(source, listing.item, quantity, metadata) then
            exports.ox_inventory:AddItem(source, CURRENCY, totalPrice) -- refund
            return notify(source, 'error', 'Not enough inventory space.')
        end

        local fee = math.floor(totalPrice * ((Config.Settings.transactionFeePercent or 0) / 100))
        local payout = totalPrice - fee

        if seller and exports.ox_inventory:AddItem(seller.PlayerData.source, CURRENCY, payout) then
            -- paid directly
        else
            MySQL.insert.await(
                'INSERT INTO vl_outpost_pickups (owner, sellerName, item, quantity, price, totalPrice, fulfilledTimestamp) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { listing.seller, playerName(buyer), CURRENCY, 1, listing.price, payout, now() }
            )
        end
    end

    if quantity >= listing.quantity then
        MySQL.query.await('DELETE FROM vl_outpost_listings WHERE id = ?', { listingId })
    else
        MySQL.query.await('UPDATE vl_outpost_listings SET quantity = quantity - ? WHERE id = ?', { quantity, listingId })
    end

    addHistory({
        type = 'purchase', item = listing.item, quantity = quantity,
        price = listing.price, totalPrice = listing.price * quantity,
        sellerName = listing.sellerName, buyerName = playerName(buyer),
    })

    notify(source, 'success', 'Purchase complete.')
    if seller then notify(seller.PlayerData.source, 'inform', ('Your listing for %s sold.'):format(listing.item)) end
    broadcastRefresh()
end)

-- =============================================================================
-- BUY ORDERS
-- =============================================================================

RegisterNetEvent('bs_market:createBuyOrder', function(item, quantity, price, tradeItem, tradeQuantity)
    local source = source
    local player = getPlayer(source)
    if not player then return end

    quantity = tonumber(quantity)
    if not quantity or quantity < 1 or not isAvailable(item) then
        return notify(source, 'error', 'That item cannot be ordered.')
    end

    local citizenid = player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM vl_outpost_buy_orders WHERE buyer = ?', { citizenid }) or 0
    if count >= Config.Settings.maxBuyOrdersPerPlayer then
        return notify(source, 'error', ('You can only have %d active buy orders.'):format(Config.Settings.maxBuyOrdersPerPlayer))
    end

    -- Escrow the offer up front, same reasoning as listings: a buy order
    -- must be a guaranteed payout for whoever fulfils it.
    if tradeItem then
        tradeQuantity = tonumber(tradeQuantity)
        if not tradeQuantity or tradeQuantity < 1 or not isAvailable(tradeItem) then
            return notify(source, 'error', 'Invalid trade item.')
        end
        if not exports.ox_inventory:RemoveItem(source, tradeItem, tradeQuantity) then
            return notify(source, 'error', "You don't have that many.")
        end
        price = 0
    else
        price = clampPrice(tonumber(price) or 0)
        if not exports.ox_inventory:RemoveItem(source, CURRENCY, price * quantity) then
            return notify(source, 'error', ("You need %d %s."):format(price * quantity, Config.CurrencyLabel))
        end
    end

    MySQL.insert.await(
        'INSERT INTO vl_outpost_buy_orders (buyer, buyerName, item, quantity, price, tradeItem, tradeQuantity, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { citizenid, playerName(player), item, quantity, price, tradeItem, tradeQuantity, now() }
    )

    addHistory({ type = 'buyOrder', item = item, quantity = quantity, price = price, buyerName = playerName(player) })
    notify(source, 'success', 'Buy order created.')
    broadcastRefresh()
end)

RegisterNetEvent('bs_market:cancelBuyOrder', function(orderId)
    local source = source
    local player = getPlayer(source)
    if not player then return end

    local order = MySQL.single.await('SELECT * FROM vl_outpost_buy_orders WHERE id = ?', { orderId })
    if not order or order.buyer ~= player.PlayerData.citizenid then
        return notify(source, 'error', 'That order is not yours.')
    end

    if order.tradeItem then
        exports.ox_inventory:AddItem(source, order.tradeItem, order.tradeQuantity)
    else
        exports.ox_inventory:AddItem(source, CURRENCY, order.price * order.quantity)
    end

    MySQL.query.await('DELETE FROM vl_outpost_buy_orders WHERE id = ?', { orderId })
    addHistory({ type = 'buyOrderCancel', item = order.item, quantity = order.quantity, buyerName = playerName(player) })
    notify(source, 'success', 'Buy order cancelled and refunded.')
    broadcastRefresh()
end)

RegisterNetEvent('bs_market:fulfillBuyOrder', function(orderId, quantity)
    local source = source
    local fulfiller = getPlayer(source)
    if not fulfiller then return end

    local order = MySQL.single.await('SELECT * FROM vl_outpost_buy_orders WHERE id = ?', { orderId })
    if not order then return notify(source, 'error', 'That order no longer exists.') end
    if order.buyer == fulfiller.PlayerData.citizenid then
        return notify(source, 'error', "You can't fulfil your own order.")
    end

    quantity = math.min(tonumber(quantity) or 1, order.quantity)
    if quantity < 1 then return end

    if not exports.ox_inventory:RemoveItem(source, order.item, quantity) then
        return notify(source, 'error', "You don't have that many.")
    end

    local buyer = getPlayerByCitizenId(order.buyer)

    if order.tradeItem then
        local tradeQty = order.tradeQuantity * quantity
        if not exports.ox_inventory:AddItem(source, order.tradeItem, tradeQty) then
            exports.ox_inventory:AddItem(source, order.item, quantity) -- refund what we took
            return notify(source, 'error', 'Not enough inventory space.')
        end
    else
        local totalPrice = order.price * quantity
        local fee = math.floor(totalPrice * ((Config.Settings.transactionFeePercent or 0) / 100))
        local payout = totalPrice - fee

        if not exports.ox_inventory:AddItem(source, CURRENCY, payout) then
            exports.ox_inventory:AddItem(source, order.item, quantity)
            return notify(source, 'error', 'Not enough inventory space.')
        end
    end

    if buyer and exports.ox_inventory:AddItem(buyer.PlayerData.source, order.item, quantity) then
        -- delivered directly
    else
        MySQL.insert.await(
            'INSERT INTO vl_outpost_pickups (owner, sellerName, item, quantity, price, totalPrice, fulfilledTimestamp) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { order.buyer, playerName(fulfiller), order.item, quantity, 0, 0, now() }
        )
    end

    if quantity >= order.quantity then
        MySQL.query.await('DELETE FROM vl_outpost_buy_orders WHERE id = ?', { orderId })
    else
        MySQL.query.await('UPDATE vl_outpost_buy_orders SET quantity = quantity - ? WHERE id = ?', { quantity, orderId })
    end

    addHistory({
        type = 'fulfill', item = order.item, quantity = quantity,
        price = order.price, totalPrice = order.price * quantity,
        sellerName = playerName(fulfiller), buyerName = order.buyerName,
    })

    notify(source, 'success', 'Order fulfilled.')
    if buyer then notify(buyer.PlayerData.source, 'inform', ('Your buy order for %s was fulfilled.'):format(order.item)) end
    broadcastRefresh()
end)

-- =============================================================================
-- PICKUPS / HISTORY / REFRESH
-- =============================================================================

RegisterNetEvent('bs_market:pickupOrder', function(pickupId)
    local source = source
    local player = getPlayer(source)
    if not player then return end

    local pickup = MySQL.single.await('SELECT * FROM vl_outpost_pickups WHERE id = ?', { pickupId })
    if not pickup or pickup.owner ~= player.PlayerData.citizenid then
        return notify(source, 'error', 'That pickup is not yours.')
    end

    local metadata = pickup.metadata and pickup.metadata ~= '' and json.decode(pickup.metadata) or nil
    local amount = pickup.item == CURRENCY and pickup.totalPrice or pickup.quantity

    if not exports.ox_inventory:AddItem(source, pickup.item, amount, metadata) then
        return notify(source, 'error', 'Not enough inventory space to claim this.')
    end

    MySQL.query.await('DELETE FROM vl_outpost_pickups WHERE id = ?', { pickupId })
    notify(source, 'success', 'Picked up.')
    TriggerClientEvent('bs_market:receivePickups', source, getPickups(player.PlayerData.citizenid))
end)

RegisterNetEvent('bs_market:getPickups', function()
    local source = source
    local player = getPlayer(source)
    if not player then return end
    TriggerClientEvent('bs_market:receivePickups', source, getPickups(player.PlayerData.citizenid))
end)

RegisterNetEvent('bs_market:getHistory', function()
    TriggerClientEvent('bs_market:receiveHistory', source, getHistory())
end)

RegisterNetEvent('bs_market:getInventoryItems', function()
    local source = source
    TriggerClientEvent('bs_market:receiveInventoryItems', source, getInventoryItemsFor(source))
end)

RegisterNetEvent('bs_market:requestRefresh', function()
    local source = source
    local player = getPlayer(source)
    if not player then return end
    TriggerClientEvent('bs_market:refreshData', source, getListings(), getBuyOrders(), getPickups(player.PlayerData.citizenid))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        openMarketPlayers = {}
    end
end)
