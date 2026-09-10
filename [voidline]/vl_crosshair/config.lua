Config = {}

-- Matches the classic GTA V PC default reticle: a small gapped cross, thin
-- white lines, mostly opaque. Sizes are fractions of screen width/height so
-- it stays correct at any resolution/aspect ratio.
Config.Size = 0.0016      -- line thickness (width, as a fraction of screen width)
Config.Length = 0.010     -- length of each arm (as a fraction of screen height)
Config.Gap = 0.004        -- empty space between the crosshair center and each arm
Config.Color = { r = 255, g = 255, b = 255, a = 200 }
Config.OutlineColor = { r = 0, g = 0, b = 0, a = 120 } -- thin dark backing, like the vanilla reticle

-- Hidden automatically while in a vehicle (driveby uses its own reticle),
-- while the weapon's scope is active (the scope draws its own), or while
-- unarmed/using melee-only fists.
Config.HideInVehicle = true
Config.HideWhileScoped = true
Config.HideUnarmed = true
