-- =============================================================================
-- vl_jobs -- client
--
-- Spawns the foreman, offers the job menu, and shows the player where to work.
-- Job-agnostic: everything comes from VLJobs.jobs, so a new job needs no code.
-- Holds no authority -- the server assigns points and validates every completion.
-- =============================================================================

local foremanPed = nil

---@type {job: string, points: vector4[], done: boolean[], zones: string[], blips: number[]}|nil
local shift = nil

-- -----------------------------------------------------------------------------
-- Indicators: blips, GPS route, in-world markers
-- -----------------------------------------------------------------------------

---Route the GPS to the nearest point still outstanding, so the line always
---points at something useful instead of the first one in the list.
local function refreshRoute()
    if not shift or not VLJobs.indicator.gpsRoute then return end

    for i = 1, #shift.blips do
        if shift.blips[i] then SetBlipRoute(shift.blips[i], false) end
    end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local bestIdx, bestDist

    for i = 1, #shift.points do
        if not shift.done[i] and shift.blips[i] then
            local p = shift.points[i]
            local d = #(pos - vec3(p.x, p.y, p.z))
            if not bestDist or d < bestDist then bestIdx, bestDist = i, d end
        end
    end

    if bestIdx then
        SetBlipRoute(shift.blips[bestIdx], true)
        SetBlipRouteColour(shift.blips[bestIdx], VLJobs.indicator.routeColour or 5)
    end
end

local function clearShift()
    if not shift then return end

    for i = 1, #shift.zones do
        if shift.zones[i] then exports.ox_target:removeZone(shift.zones[i]) end
    end
    for i = 1, #shift.blips do
        if shift.blips[i] and DoesBlipExist(shift.blips[i]) then RemoveBlip(shift.blips[i]) end
    end

    shift = nil
end

