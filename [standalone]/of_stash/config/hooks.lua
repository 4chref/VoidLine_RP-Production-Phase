Hooks = {}

-- true allows, false denies, nil defers to Config.Admin.
---@type fun(source:number): boolean?
Hooks.CanUseAdminTool = nil

-- Runs after the built-in access check; false denies, nil keeps the decision.
---@type fun(source:number, stash:table): boolean?
Hooks.CanOpenStash = nil

---@type fun(action:'create'|'update'|'delete', stash:table, source:number)
Hooks.OnStashMutated = nil

---@type fun(action:'purchase'|'rent'|'renew'|'grant'|'expire', source:number, unit:table)
Hooks.OnUnitMutated = nil

---@type fun(action:'place'|'pickup', source:number, stash:table)
Hooks.OnBoxMutated = nil

--- Invoke a hook by name. Unset hooks return nil; errors are logged, never fatal.
function Hooks.run(name, ...)
    local fn = Hooks[name]
    if type(fn) ~= 'function' then return nil end
    local ok, res = pcall(fn, ...)
    if not ok then
        print(('^1[of_stash][hook:%s]^0 %s'):format(name, res))
        return nil
    end
    return res
end
