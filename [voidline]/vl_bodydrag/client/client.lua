drag = false
draggingPed = nil
animFinished = false
draggingNpc = nil
testPeds = {}

local draggingPlayer = nil
local imBeingDragged = false
local lastHeadingSync = 0
local headingDirty = false
local activeDraggers = {}

-- ============================================================================
--  SYNC ORIENTATION DU TRAÎNEUR
--  SetEntityHeading pendant une anim scriptée ne se réplique pas : le traîneur
--  diffuse son heading via un statebag, et chaque client le force en continu
--  sur le clone distant (sinon les autres le voient rester droit).
-- ============================================================================

AddStateBagChangeHandler('bodydragHeading', nil, function(bagName, _, value)
	local ply = GetPlayerFromStateBagName(bagName)
	if ply == 0 then return end

	local sid = GetPlayerServerId(ply)
	if sid == GetPlayerServerId(PlayerId()) then return end

	if value == nil then
		activeDraggers[sid] = nil
	else
		activeDraggers[sid] = value + 0.0
	end
end)

Citizen.CreateThread(function()
	while true do
		local any = false
		for sid, heading in pairs(activeDraggers) do
			any = true
			local ply = GetPlayerFromServerId(sid)
			local ped = (ply ~= -1) and GetPlayerPed(ply) or 0
			if ped ~= 0 then
				SetEntityHeading(ped, heading)
			end
		end
		Citizen.Wait(any and 0 or 500)
	end
end)

-- ============================================================================
--  CÔTÉ TRAÎNEUR
-- ============================================================================

-- ============================================================================
--  VoidLine: qbx_medical death state
--  IsPedDeadOrDying is useless on this server. qbx_medical's OnDeath calls
--  ResurrectPlayer(), sets health to max and makes the ped invincible -- a
--  "dead" player is a live, full-health ped playing the `dead_a` animation. So
--  the native reports false for exactly the people you want to drag, and true
--  for nobody. qbx_medical instead replicates a statebag we can read on any
--  client: Player(serverId).state.isDead, true for DEAD *and* LAST_STAND.
-- ============================================================================

---@param serverId number
local function isPlayerDead(serverId)
	return Player(serverId).state.isDead == true
end

-- VoidLine: no dragging in water -- see Config.BlockInWater.
--
-- IsEntityInWater rather than IsPedSwimming: swimming only becomes true once
-- the ped is out of its depth, and the pose is already broken while wading in
-- the shallows. This is true as soon as the ped is touching water, which is the
-- point at which the carry animation stops looking like a carry.
---@param ped number
---@return boolean
local function inWater(ped)
	if not Config.BlockInWater then return false end
	return ped ~= 0 and IsEntityInWater(ped)
end

local function amIDead()
	-- Same reason: a qbx-dead player is at full health, so without this a dead
	-- player could stand up and drag somebody.
	return LocalPlayer.state.isDead == true
end

local function startDrag(targetServerId)
	if drag then return end

	local p1 = PlayerPedId()
	if amIDead() then return end

	local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
	if targetPed == 0 or targetPed == p1 then return end
	if #(GetEntityCoords(targetPed) - GetEntityCoords(p1)) > Config.ShowDistance then return end

	-- Re-checked rather than trusted from canInteract: onSelect runs from
	-- ox_target's NUI callback and startDrag is dispatched onto its own thread,
	-- so someone can step into the water between the option appearing and the
	-- drag beginning.
	if inWater(p1) or inWater(targetPed) then return end

	drag = true
	draggingPed = targetPed
	draggingPlayer = targetServerId

	runDragSequence(
		function() TriggerServerEvent('icemallow-drag-server:attach', targetServerId) end,
		function() LocalPlayer.state:set('bodydragHeading', GetEntityHeading(PlayerPedId()) + 0.0, true) end
	)
end

-- ============================================================================
--  VoidLine: ox_target instead of the proximity prompt
--  Upstream ran a 500ms thread scanning every active player, drew a native
--  helptext and watched for a keypress. That is replaced by a single global
--  player option, so dragging uses the same ALT interaction as everything else
--  on this server (ox_target:defaultHotkey is LMENU in ox.cfg).
--
--  addGlobalPlayer registers against every player; canInteract is what decides
--  whether the option is offered, and it runs per raycast rather than on a
--  timer, so there is no polling at all now.
-- ============================================================================

