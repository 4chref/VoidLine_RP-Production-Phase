Citizen.CreateThread(function()
	while true do
		-- VoidLine: was Wait(0). This polls a flag that flips once and then
		-- returns out of the thread for good, so a per-frame poll bought
		-- nothing but frames during the join.
		Wait(250)

		if NetworkIsSessionStarted() then
			TriggerServerEvent('hardcap:playerActivated')

			return
		end
	end
end)