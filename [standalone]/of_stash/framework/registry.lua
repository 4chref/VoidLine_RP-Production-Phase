Bridge = { candidates = { framework = {}, inventory = {}, target = {}, notify = {} } }

--- Register an adapter candidate.
---@param kind 'framework'|'inventory'|'target'|'notify'
---@param def { name:string, priority?:number, detect:fun():boolean, build:fun():table }
function Bridge.register(kind, def)
    local bucket = Bridge.candidates[kind]
    if not bucket then error(('of_stash: unknown bridge kind "%s"'):format(tostring(kind))) end
    def.priority = def.priority or 0
    bucket[#bucket + 1] = def
end

--- True when a resource is present and running.
---@param resource string
---@return boolean
function Bridge.started(resource)
    return GetResourceState(resource) == 'started'
end

--- Resolve one adapter for a kind.
---@param kind 'framework'|'inventory'|'target'|'notify'
---@param configured string  -- 'auto' or a specific candidate name
---@return table? adapter, string? name
function Bridge.resolve(kind, configured)
    local bucket = Bridge.candidates[kind]
    if not bucket then return nil end

    if configured and configured ~= 'auto' then
        for _, def in ipairs(bucket) do
            if def.name == configured then return def.build(), def.name end
        end
        print(('^3[of_stash]^0 %s "%s" is not a known adapter; falling back to auto.'):format(kind, configured))
    end

    local best
    for _, def in ipairs(bucket) do
        if def.detect() and (not best or def.priority > best.priority) then best = def end
    end
    if best then return best.build(), best.name end
    return nil
end
