-- ════════════════════════════════════════════════════════════════
-- codem-dynamicweather · Server-side permission check (single decision point)
--
-- This file ships UNENCRYPTED (see escrow_ignore in fxmanifest.lua) — edit it freely.
-- Everything the panel does is gated here: opening it AND every state mutation.
--
-- A player is allowed if ANY layer below says yes. If none does, access is DENIED
-- (fail-closed). See config/Config.lua for the options each layer reads.
--
-- Why a dedicated ACE object (`dynamicweather.admin`) and never `command.<Command>`:
-- a single server.cfg line such as `add_ace group.user command allow` grants EVERY
-- `command.*` ace, including ours, to every player in that group. Which groups exist is
-- outside our control and cannot be enumerated, so that ace is not usable as a gate.
--
-- Note: resources cannot run `add_ace` (FiveM denies it), so we can never grant ourselves.
-- Grant it once in server.cfg:
--     add_ace group.admin dynamicweather.admin allow     -- txAdmin / qbx_core / ESX
--     add_ace qbcore.admin dynamicweather.admin allow    -- qb-core
-- ════════════════════════════════════════════════════════════════

CDWPerm = {}

local RESOURCE = GetCurrentResourceName()

local function alert(msg)
    print(("^1[%s] SECURITY: %s^7"):format(RESOURCE, msg))
end

local function info(msg)
    print(("^2[%s]^7 %s"):format(RESOURCE, msg))
end

-- This file is buyer-editable, so never assume an option still exists / has the right type.
local function admins()
    return type(Config.Admins) == "table" and Config.Admins or {}
end

-- A missing/blank ace object would make IsPlayerAceAllowed meaningless. Fall back loudly.
local PANEL_ACE = (function()
    local a = Config.AcePermission
    if type(a) ~= "string" or a == "" then
        print(("^3[%s]^7 config: AcePermission must be a non-empty string — using 'dynamicweather.admin'.")
            :format(RESOURCE))
        return "dynamicweather.admin"
    end
    return a
end)()

-- IS_PLAYER_ACE_ALLOWED takes a char* — pass the source as a string, like qb-core does.
local function aceAllowed(src, object)
    return IsPlayerAceAllowed(tostring(src), object)
end

-- ── Startup self-check ───────────────────────────────────────────
-- These principals must never hold the admin ace. This is a WARNING, not a gate: custom
-- groups (group.vip, …) cannot be enumerated, which is exactly why the panel ace must be
-- a dedicated object that nothing else grants.
local RISKY_PRINCIPALS = { "builtin.everyone", "group.user", "group.default" }