---Draws the floating marker over outstanding points. Only runs while a shift is
---active, and only spends a per-frame wait when something is actually in range.
CreateThread(function()
    local ind = VLJobs.indicator
    while true do
        local sleep = 500

        if shift and ind.marker then
            local pos = GetEntityCoords(PlayerPedId())
            local bob = ind.markerBob and (math.sin(GetGameTimer() / 400.0) * 0.12) or 0.0

            for i = 1, #shift.points do
                if not shift.done[i] then
                    local p = shift.points[i]
                    local d = #(pos - vec3(p.x, p.y, p.z))
                    if d <= (ind.markerDrawDistance or 60.0) then
                        sleep = 0
                        DrawMarker(
                            ind.markerType or 21,
                            p.x, p.y, p.z + 1.0 + bob,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            ind.markerSize.x, ind.markerSize.y, ind.markerSize.z,
                            240, 190, 60, 160,
                            false, true, 2, false, nil, nil, false
                        )
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- -----------------------------------------------------------------------------
-- Working a point
-- -----------------------------------------------------------------------------

local function workPoint(index)
    if not shift then return end
    local cfg = VLJobs.jobs[shift.job]
    if not cfg then return end

    local ok = lib.progressBar({
        duration = cfg.durationMs or 5000,
        label = cfg.progressLabel or 'Working',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = cfg.anim,
        prop = cfg.prop,
    })

    if not ok then
        lib.notify({ title = 'Work', description = 'Cancelled.', type = 'inform' })
        return
    end

    local accepted, message, remaining = lib.callback.await('vl_jobs:server:complete', false, index)

    lib.notify({
        title = 'Work',
        description = message,
        type = accepted and 'success' or 'error',
    })

    if not accepted then return end

    shift.done[index] = true

    if shift.zones[index] then
        exports.ox_target:removeZone(shift.zones[index])
        shift.zones[index] = nil
    end
    if shift.blips[index] and DoesBlipExist(shift.blips[index]) then
        RemoveBlip(shift.blips[index])
        shift.blips[index] = nil
    end

    if remaining == 0 then
        clearShift()
    else
        refreshRoute()
    end
end

---@param jobName string
---@param points vector4[]
---@param done boolean[]|nil
local function setupShift(jobName, points, done)
    clearShift()

    local cfg = VLJobs.jobs[jobName]
    if not cfg then return end

    local ind = VLJobs.indicator
    shift = { job = jobName, points = points, done = done or {}, zones = {}, blips = {} }

    for i = 1, #points do
        if shift.done[i] == nil then shift.done[i] = false end

        if not shift.done[i] then
            local p = points[i]
            local id = ('vl_jobs_%s_%d'):format(jobName, i)

            shift.zones[i] = exports.ox_target:addSphereZone({
                name = id,
                coords = vec3(p.x, p.y, p.z),
                radius = cfg.interactDistance or 1.8,
                debug = false,
                options = {
                    {
                        name = id .. '_do',
                        icon = cfg.actionIcon or 'fas fa-wrench',
                        label = cfg.actionLabel or 'Work here',
                        onSelect = function() workPoint(i) end,
                    },
                },
            })

            if ind.blips then
                local blip = AddBlipForCoord(p.x, p.y, p.z)
                SetBlipSprite(blip, cfg.blipSprite or 402)
                SetBlipColour(blip, cfg.blipColour or 5)
                SetBlipScale(blip, 0.8)
                SetBlipAsShortRange(blip, false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(cfg.blipName or 'Work point')
                EndTextCommandSetBlipName(blip)
                shift.blips[i] = blip
            end
        end
    end

    refreshRoute()
end

-- =============================================================================
-- HAUL JOB -- pickup, carry, drop off, repeat
-- =============================================================================

local carry = { prop = nil, active = false, model = nil, offset = nil, rot = nil, bone = nil }

---Attachment values for a given crate, honouring any per-model override.
---@param cfg table
---@param modelName string
local function carryPlacement(cfg, modelName)
    local o = cfg.boxOffsets and cfg.boxOffsets[modelName]
    return
        (o and o.bone) or cfg.carryBone or 60309,
        (o and o.offset) or cfg.carryOffset,
        (o and o.rot) or cfg.carryRot
end

local function stopCarry()
    if carry.prop and DoesEntityExist(carry.prop) then
        DeleteEntity(carry.prop)
    end
    carry.prop = nil
    carry.active = false
    ClearPedTasks(PlayerPedId())
end

---Attach a crate to the player's hands and hold the carry pose.
---@param modelName string
local function startCarry(modelName, cfg)
    stopCarry()

    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) then
        print(('[vl_jobs] crate model "%s" invalid; using fallback'):format(modelName))
        hash = joaat(cfg.boxFallback)
        if not IsModelInCdimage(hash) then
            print('[vl_jobs] fallback crate model is invalid too - carrying nothing visible')
            hash = nil
        end
    end

    local ped = PlayerPedId()

    if hash then
        pcall(lib.requestModel, hash, 10000)
        if HasModelLoaded(hash) then
            local bone, off, rot = carryPlacement(cfg, modelName)
            local c = GetEntityCoords(ped)

            carry.prop = CreateObject(hash, c.x, c.y, c.z, true, true, false)
            -- No collision on the carried prop: with it on, the box shoves the
            -- player around and snags on doorways while attached.
            SetEntityCollision(carry.prop, false, false)

            AttachEntityToEntity(
                carry.prop, ped, GetPedBoneIndex(ped, bone),
                off.x, off.y, off.z,
                rot.x, rot.y, rot.z,
                true, true, false, true, 1, true
            )
            SetModelAsNoLongerNeeded(hash)

            -- Remembered so /crateadjust can re-attach without a restart.
            carry.model, carry.bone, carry.offset, carry.rot = modelName, bone, off, rot
        end
    end

    carry.active = true

    -- Hold the carry pose. Re-applied on a slow tick because getting into a
    -- vehicle, ragdolling or another script's task will clear it.
    CreateThread(function()
        local a = cfg.carryAnim
        if not a then return end

        pcall(lib.requestAnimDict, a.dict, 5000)

        while carry.active do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, a.dict, a.clip, 3) then
                TaskPlayAnim(p, a.dict, a.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
            end
            Wait(600)
        end
    end)
end

-- Live tuning for the carried crate. Prop origins differ between models, so
-- rather than guessing offsets, adjust it in game while holding one and paste
-- the printed line into VLJobs.jobs.crates.boxOffsets.
--
--   /crateadjust                       -> show current values
--   /crateadjust 0.02 0.08 0.25        -> set offset
--   /crateadjust 0.02 0.08 0.25 -145 290 0  -> set offset and rotation
RegisterCommand('crateadjust', function(_, args)
    if not carry.prop or not DoesEntityExist(carry.prop) then
        print('[vl_jobs] not carrying a crate right now')
        return
    end

    if #args >= 3 then
        carry.offset = vec3(tonumber(args[1]) or 0.0, tonumber(args[2]) or 0.0, tonumber(args[3]) or 0.0)
    end
    if #args >= 6 then
        carry.rot = vec3(tonumber(args[4]) or 0.0, tonumber(args[5]) or 0.0, tonumber(args[6]) or 0.0)
    end

    local ped = PlayerPedId()
    DetachEntity(carry.prop, true, true)
    AttachEntityToEntity(
        carry.prop, ped, GetPedBoneIndex(ped, carry.bone),
        carry.offset.x, carry.offset.y, carry.offset.z,
        carry.rot.x, carry.rot.y, carry.rot.z,
        true, true, false, true, 1, true
    )

    print(('[vl_jobs] paste into boxOffsets:\n'
        .. "    ['%s'] = { offset = vec3(%.3f, %.3f, %.3f), rot = vec3(%.1f, %.1f, %.1f) },")
        :format(carry.model or '?', carry.offset.x, carry.offset.y, carry.offset.z,
                carry.rot.x, carry.rot.y, carry.rot.z))
end, false)

-- Swap the held crate to any prop, instantly, without restarting. Prop sizes
-- cannot be judged from the model name, so audition them rather than guessing.
--
--   /cratemodels              -> list the candidates
--   /cratemodel prop_name     -> hold that prop right now
--   /cratenext                -> step to the next candidate
local candidateIndex = 0

local function swapHeldCrate(name)
    if not carry.active then
        print('[vl_jobs] pick up a crate first, then run this again')
        return
    end

    local cfg = VLJobs.jobs.crates
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then
        print(('[vl_jobs] "%s" does not exist on this build'):format(name))
        return
    end

    if carry.prop and DoesEntityExist(carry.prop) then DeleteEntity(carry.prop) end

    pcall(lib.requestModel, hash, 10000)
    if not HasModelLoaded(hash) then
        print(('[vl_jobs] "%s" failed to load'):format(name))
        return
    end

    local ped = PlayerPedId()
    local bone, off, rot = carryPlacement(cfg, name)
    local c = GetEntityCoords(ped)

    carry.prop = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetEntityCollision(carry.prop, false, false)
    AttachEntityToEntity(carry.prop, ped, GetPedBoneIndex(ped, bone),
        off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)

    carry.model, carry.bone, carry.offset, carry.rot = name, bone, off, rot
    print(('[vl_jobs] now holding "%s" -- tune with /crateadjust, then put it in boxModels'):format(name))
end

RegisterCommand('cratemodel', function(_, args)
    if not args[1] then print('[vl_jobs] usage: /cratemodel <prop_name>') return end
    swapHeldCrate(args[1])
end, false)

RegisterCommand('cratenext', function()
    local list = VLJobs.jobs.crates.boxCandidates or {}
    if #list == 0 then return end
    candidateIndex = (candidateIndex % #list) + 1
    print(('[vl_jobs] candidate %d/%d'):format(candidateIndex, #list))
    swapHeldCrate(list[candidateIndex])
end, false)

RegisterCommand('cratemodels', function()
    local list = VLJobs.jobs.crates.boxCandidates or {}
    print('[vl_jobs] crate candidates (roughly smallest first):')
    for i = 1, #list do
        local exists = IsModelInCdimage(joaat(list[i])) and 'ok     ' or 'MISSING'
        print(('  %2d. [%s] %s'):format(i, exists, list[i]))
    end
    print('[vl_jobs] hold a crate, then /cratenext to step through them')
end, false)

local haul = nil   -- { total, delivered, carrying, zones = {}, blips = {} }

local function clearHaul()
    if not haul then return end
    for _, id in ipairs(haul.zones) do exports.ox_target:removeZone(id) end
    for _, b in ipairs(haul.blips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
    end
    haul = nil
    stopCarry()
end

local function makeBlip(coords, sprite, colour, name)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, colour)
    SetBlipScale(b, 0.8)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(b)
    return b
end

local buildHaulZones   -- forward declaration

---Route/marker point at whatever the player should head to next.
local function haulTarget(cfg)
    if not haul then return nil end
    if not haul.carrying then return cfg.pickup end

    local pos = GetEntityCoords(PlayerPedId())
    local best, bestD
    for i = 1, #cfg.dropoffs do
        local d = #(pos - vec3(cfg.dropoffs[i].x, cfg.dropoffs[i].y, cfg.dropoffs[i].z))
        if not bestD or d < bestD then best, bestD = cfg.dropoffs[i], d end
    end
    return best
end

local function doPickup(cfg)
    local ok, message, model = lib.callback.await('vl_jobs:server:pickup', false)
    if not ok then
        lib.notify({ title = 'Work', description = message, type = 'error' })
        return
    end

    if not lib.progressBar({
        duration = cfg.pickupMs or 2500,
        label = cfg.pickupProgress or 'Lifting',
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'anim@heists@narcotics@trash', clip = 'pickup' },
    }) then return end

    haul.carrying = true
    startCarry(model, cfg)
    lib.notify({ title = 'Work', description = message, type = 'success' })
    buildHaulZones(cfg)
end

local function doDeliver(cfg)
    if not haul or not haul.carrying then
        lib.notify({ title = 'Work', description = 'You are not carrying a crate.', type = 'error' })
        return
    end

    if not lib.progressBar({
        duration = cfg.dropMs or 2000,
        label = cfg.dropProgress or 'Setting it down',
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'anim@heists@narcotics@trash', clip = 'drop' },
    }) then return end

    local ok, message, remaining = lib.callback.await('vl_jobs:server:deliver', false)

    lib.notify({
        title = 'Work',
        description = message,
        type = ok and 'success' or 'error',
    })
    if not ok then return end

    haul.carrying = false
    stopCarry()

    if remaining == 0 then
        clearHaul()
    else
        haul.delivered = haul.total - remaining
        buildHaulZones(cfg)
    end
end

---Rebuilt whenever the carry state flips, so only the relevant zone is live:
---the pallet when empty-handed, the storage room when loaded.
function buildHaulZones(cfg)
    if not haul then return end

    for _, id in ipairs(haul.zones) do exports.ox_target:removeZone(id) end
    for _, b in ipairs(haul.blips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
    end
    haul.zones, haul.blips = {}, {}

    if not haul.carrying then
        haul.zones[#haul.zones + 1] = exports.ox_target:addSphereZone({
            name = 'vl_jobs_crate_pickup',
            coords = vec3(cfg.pickup.x, cfg.pickup.y, cfg.pickup.z),
            radius = cfg.interactDistance or 2.0,
            options = {{
                name = 'vl_jobs_crate_pickup_do',
                icon = cfg.pickupIcon or 'fas fa-box-open',
                label = cfg.pickupLabel or 'Pick up a crate',
                onSelect = function() doPickup(cfg) end,
            }},
        })
        if VLJobs.indicator.blips then
            haul.blips[1] = makeBlip(cfg.pickup, cfg.blipSpritePickup or 478,
                cfg.blipColour or 47, cfg.blipNamePickup or 'Crate pallet')
        end
    else
        for i = 1, #cfg.dropoffs do
            local d = cfg.dropoffs[i]
            local id = ('vl_jobs_crate_drop_%d'):format(i)
            haul.zones[#haul.zones + 1] = exports.ox_target:addSphereZone({
                name = id,
                coords = vec3(d.x, d.y, d.z),
                radius = cfg.interactDistance or 2.0,
                options = {{
                    name = id .. '_do',
                    icon = cfg.dropIcon or 'fas fa-warehouse',
                    label = cfg.dropLabel or 'Set the crate down',
                    onSelect = function() doDeliver(cfg) end,
                }},
            })
            if VLJobs.indicator.blips then
                haul.blips[#haul.blips + 1] = makeBlip(d, cfg.blipSpriteDrop or 473,
                    cfg.blipColour or 47, cfg.blipNameDrop or 'Storage room')
            end
        end
    end

    -- GPS to whichever end of the loop they need next.
    if VLJobs.indicator.gpsRoute then
        for _, b in ipairs(haul.blips) do SetBlipRoute(b, false) end
        local t = haulTarget(cfg)
        if t then
            for _, b in ipairs(haul.blips) do
                local bc = GetBlipCoords(b)
                if #(bc - vec3(t.x, t.y, t.z)) < 1.0 then
                    SetBlipRoute(b, true)
                    SetBlipRouteColour(b, VLJobs.indicator.routeColour or 5)
                    break
                end
            end
        end
    end
end

---Marker over the next haul objective.
CreateThread(function()
    while true do
        local sleep = 500
        local ind = VLJobs.indicator

        if haul and ind.marker then
            local cfg = VLJobs.jobs.crates
            local t = haulTarget(cfg)
            if t then
                local pos = GetEntityCoords(PlayerPedId())
                if #(pos - vec3(t.x, t.y, t.z)) <= (ind.markerDrawDistance or 60.0) then
                    sleep = 0
                    local bob = ind.markerBob and (math.sin(GetGameTimer() / 400.0) * 0.12) or 0.0
                    DrawMarker(ind.markerType or 21, t.x, t.y, t.z + 1.0 + bob,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        ind.markerSize.x, ind.markerSize.y, ind.markerSize.z,
                        240, 150, 60, 160, false, true, 2, false, nil, nil, false)
                end
            end
        end

        Wait(sleep)
    end
end)

local function setupHaul(cfg, delivered, total)
    clearHaul()
    haul = { total = total, delivered = delivered or 0, carrying = false, zones = {}, blips = {} }
    buildHaulZones(cfg)
end

-- -----------------------------------------------------------------------------
-- Foreman menu
-- -----------------------------------------------------------------------------

local function startJob(jobName)
    local ok, message, data = lib.callback.await('vl_jobs:server:start', false, jobName)

    lib.notify({
        title = 'Work',
        description = message,
        type = ok and 'success' or 'error',
    })

    if not ok or not data then return end

    if data.haul then
        setupHaul(VLJobs.jobs[data.job], 0, data.total)
    elseif data.points then
        setupShift(data.job, data.points)
    end
end

-- -----------------------------------------------------------------------------
-- The board (NUI)
--
-- Replaces an ox_lib context menu with a custom page styled after af-camping's
-- campfire panel. Restyling ox_lib itself was the alternative and was rejected:
-- its menu CSS is shared by every resource on this server, so theming it for
-- one job board would have dragged every other menu along with it.
--
-- The page decides nothing. It is handed every job plus the current shift state
-- in one message, and posts back a key -- startJob() and the cancel callback
-- below are still the only things that change anything.
-- -----------------------------------------------------------------------------

local JOB_ORDER <const> = { 'electricity', 'cleaning', 'crates' }

local menuOpen = false

---Item label from ox_inventory, falling back to the raw name.
---@param name string?
---@return string?
local function itemLabel(name)
    if not name then return nil end
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return (ok and item and item.label) or name
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
end

local function endShift()
    local cancelled = lib.callback.await('vl_jobs:server:cancel', false)
    clearShift()
    clearHaul()
    lib.notify({
        title = 'Work',
        description = cancelled and 'Shift ended.' or 'You are not on a shift.',
        type = 'inform',
    })
end

RegisterNUICallback('start', function(data, cb)
    cb('ok')
    closeMenu()

    local key = type(data) == 'table' and data.key or nil
    -- Re-checked here, not trusted from the page: `enabled` is only a rendering
    -- hint over there, and the page is the one thing a player can tamper with.
    local cfg = key and VLJobs.jobs[key]
    if not cfg or not cfg.enabled then return end

    startJob(key)
end)

RegisterNUICallback('quit', function(_, cb)
    cb('ok')
    closeMenu()
    endShift()
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    closeMenu()
end)

local function openMenu()
    local payload = {}

    for _, key in ipairs(JOB_ORDER) do
        local cfg = VLJobs.jobs[key]
        if cfg then
            local reward = cfg.reward

            payload[#payload + 1] = {
                key         = key,
                label       = cfg.label,
                description = cfg.description,
                enabled     = cfg.enabled and true or false,
                -- `crates` counts round trips instead of fixed points, so it
                -- carries cratesPerJob. Without this fallback the haul job
                -- showed a blank Tasks tile.
                points      = cfg.pointsPerJob or cfg.cratesPerJob,
                tool        = itemLabel(cfg.tool),
                reward      = reward and ('%d %s'):format(reward.amount or 0, itemLabel(reward.item) or '')
                              or nil,
                -- Seconds read better than milliseconds on a card, and the
                -- config is the only place that needs to know the real unit.
                duration    = cfg.durationMs and ('%.0fs'):format(cfg.durationMs / 1000) or nil,

                -- ox_inventory art name. Separate from `tool` because `crates`
                -- lends nothing but still needs a picture -- see config.lua.
                image       = cfg.menuImage,
            }
        end
    end

    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action   = 'open',
        subtitle = VLJobs.menuSubtitle or "Foreman's board",
        jobs     = payload,
        -- `shift` is this file's own state, so the board always reflects what
        -- is actually running rather than what the server last said.
        running  = shift and shift.job or nil,
    })
