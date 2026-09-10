Database = {}

local function hasMySQL()
    return Config.UseDatabase and GetResourceState('oxmysql') == 'started'
end

--- Load a player's persisted needs. Returns table {poop, sleep, pee} or nil.
function Database.Load(identifier)
    if not hasMySQL() then return nil end

    local result = MySQL.query.await('SELECT poop, sleep, pee FROM player_needs WHERE identifier = ?', { identifier })
    if result and result[1] then
        return {
            poop = result[1].poop,
            sleep = result[1].sleep,
            pee = result[1].pee
        }
    end
    return nil
end

--- Insert or update a player's needs.
function Database.Save(identifier, poop, sleep, pee)
    if not hasMySQL() then return end

    MySQL.insert(
        'INSERT INTO player_needs (identifier, poop, sleep, pee) VALUES (?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE poop = VALUES(poop), sleep = VALUES(sleep), pee = VALUES(pee)',
        { identifier, poop, sleep, pee }
    )
end
