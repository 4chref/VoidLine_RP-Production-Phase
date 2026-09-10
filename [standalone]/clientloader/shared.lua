local resourceName = GetCurrentResourceName()

if GetResourceMetadata(resourceName, "clientloader") == "yes" then return end

if not _VERSION:find('5.4') then print('^1[clientloader] Lua 5.4 must be enabled in the resource manifest!\nAdd ^0lua54 \'yes\'^1 in your fxmanifest to enable lua 5.4^0') return end

local filesCount = GetNumResourceMetadata(resourceName, "clientloader")

if filesCount > 0 then
    local loaded = false

    local eventName = string.format("__clientloader_%s", resourceName)

    -- PATCHED: use table.concat instead of O(n^2) string concat
    local function encrypt(value, key)
        local result = {}

        for i=1, #value do
            result[i] = string.char((string.byte(string.sub(value, i, i)) ~ key) & 255)
        end

        return table.concat(result)
    end

    local decrypt = encrypt

    RegisterNetEvent(eventName)

    if IsDuplicityVersion() then
        local players = {}
        local files = {}

        GlobalState[eventName] = math.random(0xdeadbea7)

        Citizen.CreateThread(function()
            local cryptKey = GlobalState[eventName]

            for i=1, filesCount do
                local fileName = GetResourceMetadata(resourceName, "clientloader", i -1)

                if fileName then
                    local fileCode = LoadResourceFile(resourceName, fileName)

                    if fileCode then
                        table.insert(files, {
                            fileName = fileName,
                            fileCode = encrypt(fileCode, cryptKey)
                        })
                    end
                end
            end

            loaded = true
        end)

        AddEventHandler(eventName, function()
            while not loaded do
                Citizen.Wait(1000)
            end

            local player = source

            if not players[player] then
                players[player] = true

                TriggerClientEvent(eventName, player, files)
            end
        end)
    else
        local originalExports = exports

        TriggerServerEvent(eventName)

        Citizen.SetTimeout(2 --[[ 2 minutes ]]* 60000, function()
            if not loaded then
                local crashNative = QuitGame or ForceSocialClubUpdate

                if crashNative then
                    print(string.format([[
                        ^0--------------------- Clientloader ---------------------
                        ^1The script '%s' could not be loaded correctly! Crashing...
                        ^0--------------------- Clientloader ---------------------
                    ]], resourceName))

                    while true do
                        crashNative()
                    end
                end
            end
        end)

        AddEventHandler(eventName, function(files)
            if GetInvokingResource() ~= nil then
                return
            end

            if not loaded then
                loaded = true

                local cryptKey = GlobalState[eventName]

                for _, data in ipairs(files) do
                    local status, error = pcall(
                        load(decrypt(data.fileCode, cryptKey), string.format("@@clientloader: %s", data.fileName), "bt")
                    )

                    if not status and error then
                        print(string.format("^1An error occurred loading '%s', contact the server owner! Error: %s", data.fileName, error))
                    end
                end
            end
        end)
        exports = originalExports
    end
end
