-- [targetId] = draggerId. Sert à la fois à valider attach/deattach (un client ne peut
-- pas forcer l'attache de n'importe qui) et à nettoyer proprement les déconnexions
local draggingBy = {}

local function canDrag(source, target)
	if type(target) ~= 'number' or target == source then return false end
	if GetPlayerName(target) == nil then return false end
	if draggingBy[target] or draggingBy[source] then return false end

	for _, draggerId in pairs(draggingBy) do
		if draggerId == source or draggerId == target then return false end
	end

	local sourcePed = GetPlayerPed(source)
	local targetPed = GetPlayerPed(target)
	if sourcePed == 0 or targetPed == 0 then return false end

	-- VoidLine: upstream required GetEntityHealth(targetPed) <= 0, which
	-- rejects every death on this server. qbx_medical's OnDeath resurrects the
	-- ped and sets it to full health -- a "dead" player is a live, invincible
	-- ped playing the `dead_a` animation -- so the health test was false for
	-- exactly the people you are meant to be able to drag.
	--
	-- qbx_medical replicates isDead (true for DEAD and LAST_STAND); that is the
	-- authority. Checked here and not just on the client, because this is the
	-- event a client could otherwise fire for any player id it liked.
	if not Player(target).state.isDead then return false end
	if Player(source).state.isDead then return false end

	if #(GetEntityCoords(targetPed) - GetEntityCoords(sourcePed)) > Config.ShowDistance then return false end

	return true
end

RegisterServerEvent('icemallow-drag-server:attach')
AddEventHandler('icemallow-drag-server:attach', function(target)
	local source = tonumber(source)

	if not canDrag(source, target) then return end

	draggingBy[target] = source
	TriggerClientEvent('icemallow-drag:attach', target, source)
end)

RegisterServerEvent('icemallow-drag-server:deattach')
AddEventHandler('icemallow-drag-server:deattach', function(target)
	local source = tonumber(source)

	if draggingBy[target] ~= source then return end

	draggingBy[target] = nil
	TriggerClientEvent('icemallow-drag:deattach', target, source)
end)

-- VoidLine: a victim who gets revived or respawns mid-drag has to be released
-- server-side too, otherwise draggingBy keeps the pair locked and neither can
-- start another drag until one of them disconnects.
AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
	if value then return end

	local playerId = GetPlayerFromStateBagName(bagName)
	if playerId == 0 then return end

	local draggerId = draggingBy[playerId]
	if not draggerId then return end

	draggingBy[playerId] = nil
	TriggerClientEvent('icemallow-drag:deattach', playerId, draggerId)
end)

-- Si le traîneur ou la victime se déconnecte en plein drag, on libère l'autre proprement.
AddEventHandler('playerDropped', function()
	local source = tonumber(source)

	draggingBy[source] = nil

	for target, draggerId in pairs(draggingBy) do
		if draggerId == source then
			TriggerClientEvent('icemallow-drag:deattach', target, source)
			draggingBy[target] = nil
		end
	end
end)