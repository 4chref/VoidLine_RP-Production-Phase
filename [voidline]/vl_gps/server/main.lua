exports.qbx_core:CreateUseableItem(Config.ItemName, function(source)
    TriggerClientEvent('af-gps:client:use', source)
end)
