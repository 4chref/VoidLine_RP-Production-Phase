local inFlow = false

-- Creator sections: physical appearance only. Clothing (components) and
-- accessories (props) are hard-disabled; tattoos and ped-model swapping too.
local creatorConfig = {
    ped = false,
    headBlend = true,
    faceFeatures = true,
    headOverlays = true,
    components = false,
    componentConfig = {
        masks = false, upperBody = false, lowerBody = false, bags = false,
        shoes = false, scarfAndChains = false, bodyArmor = false,
        shirts = false, decals = false, jackets = false,
    },
    props = false,
    propConfig = { hats = false, glasses = false, ear = false, watches = false, bracelets = false },
    tattoos = false,
    enableExit = false,
    hasTracker = false,
    automaticFade = false,
}

-- =========================================================================
-- Helpers
-- =========================================================================

---Strip every clothing component and prop, leaving the bare freemode body.
---@param sex integer 0 = male, 1 = female
--- Strip the ped to the configured bare state, THROUGH illenium-appearance.
---
--- This used to call SetPedComponentVariation and ClearAllPedProps directly,
--- which is what produced the split view: you saw yourself stripped (the
--- natives had run on your own client) while everyone else saw you clothed,
--- because illenium owns the appearance other clients are given and it had
--- never been told. The same trap is documented in vl_clothing/client.lua --
--- "going around it means the next appearance refresh silently undoes whatever
--- we set" -- and the refresh here is every other player scoping you in.
---
--- Saving is the half that actually fixes the desync. Setting components via
--- illenium updates the local ped; persisting the result is what makes the
--- stripped appearance the one the server hands out.
---
--- Props are cleared with drawable -1 rather than ClearAllPedProps: illenium
--- special-cases -1 as "clear" (game/util.lua:314), so this goes through the
--- same path and stays in its model of the ped. Only the five prop ids GTA
--- actually uses are touched (its PED_PROPS_IDS is {0,1,2,6,7}).
---@param sex integer 0 = male, 1 = female
local function enforceNaked(sex)
    local ped = PlayerPedId()
    local set = sex == 1 and VLConfig.NakedAppearance.female or VLConfig.NakedAppearance.male

    for i = 1, #set.components do
        local c = set.components[i]
        exports['illenium-appearance']:setPedComponent(ped, {
            component_id = c.component_id,
            drawable = c.drawable,
            texture = c.texture,
        })
    end

    for _, propId in ipairs({ 0, 1, 2, 6, 7 }) do
        exports['illenium-appearance']:setPedProp(ped, { prop_id = propId, drawable = -1, texture = 0 })
    end

    local appearance = exports['illenium-appearance']:getPedAppearance(ped)

    if appearance then
        TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
    end
end

---@param sex integer 0 = male, 1 = female
local function setupCreationPed(sex)
    local set = sex == 1 and VLConfig.NakedAppearance.female or VLConfig.NakedAppearance.male
    local model = joaat(set.model)
    lib.requestModel(model, 30000)
    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
    ClearPedDecorations(ped)
    enforceNaked(sex)
end

--- Force the player back to a living, controllable state.
---
--- SetPlayerModel DESTROYS the old ped and builds a new one. The game reports
--- that as a networked entity death, and qbx_medical listens for exactly that:
--- client/dead.lua:118 handles CEventNetworkEntityDamage and, if the player is
--- logged in and currently ALIVE, calls StartLastStand(). Last stand sets the
--- death state and calls DisableControls() -- which is precisely "spawned dead
--- and cannot move".
---
--- The old flow happened to survive this because the identity reveal blocked
--- here for several seconds with NUI focus while the appearance creator's
--- routing-bucket swap rebuilt the ped. That was never a fix, only a mask, and
--- removing the reveal exposed it. Depending on how long a screen stays up for
--- game state to settle is the actual bug; this asserts the state instead.
---
--- ORDERING NOTE: NetworkResurrectLocalPlayer can reset the ped's components
--- to the model defaults, so every call to this must be FOLLOWED by an
--- enforceNaked() before anything observes or captures the ped. Both call sites
--- in createNewCharacter already are -- keep it that way if you move them.
---
--- Cheap when nothing is wrong: two native reads and an early return.
local function ensureAlive()
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
    end

    -- Clear qbx_medical's own state even when the ped itself reads as alive:
    -- last stand resurrects the ped and keeps it at full health, so the ped is
    -- NOT a reliable signal -- the state bag is.
    if LocalPlayer.state.isDead == true then
        -- The revive path qbx_medical uses itself (client/main.lua:213). It
        -- resurrects, sets DeathState back to ALIVE, re-enables sprint and
        -- clears injuries, so nothing is left half-cleared.
        TriggerEvent('qbx_medical:client:playerRevived')
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    SetEntityInvincible(ped, false)
end

