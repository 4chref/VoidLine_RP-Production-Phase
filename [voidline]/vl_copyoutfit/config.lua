CopyOutfit = {}

-- /copyoutfit <serverId>
CopyOutfit.command = 'copyoutfit'

-- ACE object required to use it. 'admin' is the same object permissions.cfg
-- already grants to group.admin, matching every other VoidLine admin tool.
--
-- This is NOT optional. Without a gate, any player could wear any other
-- player's outfit on demand, which is a straightforward impersonation tool --
-- and the check has to be server-side, because a client asking "am I allowed"
-- is a client that can lie.
CopyOutfit.ace = 'admin'

-- Copy the ped MODEL as well as the clothing.
--
-- Off by default, and think before turning it on. Clothing component indices
-- mean different garments on different models, so copying an outfit between
-- mp_m_freemode_01 and mp_f_freemode_01 without the model produces nonsense --
-- which is why the mismatch is refused outright below rather than applied.
-- Turning this on fixes that by making you their model, but it also replaces
-- your character's body, so you stop looking like yourself.
CopyOutfit.copyModel = false

-- Copy face, hair, head overlays and tattoos too, not just clothing.
--
-- Off by default. "Copy a clothing pack" is the intended job; taking someone's
-- FACE is a different thing entirely and is what turns this from a wardrobe
-- tool into genuine impersonation. Leave it off unless you specifically need
-- full-appearance cloning and understand that.
CopyOutfit.copyAppearance = false

-- Put an outfit ON someone else: /setoutfit <fromId> <toId>
CopyOutfit.setCommand = 'setoutfit'

-- Restore what you (or, with an id, someone else) were wearing before the last
-- change: /restoreoutfit [id]
CopyOutfit.restoreCommand = 'restoreoutfit'