exports.ox_target:addGlobalPlayer({
	{
		name = 'bodydrag:drag',
		icon = 'fa-solid fa-person-walking-with-cane',
		label = _U('target_drag'),
		distance = Config.InteractDistance,

		canInteract = function(entity)
			if drag or amIDead() then return false end

			-- NetworkGetPlayerIndexFromPed returns -1 for anything that is not
			-- a player ped, which is what keeps this off NPCs.
			local ply = NetworkGetPlayerIndexFromPed(entity)
			if ply == -1 then return false end

			local sid = GetPlayerServerId(ply)
			if sid <= 0 or sid == GetPlayerServerId(PlayerId()) then return false end

			-- Either one being in water is enough to refuse.
			if inWater(PlayerPedId()) or inWater(entity) then return false end

			return isPlayerDead(sid)
		end,

		onSelect = function(data)
			local ply = NetworkGetPlayerIndexFromPed(data.entity)
			if ply == -1 then return end

			local sid = GetPlayerServerId(ply)

			-- VoidLine: own thread. startDrag runs the pickup sequence, which
			-- waits 5.7s for the animation, and ox_target invokes onSelect from
			-- its NUI callback -- not somewhere it is safe to block.
			CreateThread(function() startDrag(sid) end)
		end
	}
})

--- VoidLine: the whole put-down sequence, in one place.
---
--- Extracted from the drop keypress so that walking into water can trigger the
--- exact same teardown. Duplicating it was the alternative, and the two copies
--- would have drifted the first time anything about detaching changed.
---@param playerPed number
local function dropBody(playerPed)
	drag = false
	animFinished = false
	draggingPed = nil
	headingDirty = false
	LocalPlayer.state:set('bodydragHeading', nil, true)

	loadAnimDict()
	TaskPlayAnim(playerPed, ANIM_DICT, 'injured_putdown_plyr', 2.0, 2.0, 5500, 1, 0, false, false, false)

	if draggingNpc then
		local npc = draggingNpc
		draggingNpc = nil

		TaskPlayAnim(npc, ANIM_DICT, 'injured_putdown_ped', 8.0, -8.0, 5500, 1, 0, false, false, false)

		Citizen.CreateThread(function()
			Citizen.Wait(5500)
			if DoesEntityExist(npc) then
				DetachEntity(npc, true, true)
				SetEntityInvincible(npc, false)
				SetEntityHealth(npc, 0)
			end
		end)
	else
		if draggingPlayer then
			TriggerServerEvent('icemallow-drag-server:deattach', draggingPlayer)
		end
		draggingPlayer = nil
	end
end

-- Rotation + dépose (ne tick vite que pendant un drag)
Citizen.CreateThread(function()
	while true do
		local sleep = 1000

		if drag and animFinished then
			sleep = 0

			local playerPed = PlayerPedId()

			ShowHelp(_U('drop_prompt'))

			local turn = 30.0 * GetFrameTime()

			local turned = false
			if IsControlPressed(0, 30) then
				SetEntityHeading(playerPed, GetEntityHeading(playerPed) + turn)
				turned = true
			elseif IsControlPressed(0, 34) then
				SetEntityHeading(playerPed, GetEntityHeading(playerPed) - turn)
				turned = true
			end

			if turned then
				headingDirty = true
				if GetGameTimer() - lastHeadingSync > 60 then
					lastHeadingSync = GetGameTimer()
					LocalPlayer.state:set('bodydragHeading', GetEntityHeading(playerPed) + 0.0, true)
				end
			elseif headingDirty then
				headingDirty = false
				LocalPlayer.state:set('bodydragHeading', GetEntityHeading(playerPed) + 0.0, true)
			end

			-- VoidLine: drop on demand, and drop on entering water.
			--
			-- One shared teardown rather than two: the sequence detaches, plays
			-- the put-down on both peds, clears the heading statebag and tells
			-- the server -- miss any of it and the body stays welded to a player
			-- who is no longer dragging. See dropBody() above.
			if IsControlJustPressed(0, 47) then
				dropBody(playerPed)
			elseif inWater(playerPed) or (draggingPed and inWater(draggingPed)) then
				dropBody(playerPed)
			end
		end

		Citizen.Wait(sleep)
	end
end)

-- ============================================================================
--  CÔTÉ VICTIME (le corps traîné)
-- ============================================================================