local function selfCheck()
    -- Every ace object we actually accept must be checked, not just the dedicated one.
    -- The qb-core shortcut uses bare objects ('admin' / 'god') which are generic enough
    -- that an unrelated server.cfg line could hand them to a non-admin principal.
    local guarded = { PANEL_ACE }
    if Config.FrameworkPermission and GetResourceState("qb-core") == "started" then
        for _, perm in ipairs(Config.QbPermissions or {}) do
            guarded[#guarded + 1] = perm
        end
    end

    for _, principal in ipairs(RISKY_PRINCIPALS) do
        for _, object in ipairs(guarded) do
            if IsPrincipalAceAllowed(principal, object) then
                alert(("principal '%s' holds ace '%s' — EVERY player can control the weather. Fix your server.cfg."):format(
                    principal, object))
            end
        end
    end

    local count = #admins()
    local layers = { ("ace '%s'"):format(PANEL_ACE) }
    if count > 0 then
        layers[#layers + 1] = ("%d allowlisted identifier(s)"):format(count)
    end
    if Config.FrameworkPermission and GetResourceState("qb-core") == "started" then
        layers[#layers + 1] = "qb-core permissions"
    end
    if type(Config.CanOpenPanel) == "function" then
        layers[#layers + 1] = "Config.CanOpenPanel"
    end
    info(("permission layers: %s"):format(table.concat(layers, ", ")))
end

-- Deferred one tick: `add_ace` lines may sit *after* `ensure` in server.cfg, in which case
-- the ACE store is not populated yet when this resource starts.
AddEventHandler("onResourceStart", function(res)
    if res ~= RESOURCE then return end
    SetTimeout(0, selfCheck)
end)

-- ── Layers ───────────────────────────────────────────────────────

-- 1) Identifier allowlist — no server.cfg edit needed.
local function inAllowlist(src)
    local list = admins()
    if #list == 0 then return false end
    local wanted = {}
    for _, id in ipairs(list) do
        if type(id) == "string" then wanted[id:lower()] = true end
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if wanted[id:lower()] then return true end
    end
    return false
end

-- 2) qb-core runs `add_ace qbcore.<perm> <perm> allow` for every entry of
--    QBCore.Config.Server.Permissions ({'god','admin','mod'}) and puts its admins into the
--    `qbcore.<perm>` principal, so its own ace objects resolve for them.
local function qbCoreAllowed(src)
    if not Config.FrameworkPermission then return false end
    if GetResourceState("qb-core") ~= "started" then return false end
    for _, perm in ipairs(Config.QbPermissions or {}) do
        if aceAllowed(src, perm) then return true end
    end
    return false
end

-- 3) Buyer-supplied hook. A crash in it must never open the panel.
local hookWarned = false
local function customAllowed(src)
    if type(Config.CanOpenPanel) ~= "function" then return false end
    local ok, result = pcall(Config.CanOpenPanel, src)
    if not ok then
        if not hookWarned then
            hookWarned = true
            alert(("Config.CanOpenPanel errored (%s) — treating as DENY."):format(tostring(result)))
        end
        return false
    end
    return result == true
end

-- The validated ace object (main.lua uses it in the deny log).
CDWPerm.aceObject = PANEL_ACE

-- ── Decision ─────────────────────────────────────────────────────
-- May this player open the panel / mutate weather state?
function CDWPerm.canOpen(src)
    if not src or src == 0 then return false end -- console is not a player

    if inAllowlist(src) then return true end
    if aceAllowed(src, PANEL_ACE) then return true end
    if qbCoreAllowed(src) then return true end
    if customAllowed(src) then return true end

    return false -- fail-closed
end

-- Per-layer breakdown for the debug log (Config.Debug). Never used as a gate.
function CDWPerm.explain(src)
    return ("allowlist=%s ace(%s)=%s qb-core=%s hook=%s"):format(
        tostring(inAllowlist(src)),
        PANEL_ACE, tostring(aceAllowed(src, PANEL_ACE)),
        tostring(qbCoreAllowed(src)),
        type(Config.CanOpenPanel) == "function" and tostring(customAllowed(src)) or "n/a")
end

-- Deeper diagnosis for the "I added the ace but it still denies me" case (Config.Debug only).
-- Separates the two possible causes and rules out a src type-coercion problem:
--   * ace not granted to a group  → your `add_ace ... allow` line never ran
--   * player not in that group    → your `add_principal ...` line never ran
function CDWPerm.diagnose(src)
    local lines = {
        ("  IsPlayerAceAllowed(number  %s, '%s') = %s"):format(
            tostring(src), PANEL_ACE, tostring(IsPlayerAceAllowed(src, PANEL_ACE))),
        ("  IsPlayerAceAllowed(string '%s', '%s') = %s"):format(
            tostring(src), PANEL_ACE, tostring(IsPlayerAceAllowed(tostring(src), PANEL_ACE))),
    }
    -- Is the ace object granted to a group at all?
    for _, group in ipairs({ "group.admin", "group.superadmin", "qbcore.admin", "builtin.everyone" }) do
        lines[#lines + 1] = ("  IsPrincipalAceAllowed('%s', '%s') = %s"):format(
            group, PANEL_ACE, tostring(IsPrincipalAceAllowed(group, PANEL_ACE)))
    end
    -- Is THIS player in group.admin? (group.admin normally holds the `command` wildcard,
    -- so a true here means the principal exists and only the add_ace line is missing.)
    local cmdAce = ("command.%s"):format(Config.Command)
    lines[#lines + 1] = ("  IsPlayerAceAllowed(src, '%s') = %s   <- true means you ARE in a group that has `command`")
        :format(cmdAce, tostring(IsPlayerAceAllowed(src, cmdAce)))
    lines[#lines + 1] = ("  IsPrincipalAceAllowed('group.admin', '%s') = %s"):format(
        cmdAce, tostring(IsPrincipalAceAllowed("group.admin", cmdAce)))
    return table.concat(lines, "\n")
end
