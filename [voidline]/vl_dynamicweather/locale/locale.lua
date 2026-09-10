-- Locale resolver — MUST be the last locale file in fxmanifest shared_scripts
-- (after every Locales['xx'] file). Falls back to English when a language or
-- the whole table is missing.

function _L()
    return Locales[Config.Locale] or Locales['en'] or {}
end

-- Only the `ui` section is sent to the NUI (see client/nui.lua getLocale).
function _LUI()
    local L = _L()
    return (L and L.ui) or {}
end
