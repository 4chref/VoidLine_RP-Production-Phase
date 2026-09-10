function IsPlayerUnreachable()
    local playerPed = PlayerPedId()
    return IsPedRagdoll(playerPed) or IsEntityDead(playerPed)
end


function KeybindTip(message)
    SetTextComponentFormat("STRING")
    AddTextComponentString(message)
    EndTextCommandDisplayHelp(0, 0, 0, 200)
end

-- This function is responsible for all the tooltips displayed on top right of the screen, you could
-- replace it with a custom notification etc.
function Notify(message)
    SetTextComponentFormat("STRING")
    AddTextComponentString(message)
    EndTextCommandDisplayHelp(0, 0, 0, -1)
end

RegisterNetEvent('kq_lasers:client:notify')
AddEventHandler('kq_lasers:client:notify', function(message)
    Notify(message)
end)

function PlayAnim(dict, anim, flag, duration)
    Citizen.CreateThread(function()
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) do
            Citizen.Wait(50)
            timeout = timeout + 1
            if timeout > 100 then
                return
            end
        end
        TaskPlayAnim(PlayerPedId(), dict, anim, 1.5, 1.0, duration or -1, flag or 1, 0, false, false, false)
        RemoveAnimDict(dict)
    end)
end

-- Keybinds display
buttons = nil
keybinds = {}

function AddKeybindDisplay(key, label)
    buttons = nil
    
    table.insert(keybinds, {
        key = '~' .. key .. '~',
        label = label,
    })
    
    buttons = RequestScaleformMovie("INSTRUCTIONAL_BUTTONS")
    while not HasScaleformMovieLoaded(buttons) do
        Wait(0)
    end
    
    BeginScaleformMovieMethod(buttons, "CLEAR_ALL")
    EndScaleformMovieMethod()
    
    for k, keybind in pairs(keybinds) do
        BeginScaleformMovieMethod(buttons, "SET_DATA_SLOT")
        ScaleformMovieMethodAddParamInt(k - 1)
        ScaleformMovieMethodAddParamPlayerNameString(keybind.key)
        PushScaleformMovieMethodParameterString(keybind.label)
        EndScaleformMovieMethod()
    end
    
    BeginScaleformMovieMethod(buttons, "DRAW_INSTRUCTIONAL_BUTTONS")
    EndScaleformMovieMethod()
end

function ClearKeybinds()
    buttons = nil
    keybinds = {}
end


Citizen.CreateThread(function()
    while true do
        local sleep = 500
        
        if buttons ~= nil then
            sleep = 1
            DrawScaleformMovieFullscreen(buttons, 255, 255, 255, 255, 0)
        end
        Citizen.Wait(sleep)
    end
end)
