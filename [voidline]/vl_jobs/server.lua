-- =============================================================================
-- vl_jobs -- server
--
-- Authoritative and job-agnostic: everything is driven by VLJobs.jobs, so a new
-- job is a config entry, not new code. The server picks which points a player
-- gets, tracks which are done, and is the only thing that can hand out or take
-- back a tool. The client only reports "I finished point N", checked every time.
-- =============================================================================

---@type table<number, {job: string, points: vector4[], done: boolean[], started: number}>
local active = {}

local function nearCoords(src, coords, allowed)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local dx, dy, dz = c.x - coords.x, c.y - coords.y, c.z - coords.z
    return (dx * dx + dy * dy + dz * dz) <= (allowed * allowed)
end

---Fisher-Yates over a copy, then take the first n. Server-side so the client
---cannot influence which points it gets or skip the awkward ones.
local function pickRandom(list, n)
    local idx = {}
    for i = 1, #list do idx[i] = i end
    for i = #idx, 2, -1 do
        local j = math.random(i)
        idx[i], idx[j] = idx[j], idx[i]
    end

    local picked = {}
    for i = 1, math.min(n, #idx) do picked[i] = list[idx[i]] end
    return picked
end

local function reclaimTool(src, toolName)
    if not toolName then return end
    local count = exports.ox_inventory:Search(src, 'count', toolName)
    if count and count > 0 then
        exports.ox_inventory:RemoveItem(src, toolName, count)
    end
end

-- -----------------------------------------------------------------------------
-- Start a shift
-- -----------------------------------------------------------------------------

lib.callback.register('vl_jobs:server:start', function(src, jobName)
    local cfg = VLJobs.jobs[jobName]
    if not cfg or not cfg.enabled then
        return false, 'That work is not available right now.'
    end

    if VLJobs.oneJobAtATime and active[src] then
        return false, 'You are already on a shift. Finish or quit it first.'
    end

    if not nearCoords(src, VLJobs.foreman.coords, 5.0) then
        return false, 'You are not at the foreman.'
    end

    -- Haul jobs have no point list; they run a pickup/drop-off loop instead.
    if cfg.type == 'haul' then
        if not cfg.pickup or not cfg.dropoffs or #cfg.dropoffs == 0 then
            return false, 'That work has no locations set up yet.'
        end

        active[src] = {
            job = jobName,
            haul = true,
            carrying = false,
            delivered = 0,
            total = cfg.cratesPerJob or 4,
            started = os.time(),
        }

        return true, 'Shift started. Collect the first crate.', {
            job = jobName,
            haul = true,
            total = cfg.cratesPerJob or 4,
        }
    end

    if not cfg.points or #cfg.points == 0 then
        return false, 'That work has no locations set up yet.'
    end

    -- Hand out the tool first: if their pockets are full the shift never starts,
    -- rather than starting one they cannot actually do.
    if cfg.tool then
        if not exports.ox_inventory:CanCarryItem(src, cfg.tool, 1) then
            return false, 'You have no room for the equipment.'
        end
        if not exports.ox_inventory:AddItem(src, cfg.tool, 1) then
            return false, 'Could not hand you the equipment.'
        end
    end

    local points = pickRandom(cfg.points, cfg.pointsPerJob)
    local done = {}
    for i = 1, #points do done[i] = false end

    active[src] = { job = jobName, points = points, done = done, started = os.time() }

    return true, 'Shift started.', { job = jobName, points = points }
end)

-- -----------------------------------------------------------------------------
-- Report a completed point
-- -----------------------------------------------------------------------------

lib.callback.register('vl_jobs:server:complete', function(src, index)
    local job = active[src]
    if not job then return false, 'You are not on a shift.' end

    local cfg = VLJobs.jobs[job.job]
    if not cfg then return false, 'Unknown job.' end

    index = tonumber(index)
    if not index or not job.points[index] then
        return false, 'Invalid work point.'
    end

    if job.done[index] then
        -- Double-click or a replayed event: refuse rather than counting twice.
        return false, 'That one is already done.'
    end

    if not nearCoords(src, job.points[index], (cfg.interactDistance or 2.0) + 2.0) then
        return false, 'You are not at that work point.'
    end

    if cfg.tool then
        local held = exports.ox_inventory:Search(src, 'count', cfg.tool)
        if not held or held < 1 then
            return false, 'You need your equipment to do that.'
        end
    end

    job.done[index] = true

    local remaining = 0
    for i = 1, #job.done do
        if not job.done[i] then remaining = remaining + 1 end
    end

    if remaining > 0 then
        return true, ('Done. %d left.'):format(remaining), remaining
    end

    -- Shift complete: take the tool back and pay out.
    reclaimTool(src, cfg.tool)
    active[src] = nil

    local reward = cfg.reward
    if reward and reward.amount and reward.amount > 0 then
        if exports.ox_inventory:CanCarryItem(src, reward.item, reward.amount) then
            exports.ox_inventory:AddItem(src, reward.item, reward.amount)
        else
            lib.print.warn(('[vl_jobs] %s finished %s but could not carry the reward'):format(src, job.job))
        end
    end

    return true, 'Shift complete. Equipment returned.', 0
end)

-- -----------------------------------------------------------------------------
-- Haul loop: pick up a crate, carry it, set it down, repeat
-- -----------------------------------------------------------------------------

lib.callback.register('vl_jobs:server:pickup', function(src)
    local job = active[src]
    if not job or not job.haul then return false, 'You are not on that shift.' end

    local cfg = VLJobs.jobs[job.job]
    if not cfg then return false, 'Unknown job.' end

    if job.carrying then
        return false, 'You are already carrying one.'
    end
    if job.delivered >= job.total then
        return false, 'You have moved them all.'
    end
    if not nearCoords(src, cfg.pickup, (cfg.interactDistance or 2.0) + 2.0) then
        return false, 'You are not at the pallet.'
    end

    job.carrying = true

    -- Cycle the crate model so each trip looks different, chosen server-side so
    -- the client cannot pick one that does not exist.
    local models = cfg.boxModels or {}
    local model = models[(job.delivered % math.max(1, #models)) + 1] or cfg.boxFallback

    return true, ('Crate %d of %d.'):format(job.delivered + 1, job.total), model
end)

lib.callback.register('vl_jobs:server:deliver', function(src)
    local job = active[src]
    if not job or not job.haul then return false, 'You are not on that shift.' end

    local cfg = VLJobs.jobs[job.job]
    if not cfg then return false, 'Unknown job.' end

    if not job.carrying then
        return false, 'You are not carrying anything.'
    end

    -- Must be at ANY of the drop-off points.
    local atDrop = false
    for i = 1, #cfg.dropoffs do
        if nearCoords(src, cfg.dropoffs[i], (cfg.interactDistance or 2.0) + 2.0) then
            atDrop = true
            break
        end
    end
    if not atDrop then
        return false, 'You are not in the storage room.'
    end

    job.carrying = false
    job.delivered = job.delivered + 1

    local remaining = job.total - job.delivered
    if remaining > 0 then
        return true, ('Stacked. %d crate%s left.'):format(remaining, remaining == 1 and '' or 's'), remaining
    end

    active[src] = nil

    local reward = cfg.reward
    if reward and reward.amount and reward.amount > 0 then
        if exports.ox_inventory:CanCarryItem(src, reward.item, reward.amount) then
            exports.ox_inventory:AddItem(src, reward.item, reward.amount)
        else
            lib.print.warn(('[vl_jobs] %s finished %s but could not carry the reward'):format(src, job.job))
        end
    end

    return true, 'All crates moved. Shift complete.', 0
end)

-- -----------------------------------------------------------------------------
-- Abandon / cleanup
-- -----------------------------------------------------------------------------

lib.callback.register('vl_jobs:server:cancel', function(src)
    local job = active[src]
    if not job then return false end

    local cfg = VLJobs.jobs[job.job]
    if cfg then reclaimTool(src, cfg.tool) end
    active[src] = nil
    return true
end)

lib.callback.register('vl_jobs:server:current', function(src)
    local job = active[src]
    if not job then return nil end

    if job.haul then
        -- Dropped mid-carry: the crate is a local prop that died with the
        -- session, so put them back on "go fetch one" rather than stranding
        -- them carrying something invisible.
        job.carrying = false
        return { job = job.job, haul = true, delivered = job.delivered, total = job.total }
    end

    return { job = job.job, points = job.points, done = job.done }
end)

AddEventHandler('playerDropped', function()
    if not VLJobs.clearOnDisconnect then return end
    -- The tool leaves with their inventory; the shift record must not survive
    -- or they could never start another one.
    active[source] = nil
end)
