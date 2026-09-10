-- =============================================================================
-- vl_setped
--
-- /setped swaps a player's ped model. Any model name works, but the list below
-- is what the chat autocomplete offers and what `restrictToList` can enforce.
-- =============================================================================

VLSetPed = {}

-- The custom peds shipped in resources/[assets]/vl_rust_peds. Model names come
-- from that resource's peds.meta <Name> entries, which is what actually
-- registers them with the game -- not from the .ydd filenames, though here they
-- happen to match.
--
-- That resource is started by `ensure [assets]` in server.cfg. If these ever
-- report as invalid, check that line before anything else.
VLSetPed.peds = {
    -- [assets]/vl_rust_peds
    { model = 'rust_nomad',     label = 'Rust Nomad' },
    { model = 'rust_scientist', label = 'Rust Scientist' },
    { model = 'arctic_hazmat',  label = 'Arctic Hazmat' },
    { model = 'makeshift',      label = 'Makeshift' },

    -- [assets]/vl_terminator
    { model = 't800',           label = 'T-800' },

    -- [assets]/vl_gipsy. The files shipped as "Gipsy Avenger.*" -- renamed,
    -- because a GTA model name cannot contain spaces and FiveM matches an
    -- addon ped by its filename.
    { model = 'vl_gipsy',       label = 'Gipsy Avenger' },
}

-- false = any model name is accepted, the list above is only a convenience.
-- true  = only the models above may be set.
VLSetPed.restrictToList = false

-- Write the new model into illenium-appearance so it survives.
--
-- Without this the swap lasts until the next appearance refresh and then
-- silently reverts: illenium owns the ped on this server, and going around it
-- means the next refresh undoes whatever was set. vl_clothing/client.lua
-- documents the same trap, and vl_identity hit it with its naked-spawn code.
VLSetPed.persist = true

-- Freemode peds get a default component set applied on swap, so a player turned
-- into mp_m_freemode_01 is clothed rather than invisible. Custom peds like the
-- rust ones carry their own single skin and are left alone.
VLSetPed.resetFreemodeComponents = true

-- =============================================================================
-- TALL PEDS -- camera fix
--
-- The gameplay camera sits at a fixed height above the ped's ROOT, sized for a
-- human. Put a player on a model several times that tall and the camera stays
-- down at ankle level -- you end up looking up between the model's legs.
--
-- GTA has no native that offsets the follow camera, so for these models a
-- scripted camera is rendered instead: positioned behind and above the ped,
-- aimed at its upper body, and driven by the same mouse input as normal so it
-- still feels like the ordinary third-person view.
--
-- Only models listed here get it. Everything else uses the stock camera
-- untouched -- a scripted camera is a real cost and a normal ped does not need
-- one.
-- =============================================================================

VLSetPed.tallPeds = {
    ['vl_gipsy'] = {
        -- How far above the ped's root the camera looks. Roughly the model's
        -- shoulder height -- the point the view should be centred on.
        height = 9.0,

        -- How far back it sits. A giant needs much more than a human or the
        -- model fills the whole screen.
        distance = 16.0,

        -- Extra lift applied to the camera itself, above `height`, so the view
        -- looks slightly DOWN at the model rather than dead level with it.
        lift = 3.0,

        -- ---------------------------------------------------------------
        -- MOVEMENT
        --
        -- A giant playing human walk animations looks like it is shuffling in
        -- slow motion. The animation itself is playing at normal speed -- the
        -- problem is that one human stride covers almost nothing relative to a
        -- nine-metre model, so it never seems to get anywhere.
        -- ---------------------------------------------------------------

        -- Multiplies how fast the ped actually travels.
        --
        -- KEEP THIS MODEST. It is applied on the wearer's own client only, and
        -- it changes REAL movement, not just the animation -- so the faster it
        -- is, the further the wearer's local position runs ahead of what the
        -- network has told everyone else. At 3.2 the wearer saw themselves
        -- sprinting while other players saw an ordinary walk, because the
        -- remote clients were still interpolating toward positions the wearer
        -- had already left.
        --
        -- 1.35 is a noticeable long stride that stays inside what position
        -- sync absorbs. The heavy look comes from the clipset below, which
        -- IS shared with everyone -- that is the half that should carry it.
        --
        -- Set to 1.0 to disable the speed change entirely and rely on the
        -- animation alone.
        moveRate = 1.35,

        -- A heavy, wide-strided walk instead of the default. Verified present
        -- rather than guessed: rpemotes lists this exact clipset
        -- ([standalone]/rpemotes/client/AnimationList.lua), and it only
        -- contains base-game names.
        --
        -- Other verified heavy options: move_m@muscle@a, move_m@tough_guy@,
        -- move_m@fat@a, move_m@swagger.
        clipset = 'move_m@fat@bulky',
    },
}

-- How often the tall-ped camera updates, in ms. 0 = every frame, which is what
-- makes mouse movement feel native. Raising it makes the camera visibly lag the
-- mouse, so leave it unless performance demands otherwise.
VLSetPed.tallCamTickMs = 0