end

-- -----------------------------------------------------------------------------
-- The ped
-- -----------------------------------------------------------------------------

local function resolveModel()
    local cfg = VLJobs.foreman
    for _, name in ipairs({ cfg.model, cfg.fallback }) do
        if name then
            local hash = joaat(name)
            if IsModelInCdimage(hash) and IsModelAPed(hash) then
                local ok = pcall(lib.requestModel, hash, 20000)
                if ok and HasModelLoaded(hash) then
                    if name ~= cfg.model then
                        print(('[vl_jobs] model "%s" invalid on this build; using "%s"'):format(cfg.model, name))
                    end
                    return hash
                end
            else
                print(('[vl_jobs] "%s" is not a valid ped model on this build'):format(name))
            end
        end
    end
    print('[vl_jobs] no usable ped model - foreman not spawned.')
    return nil
end

local function spawnForeman()
    if foremanPed and DoesEntityExist(foremanPed) then return end

    local cfg = VLJobs.foreman
    local model = resolveModel()
    if not model then return end

    local c = cfg.coords
    -- No -1.0: the coords came from /vec4, which already applies it.
    foremanPed = CreatePed(4, model, c.x, c.y, c.z, c.w, false, false)
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(foremanPed, true)
    FreezeEntityPosition(foremanPed, true)
    SetBlockingOfNonTemporaryEvents(foremanPed, true)
    SetEntityAsMissionEntity(foremanPed, true, true)
    TaskStartScenarioInPlace(foremanPed, cfg.scenario, 0, true)

    exports.ox_target:addLocalEntity(foremanPed, {
        {
            name = 'vl_jobs_foreman',
            icon = cfg.icon,
            label = cfg.label,
            distance = cfg.distance,
            onSelect = openMenu,
        },
    })

    print(('[vl_jobs] foreman spawned at %.2f, %.2f, %.2f'):format(c.x, c.y, c.z))
end

local function deleteForeman()
    if foremanPed and DoesEntityExist(foremanPed) then
        exports.ox_target:removeLocalEntity(foremanPed, 'vl_jobs_foreman')
        DeleteEntity(foremanPed)
    end
    foremanPed = nil
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(1000)
    spawnForeman()

    -- Rebuild the shift if the player reconnected part-way through one.
    local current = lib.callback.await('vl_jobs:server:current', false)
    if current then
        if current.haul then
            setupHaul(VLJobs.jobs[current.job], current.delivered, current.total)
        elseif current.points then
            setupShift(current.job, current.points, current.done)
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    spawnForeman()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deleteForeman()
    clearShift()
    -- Must run, or the attached crate is left welded to the player with no
    -- script alive to remove it.
    clearHaul()
    -- Same reason: NUI focus outlives the page, so dying with the board open
    -- would leave the player holding a cursor and no menu. Folded into the
    -- existing teardown rather than registered as a second handler for the
    -- same event -- one place to look when something is not being cleaned up.
    closeMenu()
end)
