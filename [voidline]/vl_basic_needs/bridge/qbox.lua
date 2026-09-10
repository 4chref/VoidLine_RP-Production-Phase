-- Qbox bridge: only loaded/used when Config.Framework == 'qbox'
-- Kept isolated so the core system never depends on Qbox directly.

if Config.Framework ~= 'qbox' then return end

if IsDuplicityVersion() then
    -- server side qbox overrides
    CreateThread(function()
        local ok, QBX = pcall(function() return exports.qbx_core end)
        if not ok or not QBX then return end

        function Bridge.GetIdentifier(source)
            local player = QBX:GetPlayer(source)
            if player and player.PlayerData then
                return player.PlayerData.citizenid
            end
            for _, id in ipairs(GetPlayerIdentifiers(source)) do
                if string.find(id, 'license:') then
                    return id
                end
            end
            return 'unknown:' .. tostring(source)
        end
    end)
else
    -- client side qbox overrides
    function Bridge.IsPlayerLoaded()
        local ok, QBX = pcall(function() return exports.qbx_core end)
        if not ok or not QBX then return true end
        local ok2, loaded = pcall(function() return QBX:GetPlayerData() ~= nil end)
        return ok2 and loaded
    end
end
