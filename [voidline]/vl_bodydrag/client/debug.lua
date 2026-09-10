-- ============================================================================
--  MODE TEST SOLO (Config.Debug)
--  Permet de tester le drag sur un PNJ mort, sans second joueur.
--  Tout se passe en local : aucun event serveur n'est utilise.
--  Utilise l'état et les fonctions partagées définies (non-local) dans client.lua :
--  drag, draggingPed, draggingNpc, animFinished, testPeds, ANIM_DICT, ShowHelp, runDragSequence.
-- ============================================================================

-- VoidLine: the test NPC gets the same ox_target treatment as the real thing,
-- replacing the old proximity scan + keypress. The point of the debug mode is
-- to rehearse the real interaction solo, and it could not do that while the
-- live path was ALT and this one was a hidden keybind.
--
-- addGlobalPed and addGlobalPlayer do not overlap: ox_target checks
-- IsPedAPlayer before deciding which set of options an entity gets, so this
-- never appears on a real player and the drag option never appears on an NPC.
--
-- Unlike the player path, IsPedDeadOrDying is correct here -- a test NPC really
-- is dead, with no framework keeping it alive and invincible.

local function startNpcDrag(npc)
	if drag or not DoesEntityExist(npc) then return end

	local p1 = PlayerPedId()

	drag = true
	draggingNpc = npc
	draggingPed = npc

	SetEntityInvincible(npc, true)
	SetPedCanRagdoll(npc, false)
	SetBlockingOfNonTemporaryEvents(npc, true)

	local timeout = GetGameTimer() + 1000
	repeat
		ResurrectPed(npc)
		SetEntityHealth(npc, 200)
		Wait(0)
	until not IsPedDeadOrDying(npc, 1) or GetGameTimer() > timeout

	ClearPedTasksImmediately(npc)

	runDragSequence(
		function()
			AttachEntityToEntity(npc, p1, 11816, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, false, false, true, false, 2, false)
			TaskPlayAnim(npc, ANIM_DICT, 'injured_pickup_back_ped', 8.0, -8.0, -1, 1, 0, false, false, false)
		end,
		function()
			TaskPlayAnim(npc, ANIM_DICT, 'injured_drag_ped', 8.0, -8.0, -1, 1, 0, false, false, false)
		end
	)
end

if Config.Debug then
	exports.ox_target:addGlobalPed({
		{
			name = 'bodydrag:dragtest',
			icon = 'fa-solid fa-person-walking-with-cane',
			label = _U('target_drag_test'),
			distance = Config.InteractDistance,

			canInteract = function(entity)
				if drag or LocalPlayer.state.isDead then return false end
				return IsPedDeadOrDying(entity, 1)
			end,

			onSelect = function(data)
				local npc = data.entity
				-- Own thread: startNpcDrag waits on the pickup animation, and
				-- ox_target calls onSelect from its NUI callback.
				CreateThread(function() startNpcDrag(npc) end)
			end
		}
	})
end

RegisterCommand('dragtest', function()
	if not Config.Debug then return end

	local ply = PlayerPedId()
	local model = `a_m_m_business_01`

	RequestModel(model)
	while not HasModelLoaded(model) do
		Wait(0)
	end

	local pos = GetEntityCoords(ply) + (GetEntityForwardVector(ply) * 2.0)
	local ped = CreatePed(4, model, pos.x, pos.y, pos.z, GetEntityHeading(ply), false, false)
	SetModelAsNoLongerNeeded(model)

	SetEntityHealth(ped, 0)

	testPeds[#testPeds + 1] = ped
end, false)

RegisterCommand('dragtestclear', function()
	if not Config.Debug then return end

	for _, ped in ipairs(testPeds) do
		if DoesEntityExist(ped) then
			DetachEntity(ped, true, true)
			DeleteEntity(ped)
		end
	end

	testPeds = {}
	drag = false
	animFinished = false
	draggingNpc = nil
	draggingPed = nil
	ClearPedTasks(PlayerPedId())
end, false)
