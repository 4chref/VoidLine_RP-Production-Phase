local pendingCards = {} ---@type table<number, boolean> sources that finished creation but haven't been issued a card yet
local reservations = {} ---@type table<integer, {src: number, expires: number}> spawn point index -> reservation

-- =========================================================================
-- Database setup
-- =========================================================================

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await('ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `voidline_id` INT UNSIGNED NULL DEFAULT NULL')
        MySQL.query.await('ALTER TABLE `players` ADD UNIQUE INDEX IF NOT EXISTS `voidline_id` (`voidline_id`)')
    end)
    if not ok then
        lib.print.error('[vl_identity] Could not auto-create the voidline_id column. Run install.sql manually. Error:', err)
    end
end)

-- =========================================================================
-- Helpers
-- =========================================================================

---@param source number
---@return string? license2
---@return string? license
local function getLicenses(source)
    return GetPlayerIdentifierByType(source --[[@as string]], 'license2'),
        GetPlayerIdentifierByType(source --[[@as string]], 'license')
end

---Fetch this account's single character row, if any.
---@param source number
---@return table? row
local function fetchCharacterRow(source)
    local license2, license = getLicenses(source)
    if not license2 and not license then return end
    return MySQL.single.await(
        'SELECT `citizenid`, `charinfo`, `position`, `voidline_id` FROM `players` WHERE `license` = ? OR `license` = ? ORDER BY `id` ASC LIMIT 1',
        { license2 or license, license or license2 }
    )
end

