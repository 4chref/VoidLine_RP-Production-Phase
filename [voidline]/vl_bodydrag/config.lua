Config = {}

Config.Locale = 'en'

Config.ShowDistance = 10.0 -- No
-- VoidLine: this is the ox_target reach for the "Drag body" option. Raised from
-- the stock 1.75 because a body on the ground is targeted at its chest, and
-- 1.75 made you stand almost on top of it before the option appeared.
Config.InteractDistance = 2.5

-- Mode test solo, permet de drag un PNJ mort (commandes /dragtest et /dragtestclear)
-- VoidLine: OFF. This is the only thing that registers ox_target's
-- addGlobalPed hook (client/debug.lua:54), which put a "drag body" option on
-- EVERY npc in the world -- ambient peds and af-expeditions hostiles included.
-- Dragging real players is unaffected: that path is addGlobalPlayer in
-- client/client.lua and was never gated on this flag.
-- Set back to true only to rehearse the ALT flow solo (/dragtest, /dragtestclear).
Config.Debug = false

-- VoidLine: no dragging in water.
--
-- The drag is an attach + a scripted animation. Swimming overrides both -- the
-- game puts the ped into its swim state, the carry animation stops playing, and
-- the attached body ends up towed through the water in a walking pose. It is
-- also how a body gets dragged out to sea and left somewhere nobody can reach.
--
-- Checked on BOTH people. Standing on the shore dragging someone whose body is
-- in the surf is the same broken picture as the other way round.
--
-- Set to false to allow it again.
Config.BlockInWater = true
