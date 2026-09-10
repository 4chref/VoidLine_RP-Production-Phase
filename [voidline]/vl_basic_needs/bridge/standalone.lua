-- Standalone bridge: default identifier + framework hooks used when Config.Framework == 'standalone'
Bridge = Bridge or {}

function Bridge.GetIdentifier(source)
    if IsDuplicityVersion() then
        -- server side
        for _, id in ipairs(GetPlayerIdentifiers(source)) do
            if string.find(id, 'license:') then
                return id
            end
        end
        return 'unknown:' .. tostring(source)
    else
        return nil
    end
end

function Bridge.IsPlayerLoaded()
    -- standalone: always considered loaded once client resource starts
    return true
end
