-- =============================================================================
-- vl_outpost / client/suits.lua
--
-- Moved from vl_suitshop 2026-09-02, unchanged in behaviour.
--
-- Using a suit item swaps the player's ped MODEL. SetPlayerModel replaces the
-- local player's networked entity, so the new model is visible to other clients
-- with no extra sync code.
--
-- The item is NOT consumed: using it again puts the ORIGINAL appearance back,
-- snapshotted through illenium-appearance right before the swap, so what comes
-- back is exactly what was being worn -- model, clothes and face, not a generic
-- freemode reset.
-- =============================================================================

local savedAppearance = nil
local currentSuit = nil

local function wearSuit(modelName)
    local model = joaat(modelName)
    lib.requestModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
end

local function toggleSuit(itemName, modelName)
    if currentSuit == nil then
        savedAppearance = exports['illenium-appearance']:getPedAppearance(cache.ped)
        wearSuit(modelName)
        currentSuit = itemName
    elseif currentSuit == itemName then
        exports['illenium-appearance']:setPlayerAppearance(savedAppearance)
        savedAppearance = nil
        currentSuit = nil
    else
        -- Already in a different suit: switch straight across, keeping the
        -- ORIGINAL snapshot so that is still what comes back later.
        wearSuit(modelName)
        currentSuit = itemName
    end
end

CreateThread(function()
    local suits = Config.Shops.suits
    if not suits then return end

    for _, item in ipairs(suits.items or {}) do
        if item.model then
            exports(item.name, function(data, slot)
                exports.ox_inventory:useItem(data, function(result)
                    if result then toggleSuit(item.name, item.model) end
                end)
            end)
        end
    end
end)
