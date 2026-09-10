--[[
    vl_setped -- server

    /setped [id] <model>   set another player's ped
    /setped <model>        set your own

    Registered restricted, so it needs the `command.setped` ACE. See
    permissions.cfg -- an unrestricted model swap is a griefing tool.
]]

---@param src number
---@param text string
local function reply(src, text, colour)
    if src == 0 then
        print('[vl_setped] ' .. text)
        return
    end
    TriggerClientEvent('chat:addMessage', src, { args = { (colour or '^1') .. 'setped:', text } })
end

--- Is this model one of the configured peds?
---@param model string
---@return boolean
local function inList(model)
    for i = 1, #VLSetPed.peds do
        if VLSetPed.peds[i].model:lower() == model:lower() then return true end
    end
    return false
end

--- serverId -> model, for players currently on a non-default ped.
---
--- Needed because a client that joins later, or that only just streamed another
--- player in, has no idea what model they are wearing -- and without it their
--- ped would render with the stock walk until the next /setped.
---@type table<number, string>
local wornModels = {}

--- A client asks for the full picture once it has loaded.
RegisterNetEvent('vl_setped:requestSync', function()
    local src = source
    for target, model in pairs(wornModels) do
        if target ~= src then
            TriggerClientEvent('vl_setped:sync', src, target, model)
        end
    end
end)

AddEventHandler('playerDropped', function()
    wornModels[source] = nil
end)

RegisterCommand('setped', function(source, args)
    local a1, a2 = args[1], args[2]

    if not a1 then
        reply(source, 'Usage: /setped [id] <model>  --  omit the id to change your own')
        return
    end

    local target, model

    if a2 then
        -- Two arguments: an id and a model.
        target = tonumber(a1)
        model = a2

        if not target then
            return reply(source, ('"%s" is not a player id.'):format(a1))
        end
    else
        -- One argument: it is the model, and the target is whoever ran it.
        -- Console has no ped of its own, so it must name a target.
        if source == 0 then
            return reply(source, 'From the console you must give a player id: /setped <id> <model>')
        end
        target, model = source, a1
    end

    if not GetPlayerName(target) then
        return reply(source, ('No player with id %s.'):format(tostring(target)))
    end

    -- Checked here rather than only on the client: the client check answers
    -- "can I render this", this one answers "is this allowed".
    if VLSetPed.restrictToList and not inList(model) then
        return reply(source, ('"%s" is not in VLSetPed.peds, and restrictToList is on.'):format(model))
    end

    TriggerClientEvent('vl_setped:setPed', target, model)

    -- Tell EVERYONE, not just the target.
    --
    -- SetPedMovementClipset is client-local and does not replicate, so a walk
    -- applied only on the wearer's machine is invisible to every other player --
    -- they see the same model doing the stock animation. Broadcasting the model
    -- lets each client apply the same clipset to that player's ped themselves.
    wornModels[target] = model
    TriggerClientEvent('vl_setped:sync', -1, target, model)

    reply(source, ('Set %s (%d) to %s.'):format(GetPlayerName(target), target, model), '^2')

    print(('[vl_setped] %s set %s (%s) to %s'):format(
        source == 0 and 'console' or GetPlayerName(source),
        GetPlayerName(target), target, model))
end, true)

-- Chat autocomplete. Lists the configured peds so the rust ones are
-- discoverable without reading config.lua.
-- VoidLine: this used to broadcast the suggestion to -1 (every connected
-- player) from a bare CreateThread with no delay -- fired the instant the
-- resource started, including at every restart while players were already
-- online, and hit anyone mid-connect whose own chat NUI hadn't finished
-- initializing yet. That's the exact race window `chat/dist/chat.js`'s
-- "Cannot read properties of undefined (reading 'replace')" boot error
-- matches. Registered per-player on load instead, with a short delay so it
-- lands after their chat resource has had time to finish its own init.
local suggestionParams

local function buildSuggestionParams()
    if suggestionParams then return suggestionParams end
    local names = {}
    for i = 1, #VLSetPed.peds do
        names[#names + 1] = VLSetPed.peds[i].model
    end
    suggestionParams = {
        { name = 'id',    help = 'server id -- omit to change your own' },
        { name = 'model', help = table.concat(names, ' | ') .. ' | any valid model' },
    }
    return suggestionParams
end

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if not src then return end
    SetTimeout(2000, function()
        TriggerClientEvent('chat:addSuggestion', src, '/setped', 'Change a player\'s ped model', buildSuggestionParams())
    end)
end)