---Generate a unique identity number between VLConfig.IdMin and VLConfig.IdMax.
---@return integer?
local function generateUniqueId()
    local used = MySQL.query.await('SELECT `voidline_id` FROM `players` WHERE `voidline_id` IS NOT NULL') or {}
    local taken = {}
    for i = 1, #used do
        taken[used[i].voidline_id] = true
    end

    local free = {}
    for id = VLConfig.IdMin, VLConfig.IdMax do
        if not taken[id] then
            free[#free + 1] = id
        end
    end

    if #free == 0 then
        lib.print.error('[vl_identity] All identity numbers between', VLConfig.IdMin, 'and', VLConfig.IdMax, 'are taken!')
        return
    end

    return free[math.random(1, #free)]
end

---Persist the identity number on the player's row, retrying on the (very
---unlikely) unique-constraint race between two simultaneous creations.
---@param citizenid string
---@param vlid integer
---@return integer? storedId
local function storeIdentityNumber(citizenid, vlid)
    for _ = 1, 5 do
        -- The row is written by qbx_core's Save inside Login; wait for it briefly.
        for _ = 1, 20 do
            local exists = MySQL.scalar.await('SELECT 1 FROM `players` WHERE `citizenid` = ?', { citizenid })
            if exists then break end
            Wait(100)
        end

        local ok = pcall(MySQL.update.await,
            'UPDATE `players` SET `voidline_id` = ? WHERE `citizenid` = ? AND `voidline_id` IS NULL',
            { vlid, citizenid })
        if ok then
            local stored = MySQL.scalar.await('SELECT `voidline_id` FROM `players` WHERE `citizenid` = ?', { citizenid })
            if stored then return stored end
        end

        vlid = generateUniqueId()
        if not vlid then return end
    end
end

---@param source number
---@return integer? vlid
local function getIdentityNumber(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local citizenid = player.PlayerData.citizenid
    local vlid = MySQL.scalar.await('SELECT `voidline_id` FROM `players` WHERE `citizenid` = ?', { citizenid })
    if not vlid then
        -- Self-heal characters that were somehow created without a number
        vlid = generateUniqueId()
        if vlid then
            vlid = storeIdentityNumber(citizenid, vlid)
        end
    end
    return vlid
end

-- =========================================================================
-- Spawn allocation
-- =========================================================================

local spawnCentroid do
    local x, y = 0.0, 0.0
    for i = 1, #VLConfig.SpawnPoints do
        x += VLConfig.SpawnPoints[i].x
        y += VLConfig.SpawnPoints[i].y
    end
    spawnCentroid = vec2(x / #VLConfig.SpawnPoints, y / #VLConfig.SpawnPoints)
end

---Heading (GTA convention: 0 = north, counter-clockwise) from a point toward the spawn area's center
---@param point vector3
---@return number
local function headingTowardsCenter(point)
    local dx, dy = spawnCentroid.x - point.x, spawnCentroid.y - point.y
    return math.deg(math.atan(-dx, dy)) % 360 -- two-arg atan (Lua 5.4)
end

---Number of player peds within radius of a point, excluding one source
---@param point vector3
---@param excludeSrc number
---@return integer
local function playersNearPoint(point, excludeSrc)
    local count = 0
    local players = GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i])
        if src ~= excludeSrc then
            local ped = GetPlayerPed(players[i])
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx, dy = coords.x - point.x, coords.y - point.y
                if math.sqrt(dx * dx + dy * dy) <= VLConfig.SpawnOccupiedRadius then
                    count += 1
                end
            end
        end
    end
    return count
end

---@param index integer
---@param requestingSrc number
---@return boolean
local function isReserved(index, requestingSrc)
    local res = reservations[index]
    if not res then return false end
    if res.src == requestingSrc then return false end
    if os.time() > res.expires or not GetPlayerName(tostring(res.src)) then
        reservations[index] = nil
        return false
    end
    return true
end

---Allocate a spawn position for a player. Server-authoritative: reservations
---prevent two simultaneous joiners from getting the same point, and physical
---occupancy is checked so points free up as players walk away or disconnect.
---@param source number
---@return {x: number, y: number, z: number, heading: number, fallback: boolean}
local function allocateSpawn(source)
    -- Drop any previous reservation held by this player
    for idx, res in pairs(reservations) do
        if res.src == source then reservations[idx] = nil end
    end

    local bestIdx, bestCount
    for i = 1, #VLConfig.SpawnPoints do
        local point = VLConfig.SpawnPoints[i]
        if not isReserved(i, source) then
            local nearby = playersNearPoint(point, source)
            if nearby == 0 then
                reservations[i] = { src = source, expires = os.time() + VLConfig.SpawnReservationSeconds }
                return {
                    x = point.x, y = point.y, z = point.z,
                    heading = headingTowardsCenter(point),
                    fallback = false,
                }
            end
            if not bestCount or nearby < bestCount then
                bestIdx, bestCount = i, nearby
            end
        end
    end

    -- Fallback: every point is occupied/reserved. Use the least crowded point
    -- with a small random offset so players never stack exactly on top of each other.
    local point = VLConfig.SpawnPoints[bestIdx or math.random(1, #VLConfig.SpawnPoints)]
    local angle = math.rad(math.random(0, 359))
    local dist = 1.0 + math.random() * (VLConfig.SpawnFallbackOffset - 1.0)
    return {
        x = point.x + math.cos(angle) * dist,
        y = point.y + math.sin(angle) * dist,
        z = point.z,
        heading = headingTowardsCenter(point),
        fallback = true,
    }
end

AddEventHandler('playerDropped', function()
    local src = source
    pendingCards[src] = nil
    for idx, res in pairs(reservations) do
        if res.src == src then reservations[idx] = nil end
    end
end)

-- =========================================================================
-- ID card
-- =========================================================================

---@param source number
---@param mugshot string base64 image
---@return table? metadata
local function buildCardMetadata(source, mugshot)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local vlid = getIdentityNumber(source)
    if not vlid then return end
    local sex = player.PlayerData.charinfo.gender == 1 and 'Female' or 'Male'
    return {
        vl_id = tostring(vlid),
        vl_sex = sex,
        mugShot = mugshot,
        description = ('ID: %s | Sex: %s'):format(vlid, sex),
    }
end

---@param mugshot any
---@return boolean
local function isValidMugshot(mugshot)
    return type(mugshot) == 'string' and #mugshot > 100 and #mugshot < 800000
end

---Give the player their ID card item (waits for the inventory to be ready).
---@param source number
---@param mugshot string
---@return boolean
local function giveIdCard(source, mugshot)
    local deadline = GetGameTimer() + 10000
    while not exports.ox_inventory:GetInventory(source) do
        if GetGameTimer() > deadline then return false end
        Wait(100)
    end

    local metadata = buildCardMetadata(source, mugshot)
    if not metadata then return false end

    -- One card per character: never stack duplicates on top of an existing one
    local existing = exports.ox_inventory:Search(source, 'count', 'id_card')
    if existing and existing > 0 then return true end

    return exports.ox_inventory:AddItem(source, 'id_card', 1, metadata) and true or false
end

---Show a card to its owner and, when someone is close enough, to the nearest player
---@param source number
---@param metadata table
local function displayCard(source, metadata)
    local card = { id = metadata.vl_id, sex = metadata.vl_sex, photo = metadata.mugShot }
    TriggerClientEvent('vl_identity:client:showCard', source, card, true)

    local ownCoords = GetEntityCoords(GetPlayerPed(source))
    local closest, closestDist
    local players = GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i])
        if src ~= source then
            local coords = GetEntityCoords(GetPlayerPed(players[i]))
            local dist = #(coords - ownCoords)
            if dist <= VLConfig.CardShowDistance and (not closestDist or dist < closestDist) then
                closest, closestDist = src, dist
            end
        end
    end
    if closest then
        TriggerClientEvent('vl_identity:client:showCard', closest, card, false)
    end
end

exports.qbx_core:CreateUseableItem('id_card', function(source, item)
    local metadata = item.metadata or item.info or {}

    if not metadata.vl_id or not metadata.mugShot or metadata.mugShot == '' then
        -- Card handed out without data (e.g. via admin give): fill it in now
        local mugshot = lib.callback.await('vl_identity:client:getMugshot', source)
        if not isValidMugshot(mugshot) then return end
        local newMetadata = buildCardMetadata(source, mugshot)
        if not newMetadata or not item.slot then return end
        exports.ox_inventory:SetMetadata(source, item.slot, newMetadata)
        metadata = newMetadata
    end

    displayCard(source, metadata)
end)

-- =========================================================================
-- Character flow callbacks
-- =========================================================================

lib.callback.register('vl_identity:server:getCharacter', function(source)
    local row = fetchCharacterRow(source)
    return row and { citizenid = row.citizenid } or nil
end)

lib.callback.register('vl_identity:server:createCharacter', function(source, data)
    if type(data) ~= 'table' then return end
    if fetchCharacterRow(source) then return { exists = true } end

    local sex = data.sex == 1 and 1 or 0
    local height = math.floor(tonumber(data.height) or VLConfig.Height.default)
    height = math.max(VLConfig.Height.min, math.min(VLConfig.Height.max, height))

    local vlid = generateUniqueId()
    if not vlid then return end

    local newData = {
        charinfo = {
            firstname = 'Citizen',
            lastname = tostring(vlid),
            nationality = 'None',
            birthdate = '2000-01-01',
            gender = sex,
            backstory = 'VoidLine citizen',
            cid = 1,
        },
        metadata = {
            height = height,
        },
    }

    local success = exports.qbx_core:Login(source, nil, newData)
    if not success then return end

    local player = exports.qbx_core:GetPlayer(source)
    local storedId = storeIdentityNumber(player.PlayerData.citizenid, vlid)
    if not storedId then
        lib.print.error('[vl_identity] Failed to store identity number for', player.PlayerData.citizenid)
        return
    end

    -- Keep the visible character name in sync if a race forced a different number
    if storedId ~= vlid then
        player.PlayerData.charinfo.lastname = tostring(storedId)
        player.Functions.Save()
    end

    pendingCards[source] = true
    lib.print.info(('[vl_identity] %s created character %s with identity number %s')
        :format(GetPlayerName(source), player.PlayerData.citizenid, storedId))

    return { id = storedId, sex = sex, height = height }
end)

lib.callback.register('vl_identity:server:loadCharacter', function(source)
    local row = fetchCharacterRow(source)
    if not row then return end

    local success = exports.qbx_core:Login(source, row.citizenid)
    if not success then return end

    -- Self-heal: characters predating this system get a number on first load
    local vlid = getIdentityNumber(source)

    local player = exports.qbx_core:GetPlayer(source)
    local pos = player.PlayerData.position
    local position = pos and { x = pos.x, y = pos.y, z = pos.z, heading = pos.w or 0.0 } or nil

    lib.print.info(('[vl_identity] %s loaded character %s (identity %s)')
        :format(GetPlayerName(source), row.citizenid, vlid or '?'))

    return { id = vlid, position = position }
end)

lib.callback.register('vl_identity:server:finishCreation', function(source, mugshot)
    if not pendingCards[source] then return end
    if not exports.qbx_core:GetPlayer(source) then return end
    if not isValidMugshot(mugshot) then
        lib.print.warn('[vl_identity] Invalid mugshot from', source, '- issuing card without photo refresh')
        mugshot = ''
    end

    pendingCards[source] = nil

    -- Always issue the card; a missing photo is regenerated on first use
    if not giveIdCard(source, mugshot) then
        lib.print.error('[vl_identity] Failed to give ID card to', source)
    end

    -- Starter kit (giveIdCard already waited for the inventory to be ready)
    for i = 1, #VLConfig.StarterItems do
        local item = VLConfig.StarterItems[i]
        if not exports.ox_inventory:AddItem(source, item.name, item.amount) then
            lib.print.error('[vl_identity] Failed to give starter item', item.name, 'to', source)
        end
    end

    -- Remember where this character first stood. allocateSpawn picks whichever
    -- point happens to be free, so without recording it the "original" spawn is
    -- not recoverable afterwards -- nothing else persists it.
    local spawn = allocateSpawn(source)

    local player = exports.qbx_core:GetPlayer(source)
    if player and spawn then
        player.Functions.SetMetaData('vl_originspawn', {
            x = spawn.x, y = spawn.y, z = spawn.z, heading = spawn.heading,
        })
    end

    return spawn
end)

-- Spawn allocation for players whose saved position is missing/invalid
lib.callback.register('vl_identity:server:getSpawn', function(source)
    if not exports.qbx_core:GetPlayer(source) then return end
    return allocateSpawn(source)
end)

-- =========================================================================
-- Pill: re-show the identity reveal and return to the character's first spawn
-- =========================================================================

---@param slot number|nil the slot the client says was used; verified before use
RegisterNetEvent('vl_identity:server:usePill', function(slot)
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    -- The slot comes from the client, so confirm it actually holds a pill
    -- before removing anything from it. A bad or stale slot just falls back to
    -- "remove any one pill", which RemoveItem resolves itself.
    if type(slot) == 'number' then
        local slotData = exports.ox_inventory:GetSlot(source, slot)
        if not slotData or slotData.name ~= 'pill' then slot = nil end
    else
        slot = nil
    end

    -- Consumed here rather than by ox. An item whose behaviour is a client
    -- export is dispatched with `return data.export(...)` in ox_inventory's
    -- useSlot, before it ever reaches the consume path -- so ox would never
    -- take it. Removing it FIRST, and bailing if that fails, is what makes the
    -- pill single-use: no pill, no effect, and firing this event by hand does
    -- nothing.
    if not exports.ox_inventory:RemoveItem(source, 'pill', 1, nil, slot) then
        lib.print.warn('[vl_identity] Pill use by', source, 'ignored - could not remove the item')
        return
    end

    local origin = player.PlayerData.metadata.vl_originspawn

    -- Characters created before the spawn was recorded have nothing stored, so
    -- fall back to a freshly allocated point -- same spawn area, just not
    -- guaranteed to be the exact one they started on.
    if type(origin) ~= 'table' or type(origin.x) ~= 'number' then
        origin = allocateSpawn(source)
    end

    TriggerClientEvent('vl_identity:client:pillEffect', source, getIdentityNumber(source) or '????', origin)
end)
