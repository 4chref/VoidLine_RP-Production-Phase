--[[
    vl_carloot -- client half.

    Wrecks are static map props: they are spawned by the map resources, exist
    only on each client, and have no network id. So the entity handle is
    meaningless to the server and the only durable identity a wreck has is
    WHERE it is. The client sends the prop's coordinates and the server derives
    the stash id from those, re-checking the distance because they arrive from
    an untrusted source.
]]

exports.ox_target:addModel(Config.Models, {
    {
        name = 'vl_carloot:search',
        icon = 'fa-solid fa-magnifying-glass',
        label = ('Search %s'):format(Config.StashLabel:lower()),
        distance = Config.SearchDistance,

        onSelect = function(data)
            if not DoesEntityExist(data.entity) then return end

            -- The prop's own position, not the player's: two players searching
            -- the same wreck from opposite sides must resolve to one stash.
            local coords = GetEntityCoords(data.entity)

            TriggerServerEvent('vl_carloot:server:search', {
                x = coords.x,
                y = coords.y,
                z = coords.z,
            })
        end
    }
})

-- -----------------------------------------------------------------------------
-- /carmodel -- prints the model of the prop you are looking at.
-- The apocalypse maps ship wreck props under their own names, and there is no
-- way to enumerate them from the server, so this is how you find the ones
-- Config.Models misses. Add whatever it prints to that list.
-- -----------------------------------------------------------------------------
RegisterCommand('carmodel', function()
    local ped = PlayerPedId()
    local from = GetGameplayCamCoord()
    local dir = RotationToDirection(GetGameplayCamRot(2))
    local to = vec3(from.x + dir.x * 15.0, from.y + dir.y * 15.0, from.z + dir.z * 15.0)

    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, -1, ped, 4)
    local _, hit, _, _, entity = GetShapeTestResult(ray)

    if hit ~= 1 or not entity or entity == 0 then
        return lib.notify({ type = 'error', description = 'Nothing in front of you.' })
    end

    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)

    -- GetEntityModel returns a hash. There is no hash->name native, so print the
    -- hash and let Config.Models be matched by it if the name is unknown.
    print(('[vl_carloot] model hash: %s  at %.2f, %.2f, %.2f'):format(model, coords.x, coords.y, coords.z))
    lib.notify({
        type = 'inform',
        duration = 12000,
        description = ('Model hash %s — see F8 console, add it to Config.Models'):format(model)
    })
end, false)

function RotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vec3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end
