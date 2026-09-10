fx_version 'cerulean'
game 'gta5'

name 'vl_drone_model'
author 'VoidLine'
description 'Oblivion combat drone add-on model (drone166), streamed for combat_drone'
version '1.0.0'

-- Add-on vehicle model. See README.md for exactly which files go where.
files {
    'data/vehicles.meta',
    'data/carvariations.meta',
    'data/handling.meta',
    'data/droneweapons.meta',
}

data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'
data_file 'HANDLING_FILE' 'data/handling.meta'

-- Defines VEHICLE_WEAPON_DRONE, which handling.meta references and which the
-- piloted flight mode fires via TaskVehicleShootAtPed. Required whenever
-- combat_drone runs with Config.FlightMode = 'piloted'.
-- The blob's <Name> was changed from the mod's "DLC - Turret (Insurgent)" to
-- "DLC - Drone166" so it can't clobber the stock Rockstar blob of that name.
data_file 'WEAPONINFO_FILE' 'data/droneweapons.meta'
