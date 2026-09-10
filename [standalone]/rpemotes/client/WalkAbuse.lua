local trippingWalkstyles = {
    -- ["move_f@flee@a"] = true,
    -- ["move_f@flee@c"] = true,
    -- ["move_m@flee@a"] = true,
    -- ["move_m@flee@b"] = true,
    -- ["move_m@flee@c"] = true,
    ["move_characters@orleans@core@"] = true,
    ["move_m@hurry@a"] = true,
    ["move_f@hurry@a"] = true,
    ["move_f@hurry@b"] = true
}

local function tripPlayer(time)
    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.08)
    --SetPedToRagdoll(cache.ped, time, time, 0, 0, 0, 0) -- uncomment of using ox_lib
    SetPedToRagdoll(PlayerPedId(), time, time, 0, 0, 0, 0) -- comment out if using ox_lib
end

local function isUsingCheeseWalk()
    local walk = exports.rpemotes:getWalkstyle()

    if not walk then
        return
    end

    return trippingWalkstyles[walk]
end

-- local lastWalkCheck = 0
-- local walkCheeseInterval = 0
local function isCheeseWalking()
    -- if time - lastWalkCheck < walkCheeseInterval then return end
    -- lastWalkCheck = time
    if isUsingCheeseWalk() then -- comment out if using ox_lib
        -- if math.random() < 0.15 and (IsPedSprinting(cache.ped) or IsPedRunning(cache.ped)) then -- uncomment for ox_lib
        tripPlayer(3000)
    lib.notify({ -- uncomment for ox_lib
        title = '😨',
        description = 'Ahhhhhhhhhh!!!!',
        duration = 700,
        type = 'warning'
    })
    end
end

exports("isCheeseWalking", isCheeseWalking)

CreateThread(
    function()
        while true do
            Wait(5000)
            if (IsPedSprinting(PlayerPedId()) or IsPedRunning(PlayerPedId())) then
                isCheeseWalking()
            end
        end
    end)
