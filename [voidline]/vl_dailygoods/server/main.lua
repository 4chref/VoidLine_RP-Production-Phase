lib.callback.register('vl_dailygoods:server:buy', function(source, itemName)
    local item = Config.ItemsByName[itemName]
    if not item then return { success = false, reason = 'unknown_item' } end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return { success = false, reason = 'no_ped' } end
    local coords = GetEntityCoords(ped)
    if #(coords - Config.Coords.xyz) > Config.InteractDistance + 1.0 then
        return { success = false, reason = 'too_far' }
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        return { success = false, reason = 'no_inventory' }
    end

    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return { success = false, reason = 'no_player' } end

    if Player.PlayerData.money.cash < item.price then
        return { success = false, reason = 'cant_afford' }
    end

    -- Check inventory room BEFORE charging -- CanCarryItem does not mutate
    -- state, so a failed AddItem afterwards can't happen with money already
    -- taken.
    local canCarry = exports.ox_inventory:CanCarryItem(source, item.name, 1)
    if not canCarry then
        return { success = false, reason = 'no_space' }
    end

    if not Player.Functions.RemoveMoney('cash', item.price, 'vl_dailygoods') then
        return { success = false, reason = 'cant_afford' }
    end

    local added = exports.ox_inventory:AddItem(source, item.name, 1)
    if not added then
        -- Inventory refused after all (race with something else) -- refund.
        Player.Functions.AddMoney('cash', item.price, 'vl_dailygoods-refund')
        return { success = false, reason = 'add_failed' }
    end

    return { success = true, price = item.price }
end)
