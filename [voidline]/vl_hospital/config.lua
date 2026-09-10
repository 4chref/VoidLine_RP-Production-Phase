VLHospital = {}

-- The doctor NPC. Heading faces the beds; adjust w to rotate the ped.
VLHospital.Doctor = {
    model = 's_m_m_doctor_01',
    coords = vec4(3101.22, 5452.83, 19.59, 293.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD', -- idle animation the doctor plays
}

-- Clinic beds. The player is laid down at these coords playing the sleep
-- animation. Adjust each `w` (heading) so the body lines up with the bed frame.
VLHospital.Beds = {
    vec4(3110.98, 5462.64, 19.51, 120.0),
    vec4(3113.46, 5458.09, 19.51, 120.0),
    vec4(3116.1, 5453.69, 19.51, 120.0),
}

-- Extra height above the bed coords to lay the ped on the mattress
VLHospital.BedZOffset = 0.02

-- A bed counts as occupied when any player ped is within this range of it
VLHospital.BedOccupiedRadius = 1.5

-- How long (seconds) the player rests in bed after checking in before getting up
VLHospital.RecoverySeconds = 10

-- Cooldown (seconds) between check-ins per player, to prevent spam
VLHospital.CheckInCooldown = 30

-- Sleep animation while in bed (same one Qbox hospitals use)
VLHospital.SleepAnim = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' }

-- Get-up animation when recovery finishes
VLHospital.WakeAnim = { dict = 'switch@franklin@bed', clip = 'sleep_getup_rubeyes' }
