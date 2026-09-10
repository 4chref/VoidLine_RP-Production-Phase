-- ════════════════════════════════════════════════════════════════════════════
--  BLOOD ORANGE  —  dust field
-- ════════════════════════════════════════════════════════════════════════════
--  Real occlusion, done with particles rather than timecycle fog.
--
--  The dust is anchored to the WORLD, not to the player. Emitters sit on a fixed
--  global lattice; the client spawns the cells near the camera and drops them
--  again as they fall out of range, but a cell's position never moves. Walk
--  forward and you walk THROUGH dust that was already there, instead of dragging
--  a ring of clouds around with you.
--
--  Because every cell's position and jitter are derived from its world
--  coordinates alone -- never from the player -- every client computes the exact
--  same field. Two players standing together see the same clouds in the same
--  places. (Particles are always client-rendered in FiveM; there is no such
--  thing as a server-spawned ptfx. A deterministic world field is how you get
--  a server-consistent result.)
--
--  The field only exists while the preset is active, and the preset is driven by
--  the zone weather from /weatherpanel -- so the dust covers exactly the area you
--  set to Blood Orange, and stops at its border.
-- ════════════════════════════════════════════════════════════════════════════

BODust = {}

local cells    = {}      -- "cx_cy" -> { handle = h, x = , y = , z = }
local liveCount = 0
local lastTry  = 0
local chosen   = nil
local failed   = false

-- FiveM renamed this native; older builds only have the ...NextCall spelling.
local useAsset = UseParticleFxAsset or UseParticleFxAssetNextCall

-- VoidLine: mist-leaning effects moved to the front 2026-08-31 (was
-- exp_grd_bzgas_smoke first) -- steam reads as soft ambient mist rather than
-- thick smoke, and both ship in 'core' so nothing extra streams in.
local CANDIDATES = {
    { dict = 'core',              fx = 'ent_amb_steam'          },
    { dict = 'core',              fx = 'ent_amb_smoke_mp_train' },
    { dict = 'core',              fx = 'exp_grd_bzgas_smoke'    },
    { dict = 'core',              fx = 'ent_amb_smoke_foundry'  },
    { dict = 'core',              fx = 'ent_amb_dust_devil'     },
    { dict = 'scr_agencyheistb',  fx = 'scr_env_agency3b_smoke' },
}

