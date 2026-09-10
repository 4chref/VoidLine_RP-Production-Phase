
RegisterNetEvent('919-admin:client:ToggleDuty', function()
    print('[919ADMIN] ToggleDuty event received from Radial Menu')
    if AdminDuty.Active then
        ExecuteCommand('dutyoff')
    else
        ExecuteCommand('dutyon')
    end
end)
