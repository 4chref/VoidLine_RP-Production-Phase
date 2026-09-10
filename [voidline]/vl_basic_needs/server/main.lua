local awakeSince = {} -- [source] = os.time() when they last had sleep restored / connected

-- ============================================================
-- CONNECT / DISCONNECT
-- ============================================================

AddEventHandler('playerJoining', function()
    -- no-op placeholder, identifier resolved on playerActivated via deferred load
end)

RegisterNetEvent('basic_needs:server:playerReady', function()
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    local data = Database.Load(identifier)
    Needs.Init(src, identifier, data)
    awakeSince[src] = os.time()
    Needs.Sync(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local p = Needs.Get(src)
    if p then
        Database.Save(p.identifier, p.poop, p.sleep, p.pee)
    end
    Needs.Remove(src)
    awakeSince[src] = nil
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for src, p in pairs(Needs.GetAll()) do
        Database.Save(p.identifier, p.poop, p.sleep, p.pee)
    end
end)

-- ============================================================
-- DEATH HANDLING
-- ============================================================

RegisterNetEvent('basic_needs:server:setDead', function(isDead)
    local src = source
    Needs.SetDead(src, isDead)
end)

-- ============================================================
-- SERVER TICK (decay/drain) - runs on interval, not per frame
-- ============================================================

CreateThread(function()
    while true do
        Wait(Config.TickInterval)
        local minutesPassed = Config.TickInterval / 60000

        for src, p in pairs(Needs.GetAll()) do
            if not p.dead and not p.fainted then
                Needs.Add(src, 'sleep', Config.Sleep.drainPerMinute * minutesPassed)
            end
            -- periodically persist
            Database.Save(p.identifier, p.poop, p.sleep, p.pee)
        end
    end
end)

-- ============================================================
-- FOOD / DRINK
-- ============================================================

-- Auto-feed poop/pee whenever a configured item is consumed through
-- ox_inventory, regardless of which resource actually handles that item
-- (qbx_consumables, a custom eating script, etc). This fires once per use
-- with a fixed configured amount, so it works even once hunger/thirst
-- stats themselves are already maxed out.
AddEventHandler('ox_inventory:usedItem', function(invId, itemName)
    local src = tonumber(invId)
    if Config.Debug then
        print(('[basic_needs] ox_inventory:usedItem invId=%s itemName=%s src=%s'):format(tostring(invId), tostring(itemName), tostring(src)))
    end
    if not src or src == 0 then return end

    if Config.Food[itemName] then
        Needs.Add(src, 'poop', Config.Food[itemName])
    elseif Config.Drinks[itemName] then
        Needs.Add(src, 'pee', Config.Drinks[itemName])
    end
end)

RegisterNetEvent('basic_needs:server:addFood', function(amount)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 100 then return end
    Needs.Add(src, 'poop', amount)
end)

RegisterNetEvent('basic_needs:server:addDrink', function(amount)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 100 then return end
    Needs.Add(src, 'pee', amount)
end)

-- ============================================================
-- POOP RELIEF (player presses Config.PoopRelief.key while critical; the
-- emote itself then plays through automatically -- see client/poop.lua)
-- ============================================================

-- VoidLine 2026-08-31: Needs.TriggerPoop used to be auto-called from
-- Needs.Set the instant poop hit 100, no button press at all. Player wants
-- the button back as the trigger, with the animation itself still playing
-- automatically once started (which it always did -- Config.PoopRelief.duration
-- runs unattended either way). Server-validated here rather than trusting
-- the client's "I pressed G" claim outright.
RegisterNetEvent('basic_needs:server:poopReliefRequest', function()
    local src = source
    local p = Needs.Get(src)
    if not p or p.poop < 100 then return end
    Needs.TriggerPoop(src)
end)

RegisterNetEvent('basic_needs:server:poopReliefDone', function()
    local src = source
    Needs.FinishPoop(src)
end)

-- ============================================================
-- TOILETS
-- ============================================================

RegisterNetEvent('basic_needs:server:useToilet', function(kind)
    local src = source
    local p = Needs.Get(src)
    if not p or p.toiletBusy or p.fainted or p.peeLocked or p.dead then return end
    if kind ~= 'pee' and kind ~= 'poop' then return end

    p.toiletBusy = true
    local duration = kind == 'pee' and Config.ToiletSettings.peeDuration or Config.ToiletSettings.poopDuration
    TriggerClientEvent('basic_needs:client:startToilet', src, kind, duration)

    SetTimeout(duration, function()
        local pp = Needs.Get(src)
        if not pp then return end
        pp.toiletBusy = false
        if kind == 'pee' then
            Needs.Set(src, 'pee', pp.pee - Config.ToiletSettings.peeRestore)
        else
            Needs.Set(src, 'poop', pp.poop - Config.ToiletSettings.poopRestore)
        end
        TriggerClientEvent('basic_needs:client:endToilet', src)
    end)
end)

-- ============================================================
-- PEE ANIMATION FINISHED (client tells server when forced-pee anim completes)
-- ============================================================

RegisterNetEvent('basic_needs:server:peeAnimDone', function()
    local src = source
    Needs.FinishPee(src)
end)

-- ============================================================
-- BEDS
-- ============================================================

local bedThreads = {} -- [source] = true while sleeping in bed

RegisterNetEvent('basic_needs:server:useBedStart', function()
    local src = source
    local p = Needs.Get(src)
    if not p or p.bedBusy or p.fainted or p.dead then return end
    p.bedBusy = true
    bedThreads[src] = true

    CreateThread(function()
        while bedThreads[src] do
            Wait(1000)
            local pp = Needs.Get(src)
            if not pp or not bedThreads[src] then break end
            Needs.Set(src, 'sleep', pp.sleep - Config.Sleep.bedRestorePerSecond)
            if pp.sleep <= 0 then
                bedThreads[src] = nil
            end
        end
        local pp = Needs.Get(src)
        if pp then pp.bedBusy = false end
        TriggerClientEvent('basic_needs:client:endBed', src)
    end)
end)

RegisterNetEvent('basic_needs:server:useBedStop', function()
    local src = source
    bedThreads[src] = nil
end)

AddEventHandler('playerDropped', function()
    bedThreads[source] = nil
end)

-- ============================================================
-- DEBUG COMMANDS
-- ============================================================

if Config.Debug then
    -- Config.Debug is the safety switch for these commands (they don't exist
    -- at all unless it's true), so no extra ACE permission is required here.
    RegisterCommand('setpoop', function(src, args)
        Needs.Set(src, 'poop', tonumber(args[1]) or 0)
    end, false)

    RegisterCommand('setsleep', function(src, args)
        Needs.Set(src, 'sleep', tonumber(args[1]) or 0)
    end, false)

    RegisterCommand('setpee', function(src, args)
        Needs.Set(src, 'pee', tonumber(args[1]) or 0)
    end, false)

    RegisterCommand('needs', function(src)
        local p = Needs.Get(src)
        if not p then return end
        print(('[basic_needs] poop=%d sleep=%d pee=%d'):format(p.poop, p.sleep, p.pee))
        TriggerClientEvent('basic_needs:client:notify', src, ('poop=%d sleep=%d pee=%d'):format(p.poop, p.sleep, p.pee), 'inform')
    end, false)
end

-- ============================================================
-- EXPORTS
-- ============================================================

exports('AddFood', function(source, amount)
    Needs.Add(source, 'poop', amount)
end)

exports('AddDrink', function(source, amount)
    Needs.Add(source, 'pee', amount)
end)

exports('GetNeeds', function(source)
    local p = Needs.Get(source)
    if not p then return nil end
    return { poop = p.poop, sleep = p.sleep, pee = p.pee }
end)

exports('GetPoop', function(source)
    local p = Needs.Get(source)
    return p and p.poop or nil
end)

exports('GetSleep', function(source)
    local p = Needs.Get(source)
    return p and p.sleep or nil
end)

exports('GetPee', function(source)
    local p = Needs.Get(source)
    return p and p.pee or nil
end)

exports('SetPoop', function(source, value)
    Needs.Set(source, 'poop', value)
end)

exports('SetSleep', function(source, value)
    Needs.Set(source, 'sleep', value)
end)

exports('SetPee', function(source, value)
    Needs.Set(source, 'pee', value)
end)