local function loadDict(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local deadline = GetGameTimer() + 4000
    while not HasNamedPtfxAssetLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

local function candidateList()
    local list = {}
    if BO.DustDict and BO.DustEffect then
        list[#list + 1] = { dict = BO.DustDict, fx = BO.DustEffect }
    end
    for _, c in ipairs(CANDIDATES) do
        if not (c.dict == BO.DustDict and c.fx == BO.DustEffect) then
            list[#list + 1] = c
        end
    end
    return list
end

-- Deterministic per-cell jitter. Derived only from the cell's integer coords, so
-- it is identical on every client -- a math.random() here would desync the field
-- between players standing in the same spot.
local function cellNoise(cx, cy, salt)
    local n = (cx * 73856093) ~ (cy * 19349663) ~ (salt * 83492791)
    n = n & 0x7FFFFFFF
    return (n % 10000) / 10000.0        -- 0.0 - 1.0
end

local function removeCell(key)
    local c = cells[key]
    if not c then return end
    if c.handle and DoesParticleFxLoopedExist(c.handle) then
        StopParticleFxLooped(c.handle, false)
        RemoveParticleFx(c.handle, false)
    end
    cells[key] = nil
    liveCount = liveCount - 1
end

local function clearAll()
    for key in pairs(cells) do removeCell(key) end
    cells = {}
    liveCount = 0
end

--- Spawn one world-anchored cloud. Returns the handle, or nil.
local function spawnCell(dict, fx, x, y, z, scale, alpha, c)
    local ok, h = pcall(function()
        useAsset(dict)
        -- Looped AT COORD, not on the entity: the cloud stays where the world
        -- put it and the player moves through it.
        return StartParticleFxLoopedAtCoord(
            fx, x, y, z, 0.0, 0.0, 0.0, scale, false, false, false, false
        )
    end)
    if not ok or not h or h == 0 then return nil end
    pcall(SetParticleFxLoopedColour, h, c[1], c[2], c[3], false)
    pcall(SetParticleFxLoopedAlpha, h, alpha)
    return h
end

function BODust.stop()
    clearAll()
end

function BODust.tick()
    if not BO.Dust then
        if liveCount > 0 then clearAll() end
        return
    end
    if not useAsset then return end
    if failed then
        if GetGameTimer() - lastTry < 30000 then return end
        lastTry, failed = GetGameTimer(), false
    end

    local ped = PlayerPedId()
    if BO.DustSkipInteriors and GetInteriorFromEntity(ped) ~= 0 then
        if liveCount > 0 then clearAll() end
        return
    end

    local spacing = math.max(4.0,  tonumber(BO.DustSpacing)     or 16.0)
    local reach   = math.max(spacing, tonumber(BO.DustFieldRadius) or 45.0)
    local maxCells= math.max(4,    math.floor(BO.DustMaxEmitters or 22))
    local scale   = math.max(0.5,  tonumber(BO.DustScale)  or 7.0)
    local alpha   = math.min(1.0, math.max(0.0, tonumber(BO.DustAlpha) or 0.7))
    local height  = tonumber(BO.DustHeight) or 2.0
    local col     = BO.DustColor or { 0.870, 0.530, 0.310 }

    local p  = GetEntityCoords(ped)
    local cx0, cy0 = math.floor(p.x / spacing), math.floor(p.y / spacing)
    local range = math.ceil(reach / spacing)

    -- Which cells should exist right now, nearest first.
    local want = {}
    for i = -range, range do
        for j = -range, range do
            local cx, cy = cx0 + i, cy0 + j
            -- Jitter off the lattice so it never reads as a grid, but
            -- deterministically, so all clients agree.
            local x = (cx + 0.5 + (cellNoise(cx, cy, 1) - 0.5) * 0.7) * spacing
            local y = (cy + 0.5 + (cellNoise(cx, cy, 2) - 0.5) * 0.7) * spacing
            local d = #(vector2(x, y) - vector2(p.x, p.y))
            if d <= reach then
                want[#want + 1] = { key = cx .. '_' .. cy, x = x, y = y, d = d }
            end
        end
    end
    table.sort(want, function(a, b) return a.d < b.d end)

    local keep = {}
    local budget = maxCells

    for _, w in ipairs(want) do
        if budget <= 0 then break end
        budget = budget - 1
        keep[w.key] = true

        local existing = cells[w.key]
        if existing and existing.handle and DoesParticleFxLoopedExist(existing.handle) then
            -- Already alive and anchored. Leave it completely alone -- respawning
            -- a living cloud is what made the dust flicker in and out.
        else
            if existing then removeCell(w.key) end

            local z = p.z
            local okG, gz = GetGroundZFor_3dCoord(w.x, w.y, p.z + 60.0, false)
            if okG then z = gz end
            z = z + height + cellNoise(math.floor(w.x), math.floor(w.y), 3) * 2.0

            local list = chosen and { chosen } or candidateList()
            local handle
            for _, c in ipairs(list) do
                if loadDict(c.dict) then
                    handle = spawnCell(c.dict, c.fx, w.x, w.y, z, scale, alpha, col)
                    if handle then
                        if not chosen then
                            chosen = c
                            BO.DustDict, BO.DustEffect = c.dict, c.fx
                            print(('^2[bloodorange]^7 dust field using %s / %s')
                                :format(c.dict, c.fx))
                        end
                        break
                    end
                end
            end

            if handle then
                cells[w.key] = { handle = handle, x = w.x, y = w.y, z = z }
                liveCount = liveCount + 1
            elseif not chosen and not failed then
                failed, lastTry = true, GetGameTimer()
                print('^3[bloodorange]^7 no particle effect produced handles — '
                    .. 'dust field unavailable. Run /bodustdbg for details.')
                return
            end
        end
    end

    -- Drop cells that fell out of range or over budget.
    for key in pairs(cells) do
        if not keep[key] then removeCell(key) end
    end
end

function BODust.refresh()
    clearAll()
    chosen, failed = nil, false
    BODust.tick()
end

function BODust.count()
    return liveCount
end
