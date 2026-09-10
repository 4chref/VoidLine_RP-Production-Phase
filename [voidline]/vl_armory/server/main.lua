local itemsByName = {}
for _, item in ipairs(Config.Items) do
    itemsByName[item.name] = item
end

lib.callback.register('vl_armory:server:take', function(source, itemName)
    local item = itemsByName[itemName]
    if not item then return false end

    -- Distance check: the player must actually be at the armory
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    if #(coords - Config.Coords.xyz) > Config.InteractDistance + 1.0 then
        return false
    end

    if GetResourceState('ox_inventory') ~= 'started' then return false end

    local added = exports.ox_inventory:AddItem(source, item.name, item.amount)
    return added and true or false
end)