---Place the player in the world and fire the standard Qbox load events.
---@param pos {x: number, y: number, z: number, heading: number?}
local function spawnAt(pos)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.heading or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    DisplayRadar(true)

    -- Standard Qbox load events: qbx_core ends the tutorial session, ox_inventory,
    -- illenium-appearance, hud etc. all hook these.
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    Wait(500)
    DoScreenFadeIn(1000)
end

-- =========================================================================
-- Character creation -- NUI screens
--
-- Both creation screens are our own NUI (web/) rather than ox_lib dialogs, so
-- the whole intake reads in the server's gold-on-black styling. Each one hands
-- control back through a promise resolved by its NUI callback, which keeps the
-- calling code sequential the way lib.inputDialog was.
-- =========================================================================

local intakePromise ---@type promise?

RegisterNUICallback('intakeSubmit', function(data, cb)
    cb('ok')
    local p = intakePromise
    if not p then return end
    intakePromise = nil
    p:resolve({
        sex = data.sex == 'female' and 1 or 0,
        height = math.floor(tonumber(data.height) or VLConfig.Height.default),
    })
end)

---@return integer sex, integer height
local function characterDialog()
    local p = promise.new()
    intakePromise = p

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openIntake',
        heightMin = VLConfig.Height.min,
        heightMax = VLConfig.Height.max,
        heightDefault = VLConfig.Height.default,
        text = VLConfig.IntakeText,
    })

    local result = Citizen.Await(p)
    SetNuiFocus(false, false)

    local height = math.max(VLConfig.Height.min, math.min(VLConfig.Height.max, result.height))
    return result.sex, height
end

---Passive arrival card. Does NOT take NUI focus and does NOT block: the player
---is already spawned and in control, and this plays over the top of that.
---
---@param id string|integer identity number -- becomes the headline
local function showArrival(id)
    local text = VLConfig.ArrivalText or {}
    local cfg = VLConfig.Arrival or {}

    SendNUIMessage({
        action   = 'showArrival',
        eyebrow  = text.eyebrow,
        -- The identity number IS the headline now. The separate blocking
        -- reveal screen that used to announce it is gone -- this says the same
        -- thing over live gameplay instead of stopping the flow for it.
        title    = tostring(id),
        desc     = text.desc,
        lines    = text.lines,
        duration = cfg.duration,
        fade     = cfg.fade,
        sound    = cfg.sound or nil,
        volume   = cfg.volume,
    })
end

local function runAppearanceCreator()
    TriggerServerEvent('illenium-appearance:server:ChangeRoutingBucket')

    local p = promise.new()
    exports['illenium-appearance']:startPlayerCustomization(function(appearance)
        if appearance then
            TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
        end
        p:resolve(appearance ~= nil)
    end, creatorConfig)
    Citizen.Await(p)

    TriggerServerEvent('illenium-appearance:server:ResetRoutingBucket')
end

local startFlow, loadExistingCharacter -- forward declarations

