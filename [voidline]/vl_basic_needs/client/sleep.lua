SleepClient = {}

local isFainted = false
local faintThread = false
local ragdollPulseThread = false
local faintEndAt = 0
local savedCamViewMode = nil
local faintAnimLoaded = false

local function disableAllControlsThisFrame()
    DisableControlAction(0, 30, true) -- move lr
    DisableControlAction(0, 31, true) -- move fb
    DisableControlAction(0, 21, true) -- sprint
    DisableControlAction(0, 22, true) -- jump
    DisableControlAction(0, 24, true) -- attack
    DisableControlAction(0, 25, true) -- aim
    DisableControlAction(0, 45, true) -- reload
    DisableControlAction(0, 23, true) -- enter/exit vehicle
    DisableControlAction(0, 71, true) -- vehicle accel
    DisableControlAction(0, 72, true) -- vehicle brake
    DisableControlAction(0, 63, true) -- vehicle steer left
    DisableControlAction(0, 64, true) -- vehicle steer right
    DisableControlAction(0, 59, true) -- vehicle steer axis
    DisableControlAction(0, 60, true) -- vehicle move axis
    DisableControlAction(0, 75, true) -- exit vehicle
    DisableControlAction(0, 140, true) -- melee
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 143, true)
    DisableControlAction(0, 2, true) -- cycle camera view (V) -- keep it locked in first person
end