RegisterNetEvent('icemallow-drag:attach')
AddEventHandler('icemallow-drag:attach', function(who)
	local p1 = PlayerPedId()
	local p2 = GetPlayerPed(GetPlayerFromServerId(who))
	local coords = GetEntityCoords(p1)

	imBeingDragged = true

	-- VoidLine: this is what makes the victim actually animate.
	--
	-- Both of Qbox's downed states re-apply their animation in a Wait(0) loop:
	-- qbx_ambulancejob's setdownedstate thread calls PlayDeadAnimation() every
	-- frame while DEAD, and qbx_medical's laststand thread calls
	-- PlayLastStandAnimation() every frame while LAST_STAND. Both are guarded
	-- with "if not IsEntityPlayingAnim(<downed anim>)", so the instant the drag
	-- animation takes over they put the downed one straight back -- which is
	-- exactly what you see: the dragger animates, the victim stays face down.
	--
	-- Both loops now skip while this is set. Cleared on release, and each loop
	-- restores the animation appropriate to its own state on the next frame.
	LocalPlayer.state:set('bodydragged', true, false)

	SetEntityCoordsNoOffset(p1, coords.x, coords.y, coords.z, false, false, false, true)

	-- VoidLine: only resurrect if the ped is genuinely dead. Under qbx_medical
	-- it is not -- OnDeath already resurrected it and set full health -- so
	-- calling this unconditionally would clear the ped's tasks and fight the
	-- death state for no gain. Kept as a fallback for a real corpse.
	if IsPedDeadOrDying(p1, 1) then
		NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(p2), true, false)
		SetEntityHealth(p1, GetPedMaxHealth(p1))
	end

	SetEntityHeading(p1, GetEntityHeading(p2))

	SetPedCanRagdoll(p1, false)
	SetEntityInvincible(p1, true)

	AttachEntityToEntity(p1, p2, 11816, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, false, false, true, false, 2, false)

	loadAnimDict()
	TaskPlayAnim(p1, ANIM_DICT, 'injured_pickup_back_ped', 8.0, -8.0, -1, 1, 0, false, false, false)

	Citizen.Wait(5700)

	if imBeingDragged then
		TaskPlayAnim(p1, ANIM_DICT, 'injured_drag_ped', 8.0, -8.0, -1, 1, 0, false, false, false)
	end
end)

RegisterNetEvent('icemallow-drag:deattach')
AddEventHandler('icemallow-drag:deattach', function(who)
	if not imBeingDragged then return end
	imBeingDragged = false

	local p1 = PlayerPedId()

	loadAnimDict()
	TaskPlayAnim(p1, ANIM_DICT, 'injured_putdown_ped', 8.0, -8.0, 5500, 1, 0, false, false, false)

	Citizen.Wait(5500)

	DetachEntity(p1, true, true)

	-- VoidLine: upstream finished with SetEntityHealth(p1, 0) to put the body
	-- back on the floor. That is wrong here -- under qbx_medical the player is
	-- deliberately kept alive and invincible while "dead", so zeroing health
	-- hard-kills someone the framework already considers dead and can fire a
	-- second death or strand them out of the respawn loop.
	--
	-- If qbx still has them down, hand presentation back to it: restore
	-- invincibility and release the flag. Deliberately not calling
	-- PlayDeadAnimation here -- qbx's own loop picks it up on the next frame
	-- and plays the animation matching the actual state, which PlayDeadAnimation
	-- would get wrong for LAST_STAND. Only fall through to the original
	-- behaviour when qbx is not managing this death.
	if LocalPlayer.state.isDead then
		SetPedCanRagdoll(p1, false)
		SetEntityInvincible(p1, true)
		LocalPlayer.state:set('bodydragged', false, false)
	else
		LocalPlayer.state:set('bodydragged', false, false)
		SetEntityInvincible(p1, false)
		SetPedCanRagdoll(p1, true)
		SetEntityHealth(p1, 0)
	end
end)

local function forceDetachSelf()
	if not imBeingDragged then return end
	imBeingDragged = false

	-- VoidLine: must clear here too, or a revive/respawn mid-drag leaves the
	-- flag set and qbx never animates that player being downed again.
	LocalPlayer.state:set('bodydragged', false, false)

	local p1 = PlayerPedId()
	DetachEntity(p1, true, true)
	SetPedCanRagdoll(p1, true)
	ClearPedTasksImmediately(p1)
end

AddEventHandler('playerSpawned', forceDetachSelf)

-- VoidLine: qbx_medical's respawn goes through its own server callback and does
-- not necessarily fire playerSpawned, so a revive mid-drag would otherwise
-- leave the victim welded to the dragger.
--
-- RegisterNetEvent, not AddEventHandler: qbx_medical and qbx_ambulancejob both
-- send this with TriggerClientEvent (their server/main.lua), and FiveM only
-- hands a networked event to a resource that registered it as one *in that
-- resource*. With a plain AddEventHandler it was refused every time and logged
-- as "event qbx_medical:client:playerRevived was not safe for net", so this
-- handler had never actually run. The isDead state watcher below is what has
-- been covering revives in practice.
RegisterNetEvent('qbx_medical:client:playerRevived', forceDetachSelf)

-- Belt and braces, and the one that actually covers every exit: the moment qbx
-- stops considering us dead -- revive, respawn, admin heal, anything -- let go.
-- Watching the state rather than guessing at event names means a route added
-- later is covered for free.
AddStateBagChangeHandler('isDead', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
	if not value then forceDetachSelf() end
end)
