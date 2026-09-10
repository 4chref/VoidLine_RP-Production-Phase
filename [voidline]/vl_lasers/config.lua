Config = {}

Config.debug = false

--- SETTINGS FOR ESX
Config.esxSettings = {
    enabled = false,
    -- Whether or not to use the new ESX export method
    useNewESXExport = true,
}

--- SETTINGS FOR QBCORE (bridges to qbx_core on this server -- see
--- main/client/editable/qb.lua)
Config.qbSettings = {
    enabled = true,
}

--- IF USING A STANDALONE SOLUTION. SIMPLY DISABLE BOTH FRAMEWORKS



-- https://docs.fivem.net/docs/game-references/controls/
-- Use the input index for the "input" value
Config.keybinds = {
    debug = {
        label = 'E',
        name = 'INPUT_PICKUP',
        input = 38,
    },
}


------------------------------------------
--- LASERS
------------------------------------------

Config.laser = {
    -- Overal maximum render distance for all lasers
    maxRenderDistance = 50.0,
    
    -- Laser prop
    prop = {
        -- Whether to use the laser prop
        enabled = true,
        -- The prop model
        model = 'w_at_sr_supp_2',
        -- The prop offset
        offset = vector3(-0.022, 0.0, 0.0),
        -- The prop rotation offset
        rotation = vector3(0.0, 180.0, 0.0),
    },
    
    -- All lasers
    -- Please refer to the documentation.md file to learn more.
    lasers = {
        ['test'] = {
            origin = vector3(-924.9017, -2946.101, 13.738),
            endPoint = vector3(-920.802, -2949.351, 14.320),

            maxLength = 15.0,

            damage = 5,
            ragdoll = true,

            triggers = {
                {
                    event = 'kq_lasers:dispatch:client:trigger',
                    type = 'client',
                    parameters = {
                        title = 'Laser tripped!',
                        message = 'a security laser at the LSIA has been tripped.',
                        jobs = { 'police' },
                    },
                }
            }
        },
        ['test2'] = {
            origin = vector3(-921.998, -2951.743, 14.3),
            endPoint = vector3(-926.485, -2948.844, 14.3),

            maxLength = 15.0,

            cooldown = 5000,
        },
        ['test3'] = {
            origin = vector3(-921.998, -2951.743, 14.6),
            endPoint = vector3(-926.485, -2948.844, 14.6),

            maxLength = 15.0,

            cooldown = 5000,
        },
        ['test4'] = {
            origin = vector3(-928.17, -2951.77, 13.17),
            endPoint = vector3(-923.66, -2954.62, 13.17),

            maxLength = 8.0,

            cooldown = 5000,
        },
        ['example_handler'] = {
            origin = vector3(573.30, -3116.0, 18.6),
            endPoint = vector3(573.61, -3119.74, 18.61),

            maxLength = 8.0,

            cooldown = 50000,
            
            -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                local model = 'csb_mweather'
                RequestModel(model)
                while not HasModelLoaded(model) do
                    Citizen.Wait(1)
                end
                
                local ped = CreatePed(0, model, vector3(582.06, -3118.0, 18.7), 90.0, true, false)
                SetModelAsNoLongerNeeded(model)
                
                GiveWeaponToPed(ped, 'WEAPON_APPISTOL', 60, false, true)
                SetPedCombatAbility(ped, 1)
                
                TaskCombatPed(ped, PlayerPedId(), 0, 16)
            end
        },
    }
}

------------------------------------------
--- DISPATCH
------------------------------------------

Config.dispatch = {
    system = 'default',   -- Setting for the dispatch system to use ('default' for the built-in system or 'cd-dispatch', 'core-dispatch-old', 'core-dispatch-new' or 'ps-dispatch' for external systems)

    globalCooldown = 30,  -- The global cooldown in seconds
    blip = {
        sprite = 788,     -- Sprite for the blip
        color = 75,       -- Color for the blip
        scale = 1.0,      -- Scale for the blip

        timeout = 60,     -- Time in seconds for the blip to disappear

        showRadar = true, -- Setting to show the radar blip on the radar
    },
}
