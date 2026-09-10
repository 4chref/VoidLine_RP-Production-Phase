-- GTA V only ever draws its built-in reticle in first-person view. Third
-- person free-aim (what most RP servers actually play in) shows nothing,
-- which is what this restores: the same small centered cross, drawn by hand
-- since the vanilla reticle sprite isn't something we can call directly.

local function isAiming(ped)
    return IsPlayerFreeAiming(PlayerId())
        or IsControlPressed(0, 25) -- INPUT_AIM
end

local function shouldShow(ped)
    if Config.HideInVehicle and IsPedInAnyVehicle(ped, false) then
        return false
    end

    -- First person already has its own native reticle; drawing ours on top
    -- would double up.
    if GetFollowPedCamViewMode() == 4 then
        return false
    end

    if Config.HideUnarmed then
        local weapon = GetSelectedPedWeapon(ped)
        if weapon == `WEAPON_UNARMED` then
            return false
        end
    end

    if Config.HideWhileScoped and IsFirstPersonAimCamActive() then
        return false
    end

    return isAiming(ped)
end

local function drawLine(x1, y1, x2, y2, thickness, color)
    -- DrawRect only draws axis-aligned boxes, which is all four crosshair
    -- arms need since they're always horizontal or vertical.
    local cx = (x1 + x2) / 2
    local cy = (y1 + y2) / 2
    local w = math.abs(x2 - x1)
    local h = math.abs(y2 - y1)

    if w < thickness then w = thickness end
    if h < thickness then h = thickness end

    DrawRect(cx, cy, w, h, color.r, color.g, color.b, color.a)
end

local function drawCrosshair()
    local cx, cy = 0.5, 0.5
    local gap = Config.Gap
    local len = Config.Length
    local thick = Config.Size

    local arms = {
        { cx, cy - gap - len, cx, cy - gap },         -- top
        { cx, cy + gap,       cx, cy + gap + len },   -- bottom
        { cx - gap - len, cy, cx - gap, cy },         -- left
        { cx + gap, cy,       cx + gap + len, cy },   -- right
    }

    for _, arm in ipairs(arms) do
        -- Dark backing first (slightly thicker), then the white line on top,
        -- matching the vanilla reticle's thin outline.
        drawLine(arm[1], arm[2], arm[3], arm[4], thick * 1.8, Config.OutlineColor)
        drawLine(arm[1], arm[2], arm[3], arm[4], thick, Config.Color)
    end
end

CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()

        if shouldShow(ped) then
            drawCrosshair()
        end
    end
end)
