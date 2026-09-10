-- =============================================================================
-- vl_forcequit
-- =============================================================================
-- Ctrl+Shift+D closes the game client immediately, via FiveM's own built-in
-- `quit` command -- the same one the pause menu's "Quit Game" button runs.
-- There's no scripting native to close the client, only that command.
--
-- Uses raw keyboard state (IsRawKeyDown) rather than RegisterKeyMapping/
-- IsControlPressed: those are built around GTA's single-key control bindings
-- and don't cleanly express a three-key combo. Raw key codes are the
-- standard Windows virtual-key codes: 0x11 = Ctrl, 0x10 = Shift, 0x44 = D.

local VK_CONTROL = 0x11
local VK_SHIFT   = 0x10
local VK_D       = 0x44

CreateThread(function()
    while true do
        Wait(0)

        if IsRawKeyDown(VK_CONTROL) and IsRawKeyDown(VK_SHIFT) and IsRawKeyDown(VK_D) then
            ExecuteCommand('quit')
        end
    end
end)
