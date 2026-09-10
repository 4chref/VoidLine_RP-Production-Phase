-- Fonctions utilitaires partagées entre client/client.lua et client/debug.lua.

ANIM_DICT = 'combat@drag_ped@'

function loadAnimDict()
	if HasAnimDictLoaded(ANIM_DICT) then return end

	RequestAnimDict(ANIM_DICT)
	while not HasAnimDictLoaded(ANIM_DICT) do
		Wait(0)
	end
end

-- Helptext natif (pas de dépendance framework) : à rappeler chaque frame pour rester affiché.
function ShowHelp(text)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Séquence d'anim commune côté traîneur (ramassage -> attente -> traîne), utilisée aussi
-- bien pour un vrai joueur que pour un PNJ en mode test. onPickedUp gère l'attache de la
-- cible (event serveur ou AttachEntityToEntity local), onDragging la suite une fois debout.
-- Dépend de l'état partagé (drag, animFinished) défini dans client.lua.
function runDragSequence(onPickedUp, onDragging)
	local p1 = PlayerPedId()
	local duration = 5700

	loadAnimDict()
	TaskPlayAnim(p1, ANIM_DICT, 'injured_pickup_back_plyr', 2.0, 2.0, duration, 1, 0, false, false, false)
	onPickedUp()

	Citizen.Wait(duration)

	if not drag then return end

	animFinished = true
	TaskPlayAnim(p1, ANIM_DICT, 'injured_drag_plyr', 2.0, 2.0, -1, 1, 0, false, false, false)
	onDragging()
end
