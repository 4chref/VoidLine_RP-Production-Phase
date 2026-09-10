Config = {}

Config.Coords = vector4(3092.38, 5442.00, 27.19, 332)
Config.InteractDistance = 2.0

-- GROUND HEIGHT
--
-- Coordinates read out of the game sit at the player's CENTRE, roughly a metre
-- above their feet, while CreatePed places a ped by its feet -- which is why a
-- vendor spawned at the raw number hangs in the air. Rather than bake in a
-- guessed offset, the ped probes straight down for the floor and stands on
-- whatever it finds. Correct indoors, outdoors, and on any surface.
Config.SnapToGround = true

-- How far above/below Config.Coords.z to search for that floor. Up covers a
-- coordinate taken slightly below the surface; down covers the usual
-- centre-of-player metre plus room to spare.
Config.GroundProbeUp = 1.0
Config.GroundProbeDown = 3.0

-- Fallback only, used when SnapToGround is false or the probe finds nothing:
-- the ped is spawned this far below Config.Coords.z. 1.0 is the convention
-- vl_campshop and vl_suitshop use for their standing vendors.
Config.PedZOffset = 1.0

Config.PedModel = 'a_m_m_farmer_01'

-- Standing vendor. Set back to 'PROP_HUMAN_SEAT_CHAIR' (and re-add the seat
-- probing) only if he is moved onto furniture again.
Config.PedScenario = 'WORLD_HUMAN_STAND_IMPATIENT'

Config.ShopLabel = 'Daily Goods'

-- Every item defaults to Config.DefaultPrice unless it sets its own `price`.
Config.DefaultPrice = 50

Config.Categories = {
    {
        id = 'essentials',
        label = 'Essentials',
        items = {
            { name = 'notepad',   label = 'Notepad',   price = 40 },
            { name = 'cigarette', label = 'Cigarette', price = 25 },
            { name = 'lighter',   label = 'Lighter',   price = 35 },
        },
    },
}