local function loadAnimDictSafely(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

--- Forces first-person and a heavy blur/darken so being fainted actually
--- feels like drifting in and out of sleep, rather than a flat black screen.
local function applySleepyVision()
    savedCamViewMode = GetFollowPedCamViewMode()
    SetFollowPedCamViewMode(4) -- first person

    TriggerScreenblurFadeIn(1500.0)
    AnimpostfxPlay('DeathFailOut', 0, true) -- built-in dim/desaturate effect

    -- Extra darkness on top of the post effect -- DeathFailOut alone is more
    -- desaturated than dark. spectator1 is a heavily darkened timecycle used
    -- by several unconscious/spectator implementations for exactly this.
    -- This used to be layered with an additional full-screen NUI black+blur
    -- overlay (web/sleep_overlay.html), removed 2026-08-30 -- it was this
    -- resource's only ui_page, so it loaded and rendered immediately on every
    -- resource start regardless of faint state, causing a stuck black screen
    -- on every login. Native effects only now; they can't get stuck as a
    -- persistent full-screen layer the way an eagerly-loaded NUI page can.
    SetTimecycleModifier('spectator1')
    SetTimecycleModifierStrength(1.0)
end

local function restoreVision()
    TriggerScreenblurFadeOut(1000.0)
    AnimpostfxStop('DeathFailOut')
    ClearTimecycleModifier()

    if savedCamViewMode then
        SetFollowPedCamViewMode(savedCamViewMode)
        savedCamViewMode = nil
    end
end

--- Fallback used only if the faint animation dict fails to load: keeps
--- refreshing ragdoll every frame so there is never a gap for the engine's
--- own get-up task to start in.
local function startRagdollPulse()
    ragdollPulseThread = true
    CreateThread(function()
        while ragdollPulseThread do
            local ped = PlayerPedId()
            if not IsPedFatallyInjured(ped) and not IsEntityDead(ped) then
                SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
            end
            Wait(0)
        end
    end)
end

--- Keeps the faint animation looping. TaskPlayAnim with flag 1 already loops
--- on its own, but this re-issues it if anything (a hit, another script)
--- knocks the ped out of it, so they never end up standing mid-faint.
local function startAnimKeepAlive(dict, anim)
    ragdollPulseThread = true
    CreateThread(function()
        while ragdollPulseThread do
            local ped = PlayerPedId()
            if not IsPedFatallyInjured(ped) and not IsEntityDead(ped)
                and not IsEntityPlayingAnim(ped, dict, anim, 3) then
                TaskPlayAnim(ped, dict, anim, 3.0, -3.0, -1, 1, 0, false, false, false)
            end
            Wait(500)
        end
    end)
end

--- Everything between the fade-out and fade-in, isolated so a pcall around
--- it can guarantee the fade-in always runs -- an uncaught error anywhere in
--- here previously meant the coroutine just died mid-sequence with the
--- screen left permanently faded to black, no error visible in-game.
local function runFaintBody(ped)
    local dict, anim = Config.Sleep.faintAnim.dict, Config.Sleep.faintAnim.anim
    faintAnimLoaded = loadAnimDictSafely(dict)

    if faintAnimLoaded then
        -- Ends the ragdoll ourselves by handing the ped a new task before its
        -- timer runs out, so it blends straight into this animation instead
        -- of the engine's own get-up-from-ragdoll transition.
        ClearPedTasksImmediately(ped)
        TaskPlayAnim(ped, dict, anim, 3.0, -3.0, -1, 1, 0, false, false, false)
        startAnimKeepAlive(dict, anim)
    else
        -- Dict failed to load (e.g. stripped game build) -- fall back to the
        -- brute-force ragdoll refresh so the player still stays down.
        startRagdollPulse()
    end

    FreezeEntityPosition(ped, true) -- locks world position only, not the pose

    applySleepyVision()
end

local function beginFaintSequence(duration)
    if isFainted then return end
    isFainted = true
    faintThread = true
    faintEndAt = GetGameTimer() + duration

    local ped = PlayerPedId()

    if not IsPedFatallyInjured(ped) and not IsEntityDead(ped) then
        SetPedToRagdoll(ped, 1200, 1200, 0, false, false, false)
        Wait(1200)
    end

    DoScreenFadeOut(600)
    -- Timeout-guarded like loadAnimDictSafely above: if this fires shortly
    -- after login (e.g. saved sleep was already ~99 and the first decay tick
    -- pushes it over criticalThreshold), it can race the player's own spawn
    -- fade-in. When that happens IsScreenFadingOut() can get stuck reporting
    -- true forever, which used to hang this loop before it ever reached the
    -- fade-in below -- leaving the screen permanently black with only the
    -- HUD visible. Cap the wait so it always proceeds.
    local fadeOutTimeout = GetGameTimer() + 3000
    while IsScreenFadingOut() and GetGameTimer() < fadeOutTimeout do Wait(0) end

    local ok, err = pcall(runFaintBody, PlayerPedId())
    if not ok then
        print(('[basic_needs] faint sequence error, forcing fade-in to avoid a stuck black screen: %s'):format(tostring(err)))
    end

    DoScreenFadeIn(600) -- fade back in to the blurred/dark view, not pure black -- ALWAYS runs, error or not

    CreateThread(function()
        local camCheckAt = 0
        while faintThread do
            disableAllControlsThisFrame()

            -- Re-assert first-person every half second in case anything else
            -- (another script, a cutscene camera) resets the view mode.
            local now = GetGameTimer()
            if now >= camCheckAt then
                SetFollowPedCamViewMode(4)
                camCheckAt = now + 500
            end

            Wait(0)
        end
    end)

    Wait(duration)

    if isFainted then
        SleepClient.EndFaint()
    end
end

function SleepClient.EndFaint()
    if not isFainted then return end
    faintThread = false
    ragdollPulseThread = false
    isFainted = false
    faintEndAt = 0

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    if faintAnimLoaded then
        local dict, anim = Config.Sleep.faintAnim.dict, Config.Sleep.faintAnim.anim
        StopAnimTask(ped, dict, anim, 1.0)
        RemoveAnimDict(dict)
        faintAnimLoaded = false
    elseif IsPedRagdoll(ped) then
        ClearPedTasksImmediately(ped)
    end

    restoreVision()
end

RegisterNetEvent('basic_needs:client:startFaint', function(duration)
    if isFainted then return end
    CreateThread(function()
        beginFaintSequence(duration)
    end)
end)

RegisterNetEvent('basic_needs:client:endFaint', function()
    SleepClient.EndFaint()
end)

function SleepClient.IsFainted()
    return isFainted
end

--- Milliseconds remaining until the player wakes up, 0 if not fainted.
--- Used by vl_hud to draw a countdown over the sleep icon.
function SleepClient.GetFaintRemainingMs()
    if not isFainted then return 0 end
    return math.max(0, faintEndAt - GetGameTimer())
end

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    if isFainted then
        SleepClient.EndFaint()
    end
end)
