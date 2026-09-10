-- VoidLine 2026-09-02: qb-adminmenu's own staff roster.
--
-- Single source of truth for THIS resource's god/admin/moderator roles.
-- Replaces both the server.cfg `add_principal ... group.admin` grants and the
-- DB `permissions` table lookup that used to feed AdminPanel.HasPermission /
-- HasPermissionEx (see server/main.lua) -- neither is read for that purpose
-- any more. Edit server/staff.json and run /refreshstaff (or restart the
-- resource) to apply changes. staff.json is deliberately NOT in fxmanifest's
-- files{} list, so it never ships to clients.

AdminPanel = AdminPanel or {}
AdminPanel.Staff = { god = {}, admin = {}, moderator = {} }
AdminPanel.StaffIdentifierIndex = {} -- identifier string -> role name

local function BuildIdentifierIndex()
    AdminPanel.StaffIdentifierIndex = {}
    for role, list in pairs(AdminPanel.Staff) do
        for _, entry in ipairs(list) do
            for _, id in ipairs(entry.identifiers or {}) do
                AdminPanel.StaffIdentifierIndex[id] = role
            end
        end
    end
end

AdminPanel.LoadStaff = function()
    local raw = LoadResourceFile(GetCurrentResourceName(), "server/staff.json")
    if not raw then
        print("^1[919ADMIN] server/staff.json missing or unreadable -- no one will have staff access until it exists.^7")
        AdminPanel.Staff = { god = {}, admin = {}, moderator = {} }
        BuildIdentifierIndex()
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= "table" then
        print("^1[919ADMIN] server/staff.json failed to parse -- keeping the previously loaded staff table.^7")
        return
    end

    AdminPanel.Staff = {
        god = decoded.god or {},
        admin = decoded.admin or {},
        moderator = decoded.moderator or {},
    }
    BuildIdentifierIndex()

    if AdminPanel.ClearPermissionCache then
        AdminPanel.ClearPermissionCache()
    end

    print(("^2[919ADMIN] staff.json loaded (%d god, %d admin, %d moderator).^7"):format(
        #AdminPanel.Staff.god, #AdminPanel.Staff.admin, #AdminPanel.Staff.moderator))
end

-- Returns "god" / "admin" / "moderator" / nil for a connected player, by
-- matching their identifiers against the loaded staff.json table.
AdminPanel.GetStaffRole = function(src)
    local identifiers = GetPlayerIdentifiers(src)
    if not identifiers then return nil end
    for _, id in ipairs(identifiers) do
        local role = AdminPanel.StaffIdentifierIndex[id]
        if role then return role end
    end
    return nil
end

Citizen.CreateThread(function()
    AdminPanel.LoadStaff()
end)

-- Bootstrap-safe reload command: re-reads staff.json from disk directly to
-- check whether the CALLER is god, instead of going through
-- AdminPanel.GetStaffRole (which depends on the table this command is about
-- to replace). That avoids a chicken-and-egg lockout if the currently loaded
-- table is stale/wrong -- the check always reflects what's on disk right now.
RegisterCommand("refreshstaff", function(source)
    local src = source
    if src ~= 0 then
        local identifiers = GetPlayerIdentifiers(src) or {}
        local raw = LoadResourceFile(GetCurrentResourceName(), "server/staff.json")
        local isGod = false
        if raw then
            local ok, decoded = pcall(json.decode, raw)
            if ok and type(decoded) == "table" and decoded.god then
                for _, entry in ipairs(decoded.god) do
                    for _, id in ipairs(entry.identifiers or {}) do
                        for _, myId in ipairs(identifiers) do
                            if id == myId then isGod = true end
                        end
                    end
                end
            end
        end
        if not isGod then
            TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to reload staff.json.', 'error')
            return
        end
    end

    AdminPanel.LoadStaff()
    if src ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'staff.json reloaded.', 'success')
    else
        print("^2[919ADMIN] staff.json reloaded via console.^7")
    end
end, false)
