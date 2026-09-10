Needs = {}

local players = {} -- [source] = { identifier, poop, sleep, pee, lastWarn = {poop=0,sleep=0,pee=0}, fainted=false, peeLocked=false, poopLocked=false, toiletBusy=false, bedBusy=false, dead=false }

local function clamp(v)
    -- nil ~= nil is FALSE in Lua, so this didn't actually catch a nil value
    -- (only real NaN, e.g. 0/0) -- `v < 0` below then threw "attempt to
    -- compare nil with number" for any row with a NULL/missing column,
    -- aborting Needs.Init entirely for that player.
    if v == nil or v ~= v then return 0 end
    if v < 0 then return 0 end
    if v > 100 then return 100 end
    return math.floor(v + 0.5)
end

function Needs.Init(source, identifier, data)
    -- VoidLine: this used to also force-trigger a full faint (screen fade to
    -- black, blur overlay, frozen position, 3 minutes long) immediately for
    -- any returning player whose SAVED sleep value was already at/above
    -- critical -- firing the instant they connect, before they've even
    -- properly loaded in. That's a much worse experience than the thing it
    -- was meant to fix (their sleep value silently sitting at/above
    -- critical for one drain tick, ~a few seconds, before naturally
    -- catching up and fainting normally through the existing Needs.Set
    -- path). Removed -- let it resolve on the next tick like normal instead
    -- of forcing it at login.
    players[source] = {
        identifier = identifier,
        poop = data and clamp(data.poop) or 0,
        sleep = data and clamp(data.sleep) or 0,
        pee = data and clamp(data.pee) or 0,
        lastWarn = { poop = 0, sleep = 0, pee = 0 },
        fainted = false,
        peeLocked = false,
        poopLocked = false,
        toiletBusy = false,
        bedBusy = false,
        dead = false
    }
end

function Needs.Remove(source)
    players[source] = nil
end

function Needs.Get(source)
    return players[source]
end

function Needs.GetAll()
    return players
end

local function sync(source)
    local p = players[source]
    if not p then return end
    TriggerClientEvent('basic_needs:client:updateHud', source, {
        poop = p.poop,
        sleep = p.sleep,
        pee = p.pee
    })
end

local function checkWarnings(source, needName)
    local p = players[source]
    if not p then return end
    local value = p[needName]
    local warnings = Config.Warnings[needName]
    if not warnings then return end

    if value < 50 then
        p.lastWarn[needName] = 0
        return
    end

    local thresholds = { 50, 75, 100 }
    for _, t in ipairs(thresholds) do
        if value >= t and p.lastWarn[needName] < t and warnings[t] then
            p.lastWarn[needName] = t
            TriggerClientEvent('basic_needs:client:notify', source, warnings[t], t == 100 and 'error' or 'warning')
        end
    end
end

--- Set a need to an absolute value (server-authoritative, clamped).
function Needs.Set(source, needName, value)
    local p = players[source]
    if not p then return end
    if p[needName] == nil then return end

    local old = p[needName]
    p[needName] = clamp(value)
    checkWarnings(source, needName)
    sync(source)

    if needName == 'poop' then
        if old < 100 and p[needName] >= 100 then
            TriggerClientEvent('basic_needs:client:setPoopEffect', source, true)
        elseif old >= 100 and p[needName] < 100 then
            TriggerClientEvent('basic_needs:client:setPoopEffect', source, false)
        end
    elseif needName == 'sleep' then
        if p[needName] >= Config.Sleep.criticalThreshold and not p.fainted and not p.dead then
            Needs.TriggerFaint(source)
        end
    elseif needName == 'pee' then
        if p[needName] >= 100 and not p.peeLocked and not p.dead then
            Needs.TriggerPee(source)
        end
    end
end

--- Add an amount to a need.
function Needs.Add(source, needName, amount)
    local p = players[source]
    if not p then return end
    Needs.Set(source, needName, p[needName] + amount)
end

function Needs.TriggerFaint(source)
    local p = players[source]
    if not p or p.fainted or p.dead then return end
    p.fainted = true
    TriggerClientEvent('basic_needs:client:startFaint', source, Config.Sleep.faintDuration)

    SetTimeout(Config.Sleep.faintDuration, function()
        local pp = players[source]
        if not pp then return end
        pp.fainted = false
        pp.sleep = clamp(Config.Sleep.wakeUpValue)
        pp.lastWarn.sleep = 0
        TriggerClientEvent('basic_needs:client:endFaint', source)
        sync(source)
    end)
end

function Needs.TriggerPee(source)
    local p = players[source]
    if not p or p.peeLocked or p.dead or p.fainted then return end
    p.peeLocked = true
    TriggerClientEvent('basic_needs:client:startPee', source)
end

function Needs.FinishPee(source)
    local p = players[source]
    if not p then return end
    p.peeLocked = false
    p.pee = 0
    p.lastWarn.pee = 0
    sync(source)
end

function Needs.TriggerPoop(source)
    local p = players[source]
    if not p or p.poopLocked or p.dead or p.fainted then return end
    p.poopLocked = true
    TriggerClientEvent('basic_needs:client:startPoop', source)
end

function Needs.FinishPoop(source)
    local p = players[source]
    if not p then return end
    p.poopLocked = false
    p.poop = 0
    p.lastWarn.poop = 0
    sync(source)
    -- VoidLine: this sets p.poop directly rather than going through
    -- Needs.Set, so the crossing-back-under-100 branch there (the only place
    -- that fires setPoopEffect(false) to clear the desperate walk clipset)
    -- never ran -- poop reset correctly but the walk animation stayed stuck
    -- on forever. Fire it explicitly here too.
    TriggerClientEvent('basic_needs:client:setPoopEffect', source, false)
end

function Needs.SetDead(source, isDead)
    local p = players[source]
    if not p then return end
    p.dead = isDead
    if isDead then
        p.fainted = false
        p.peeLocked = false
        p.poopLocked = false
    end
end

Needs.Sync = sync
Needs.Clamp = clamp
