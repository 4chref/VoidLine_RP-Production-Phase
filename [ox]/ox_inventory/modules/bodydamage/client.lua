-- =============================================================================
-- ox_inventory / modules/bodydamage/client.lua
--
-- VoidLine addition. Feeds the character panel's body-damage indicators, which
-- replaced the AVP clothing slots (see web-avp/src/views/Clothes.vue).
--
-- Injuries live in qbx_medical, which writes one player statebag per body part:
--   LocalPlayer.state['qbx_medical:injuries:HEAD'] = { severity = 1..4, ... }
-- The bag is absent (nil) while that part is unhurt. Severity is capped at 4 by
-- qbx_medical's own upgradeInjury(), so 4 is 100%.
--
-- qbx_medical tracks fifteen parts, which is far more granular than the five
-- indicators the panel shows, so they are grouped below and each group reports
-- its WORST member. Worst rather than average deliberately: a shattered hand
-- reading "33% arm" because the forearm and fingers are fine would understate
-- the injury the player actually needs to act on.
-- =============================================================================

local PREFIX = 'qbx_medical:injuries:'
local MAX_SEVERITY = 4

-- Panel indicator -> the qbx_medical parts it covers.
local GROUPS = {
    head  = { 'HEAD', 'NECK' },
    body  = { 'SPINE', 'UPPER_BODY', 'LOWER_BODY' },
    larm  = { 'LARM', 'LHAND', 'LFINGER' },
    rarm  = { 'RARM', 'RHAND', 'RFINGER' },
    legs  = { 'LLEG', 'LFOOT', 'RLEG', 'RFOOT' },
}

-- Flat cache of every part's severity, kept current by the statebag handlers so
-- a rebuild never has to read fifteen bags back out.
local severities = {}

local function buildPayload()
    local out = {}

    for group, parts in pairs(GROUPS) do
        local worst = 0
        for i = 1, #parts do
            local s = severities[parts[i]] or 0
            if s > worst then worst = s end
        end
        out[group] = {
            severity = worst,
            percent = math.floor((worst / MAX_SEVERITY) * 100 + 0.5),
        }
    end

    return out
end

local function push()
    SendNUIMessage({ action = 'bodyDamage', data = buildPayload() })
end

for group, parts in pairs(GROUPS) do
    for i = 1, #parts do
        local part = parts[i]
        local bag = PREFIX .. part

        -- Seed from whatever is already set: a player who reconnects mid-injury
        -- must not show a clean body until the next hit lands.
        local current = LocalPlayer.state[bag]
        severities[part] = type(current) == 'table' and current.severity or 0

        AddStateBagChangeHandler(bag, ('player:%s'):format(cache.serverId), function(_, _, value)
            severities[part] = type(value) == 'table' and value.severity or 0
            push()
        end)
    end
end

-- The panel asks for a snapshot when it mounts. Without this it would render
-- empty until the player's next injury changed a bag.
RegisterNUICallback('bodyDamage:request', function(_, cb)
    cb(buildPayload())
end)