local function createNewCharacter()
    -- Park the (invisible) player at the first spawn point while creating; the
    -- appearance resource moves them to an isolated routing bucket meanwhile.
    local creationPos = VLConfig.SpawnPoints[1]
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, creationPos.x, creationPos.y, creationPos.z, false, false, false, false)
    SetEntityVisible(ped, false, false)

    Wait(1000)
    DoScreenFadeIn(500)

    local sex, height = characterDialog()

    local result = lib.callback.await('vl_identity:server:createCharacter', false, { sex = sex, height = height })
    if not result then
        lib.notify({ title = 'Character Creation', description = 'Something went wrong, retrying...', type = 'error' })
        Wait(2000)
        inFlow = false -- release the guard so the flow can restart
        return startFlow()
    end
    if result.exists then
        -- Account already has a character (e.g. double-join race): load it instead
        return loadExistingCharacter()
    end

    setupCreationPed(sex)

    -- Immediately after the model swap, before anything else can observe a
    -- dead player. See ensureAlive() for what the swap does to qbx_medical.
    ensureAlive()

    local newPed = PlayerPedId()
    FreezeEntityPosition(newPed, true)
    SetEntityCoords(newPed, creationPos.x, creationPos.y, creationPos.z, false, false, false, false)
    SetEntityVisible(newPed, true, false)

    runAppearanceCreator()

    -- The creator never offers clothing, but enforce a fully stripped ped anyway
    enforceNaked(sex)
    Wait(200)

    local mugshot = exports.MugShotBase64:GetMugShotBase64(PlayerPedId(), true) or ''
    local spawn = lib.callback.await('vl_identity:server:finishCreation', false, mugshot)
        or lib.callback.await('vl_identity:server:getSpawn', false)

    -- Again before the spawn: the appearance creator changes the ped model too
    -- (illenium rebuilds it on sex/model change), so it can re-trigger the same
    -- last-stand path after the first call already cleared it.
    ensureAlive()

    spawnAt(spawn)
    enforceNaked(sex)

    -- After spawnAt, not before: the card sits over the world the player has
    -- just landed in, and firing it while the screen was still faded out for
    -- the teleport would spend the whole animation behind a black screen.
    showArrival(result.id)

    lib.notify({
        title = 'ID Card',
        description = ('You received your ID card. Identity number: %s'):format(result.id),
        type = 'success',
        duration = 8000,
    })
end

function loadExistingCharacter()
    local result = lib.callback.await('vl_identity:server:loadCharacter', false)
    if not result then
        -- Row disappeared between checks; fall back to creation
        return createNewCharacter()
    end

    local pos = result.position
    if not pos or (pos.x == 0.0 and pos.y == 0.0) then
        pos = lib.callback.await('vl_identity:server:getSpawn', false)
    end

    spawnAt(pos)
end

function startFlow()
    if inFlow then return end
    inFlow = true

    DoScreenFadeOut(0)
    DisplayRadar(false)

    local function waitUntil(predicate, timeoutMs, interval)
        local deadline = GetGameTimer() + timeoutMs
        while not predicate() and GetGameTimer() < deadline do
            Wait(interval or 0)
        end
    end

    waitUntil(IsScreenFadedOut, 2000)

    -- Get the player out of the shared world before the screen comes down.
    NetworkStartSoloTutorialSession()
    waitUntil(NetworkIsInTutorialSession, 5000)

    -- Only now tear the loading screen down. NetworkIsSessionStarted() -- the
    -- trigger for this flow -- goes true while the engine is still streaming
    -- the world, so waiting for collision around the ped before dropping the
    -- screen is what stops the player being shown an unbuilt world. The
    -- timeout keeps a bad stream from wedging the flow entirely.
    --
    -- This is NOT what causes the "Loading game (x%)" card in the corner. That
    -- was the theory when this wait was written and it was wrong: a probe trace
    -- through this whole function showed it reaching the end in under three
    -- seconds with collision loaded, and the card still sitting there. It is
    -- the game's busy spinner, a separate overlay these two natives do not
    -- touch -- see vl_loadingscreen/client/failsafe.lua, which clears it.
    -- The collision wait stays because it is correct on its own merits.
    waitUntil(function() return HasCollisionLoadedAroundEntity(PlayerPedId()) end, 30000, 100)
    Wait(1000)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- Keep the player safe until they are fully in the world
    CreateThread(function()
        while inFlow do
            SetEntityInvincible(PlayerPedId(), true)
            Wait(250)
        end
        SetEntityInvincible(PlayerPedId(), false)
    end)

    local character = lib.callback.await('vl_identity:server:getCharacter', false)
    if character then
        loadExistingCharacter()
    else
        createNewCharacter()
    end

    inFlow = false
