local entry = Config.EntryCoords
local dest = Config.DestinationCoords
local promptShown = false
local onCooldown = false

local function drawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)
end

local function tryUnlock()
    if onCooldown then return end
    onCooldown = true

    local input = lib.inputDialog('Data Room Access', {
        {
            type = 'input',
            label = 'Password',
            password = true,
            required = true
        }
    })

    if input and input[1] then
        if tostring(input[1]) == Config.Password then
            lib.notify({ title = 'Access Granted', description = 'Unlocking data room...', type = 'success' })
            DoScreenFadeOut(400)
            Wait(450)
            SetEntityCoords(cache.ped, dest.x, dest.y, dest.z, false, false, false, true)
            SetEntityHeading(cache.ped, dest.w)
            Wait(300)
            DoScreenFadeIn(400)
        else
            lib.notify({ title = 'Access Denied', description = 'Incorrect password.', type = 'error' })
        end
    end

    onCooldown = false
end

CreateThread(function()
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(cache.ped)
        local dist = #(playerCoords - vector3(entry.x, entry.y, entry.z))

        if dist < Config.MarkerDrawDistance then
            sleep = 0
            DrawMarker(1, entry.x, entry.y, entry.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.6,
                65, 105, 225, 140, false, true, 2, false, nil, nil, false)

            if dist < Config.InteractDistance then
                drawText3D(vector3(entry.x, entry.y, entry.z + 0.1), '[E] Access Data Room')
                if IsControlJustPressed(0, 38) then -- E
                    tryUnlock()
                end
            end
        end

        Wait(sleep)
    end
end)
