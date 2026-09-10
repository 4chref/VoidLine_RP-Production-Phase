-- VoidLine: the native FiveM/GTA pause menu (ESC) bundles Map, Game, Info,
-- Stats, Settings and Gallery into ONE tab bar (pausemenu.xml's
-- MENU_UNIQUE_ID_HEADER_MULTIPLAYER) -- FiveM has no supported way to strip
-- a single tab from it. Confirmed against FiveM's own docs/forum: the
-- data_file override system that overrides other game data files explicitly
-- cannot touch pausemenu.xml, and there is an open, still-unimplemented
-- feature request asking for exactly that capability.
--
-- The only way to drop Map without dropping everything else is to never
-- open that tabbed menu at all, and instead jump straight to the one native
-- sub-page that actually matters day to day -- Settings (audio/video/
-- controls/display) -- via ActivateFrontendMenu. Same technique used by the
-- community's own native-pause-menu-replacement resources (e.g.
-- Vanity-Pausemenu, Roda_PauseMenu): block the native menu every frame with
-- SetPauseMenuActive(false), then catch the ESC press yourself.

CreateThread(function()
    while true do
        -- VoidLine 2026-08-31: this used to call SetPauseMenuActive(false)
        -- unconditionally, every frame -- including while the settings page
        -- opened below (via ActivateFrontendMenu) was actively showing. That
        -- page relies on the same underlying pause-menu-active state to
        -- handle its own ESC-to-close behaviour; fighting it every single
        -- frame raced against that close, and the menu could get stuck open
        -- (intermittently -- a race, not every time -- matching "sometimes
        -- can't close it unless I stop the script"). Now only suppressed
        -- while no native frontend menu (ours or otherwise) is showing, so
        -- the close behaviour isn't fought while a page is actually open.
        if GetCurrentFrontendMenuVersion() == -1 then
            SetPauseMenuActive(false)
            -- Backspace (control 202, INPUT_FRONTEND_PAUSE_ALTERNATE) opens
            -- the native settings menu on its own at the engine level,
            -- independent of SetPauseMenuActive and of the ESC handling
            -- below -- disabling the control action itself is what actually
            -- stops it. This only suppresses it as a GAME control; it does
            -- not touch OS/NUI-level key events, so Backspace still deletes
            -- text normally in chat, NUI inputs, etc.
            DisableControlAction(0, 202, true)
        end
        Wait(0)
    end
end)

local function openSettings()
    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_LANDING_MENU'), false, -1)
end

CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 200) -- ESC only, Backspace (202) left alone on purpose
            and GetCurrentFrontendMenuVersion() == -1
            and not IsPauseMenuActive()
            and not IsNuiFocused() then
            openSettings()
        end
    end
end)