end

CreateThread(function()
    while true do
        -- 100ms, not 0. This polls a flag that flips exactly once, several
        -- seconds into the join, and then the thread breaks out for good. At
        -- Wait(0) it burned a frame every frame from resource start until the
        -- session came up -- on a slow load that is thousands of wasted ticks
        -- during the single busiest moment of the client's life, which is
        -- precisely when the frame budget is worth protecting. A tenth of a
        -- second of extra latency on a flow that then waits on collision and a
        -- server callback is not measurable.
        Wait(100)
        if NetworkIsSessionStarted() then
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(250)
            startFlow()
            break
        end
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end -- server-triggered only
    startFlow()
end)

-- =========================================================================
-- ID card
-- =========================================================================

lib.callback.register('vl_identity:client:getMugshot', function()
    return exports.MugShotBase64:GetMugShotBase64(PlayerPedId(), true)
end)

---@param card {id: string, sex: string, photo: string}
---@param isOwn boolean
RegisterNetEvent('vl_identity:client:showCard', function(card, isOwn)
    SendNUIMessage({
        action = 'showCard',
        card = { id = card.id, sex = card.sex, photo = card.photo },
        duration = VLConfig.CardDisplayMs,
    })
    if not isOwn then
        lib.notify({ title = 'ID Card', description = 'Someone is showing you their ID card', type = 'inform' })
    end
end)

-- Never leave a player stuck with a cursor and no game input if the resource is
-- stopped or restarted while an intake screen is open.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

-- Inventory tooltip labels for the card metadata
CreateThread(function()
    exports.ox_inventory:displayMetadata({
        vl_id = 'ID',
        vl_sex = 'Sex',
    })
end)

-- =========================================================================
-- Pill
-- =========================================================================
-- Replays the intake identity reveal and puts the character back on the exact
-- spawn point they first stood on.
--
-- Lives in vl_identity rather than its own resource because both halves are
-- private to this file: showArrival owns the splash NUI and spawnAt owns the
-- fade + the Qbox load events that other resources hook. Reimplementing either
-- elsewhere would duplicate the flow and drift out of sync with it.

--- Entry point for ox_inventory. Referenced from the item's `client.export`, so
--- ox calls it with (data, slotInfo). The slot is forwarded only so the exact
--- pill that was clicked gets consumed rather than an arbitrary one; the server
--- re-checks that the slot really holds a pill before trusting it.
exports('usePill', function(_, slotInfo)
    TriggerServerEvent('vl_identity:server:usePill', type(slotInfo) == 'table' and slotInfo.slot or nil)
end)

---@param id string|integer identity number
---@param spawn {x: number, y: number, z: number, heading: number}
RegisterNetEvent('vl_identity:client:pillEffect', function(id, spawn)
    -- The pill is used from the AVP grid, and ox's `close = true` only closes
    -- ox's own UI -- AVP's would stay open underneath the reveal, both holding
    -- NUI focus. PLAYER_SEND_NUI_MESSAGE is how AVP's server talks to its NUI;
    -- triggering it locally drives the same path its own close button uses.
    if GetResourceState('avp_grid_inventory') == 'started' then
        TriggerEvent('PLAYER_SEND_NUI_MESSAGE', { event = 'SET_INTERFACE_OPEN', state = false })
        Wait(150)
    end

    -- Teleport FIRST, then the splash -- the same order character creation
    -- uses. The old blocking reveal ran before the teleport deliberately, to
    -- hide it; the splash is passive and plays over live gameplay, so running
    -- it first would just mean spawnAt's screen fade wiping it mid-animation.
    if type(spawn) == 'table' and type(spawn.x) == 'number' then
        spawnAt(spawn)
    end

    showArrival(id)
end)
