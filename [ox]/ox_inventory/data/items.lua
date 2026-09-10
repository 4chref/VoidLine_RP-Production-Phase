return {
    ['testburger'] = {
        label = 'Test Burger',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'Lick it',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'Squeeze it',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'What do you call a vegan burger?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'What do frogs like to eat with their hamburgers?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'Why were the burger and fries running?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    ['bandage'] = {
        label = 'Bandage',
        weight = 115,
    },

    -- VoidLine: replays the intake identity reveal and returns the character to
    -- the exact spawn point they first stood on. Registered here rather than in
    -- avp_grid_inventory because the AVP player grid is a projection of
    -- ox_inventory -- an item ox has never heard of is refused by CanCarryItem
    -- and cannot exist in the grid at all.
    --
    -- consume = 0 and the removal is done in vl_identity's server handler:
    -- ox dispatches a client.export item with `return data.export(...)` in
    -- useSlot, before the consume path, so ox would never take it.
    ['pill'] = {
        label = 'Pill',
        weight = 5,
        -- Single use: one per slot, and the server removes it the moment it is
        -- swallowed. Not stackable so a stack of them can never survive a use
        -- and read as "the pill was not consumed".
        stack = false,
        close = true,
        consume = 0,
        description = 'Swallow to remember who you are, and where you woke up.',
        client = {
            image = 'pill.png',
            export = 'vl_identity.usePill',
        },
    },

    ['burger'] = {
        label = 'Burger',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'You ate a delicious burger'
        },
    },

    ['sprunk'] = {
        label = 'Sprunk',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'You quenched your thirst with a sprunk'
        }
    },

    ['parachute'] = {
        label = 'Parachute',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Knickers',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 160,
    },

    ['phone'] = {
        label = 'Phone',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,

            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['mustard'] = {
        label = 'Mustard',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You... drank mustard'
        }
    },

    ['water'] = {
        label = 'Water',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'You drank some refreshing water'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Clothing',
        consume = 0,
    },

    ['money'] = {
        label = 'Money',
    },

    ['black_money'] = {
        label = 'Dirty Money',
    },

    -- VoidLine: kitchen ration pack (vl_kitchen). Status is on ox_lib's
    -- 0-1,000,000 scale, so 400000 = 40%. For comparison, the stock sandwich
    -- above uses 200000 = 20%.
    ['canned_chicken_soup'] = {
        label = 'Canned Chicken Soup',
        weight = 200,
        description = 'Cold, salty, and still edible after all these years.',
        client = {
            status = { hunger = 400000 },
            anim = 'eating',
            prop = { model = `prop_sandwich_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 2500,
            notification = 'You ate the chicken soup'
        },
    },

    ['canned_tuna'] = {
        label = 'Canned Tuna',
        weight = 200,
        description = 'Packed in oil. Heavy, filling, and it keeps forever.',
        client = {
            status = { hunger = 400000 },
            anim = 'eating',
            prop = { model = `prop_sandwich_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 2500,
            notification = 'You ate the tuna'
        },
    },

    ['water_bottle'] = {
        label = 'Water Bottle',
        weight = 200,
        description = 'Filtered, bottled, and worth more than most things.',
        client = {
            status = { thirst = 400000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            notification = 'You drank the water'
        },
    },

    ['watermelon_punch'] = {
        label = 'Watermelon Punch',
        weight = 500,
        description = 'Sickly sweet. Nobody asks what is actually in it.',
        client = {
            status = { thirst = 400000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            notification = 'You drank the punch'
        },
    },

    -- VoidLine: item-based currency replacing pocket cash. Weight is 0 to match
    -- the `money` item it stands in for -- players carry these in the thousands,
    -- so any per-unit weight eats the whole inventory. Image is
    -- web/images/core.png.
    ['core'] = {
        label = 'Core',
        weight = 0,
        description = 'Minted after the collapse. The only currency anyone still honours.',
    },

    ['id_card'] = {
        label = 'Identification Card',
    },

    ['driver_license'] = {
        label = 'Drivers License',
    },

    ['weaponlicense'] = {
        label = 'Weapon License',
    },

    ['lawyerpass'] = {
        label = 'Lawyer Pass',
    },

    ['jammer'] = {
        label = 'Radio Jammer',
        weight = 10000,
        allowArmed = true,
        -- VoidLine: mm_radio was removed in favour of vl_dusa_radio, which has no
        -- jammer feature. The event it pointed at no longer exists, so it is
        -- stripped rather than left firing into nothing. The item is KEPT so
        -- any already in a player's inventory are not purged on load.
    },

    ['radiocell'] = {
        label = 'AAA Cells',
        weight = 1000,
        stack = true,
        allowArmed = true,
        -- VoidLine: dead mm_radio event stripped, see 'jammer' above.
    },

    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Screwdriver Set',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Electronic Kit',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'Cleaning Kit',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Repair Kit',
        weight = 2500,
    },

    ['advancedrepairkit'] = {
        label = 'Advanced Repair Kit',
        weight = 4000,
    },

    ['diamond_ring'] = {
        label = 'Diamond',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Crack Baggy',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Bag of Coke',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'Coke Brick',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Coke Package',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Bag of Ecstasy',
        weight = 100,
    },

    ['meth'] = {
        label = 'Methamphetamine',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Oxycodone',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'AK47 2g',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'Skunk 2g',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'Amnesia 2g',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'Amnesia Seed',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'OGKush Seed',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'White Widow Seed',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'Purple Haze 2g',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'Purple Haze Seed',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'Weed Brick',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Plant Fertilizer',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Joint',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Rolling Paper',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
    },

    ['firstaid'] = {
        label = 'First Aid',
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'Individual First Aid Kit',
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'Painkillers',
        weight = 400,
    },

    ['firework1'] = {
        label = '2Brothers',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Poppelers',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'WipeOut',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Weeping Willow',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Steel',
        weight = 100,
    },

    ['rubber'] = {
        label = 'Rubber',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Metal Scrap',
        weight = 100,
    },

    ['iron'] = {
        label = 'Iron',
        weight = 100,
    },

    ['copper'] = {
        label = 'Copper',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'Aluminium',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Plastic',
        weight = 100,
    },

    ['glass'] = {
        label = 'Glass',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Gatecrack',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'Crypto Stick',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'Trojan USB',
        weight = 100,
    },

    ['toaster'] = {
        label = 'Toaster',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Small TV',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Security Card A',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Security Card B',
        weight = 100,
    },

    ['drill'] = {
        label = 'Drill',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Thermite',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Diving Gear',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Diving Tube',
        weight = 3000,
    },

    -- VoidLine: vl_outpost (was vl_suitshop, merged 2026-09-02) -- not consumed
    -- on use: toggles the wearer's ped
    -- model on/off, restoring the exact prior appearance on the second use
    -- (see client/main.lua there). Icons expected at web/images/<name>.png
    -- -- not shipped with the resource, add them manually.
    ['rust_scientist'] = {
        label = 'Scientist Hazmat Suit',
        weight = 5000,
        consume = 0,
        stack = false,
        description = 'Protects you from radiation.',
        client = {
            export = 'vl_outpost.rust_scientist',
        },
    },

    ['rust_nomad'] = {
        label = 'Nomad Suit',
        weight = 5000,
        consume = 0,
        stack = false,
        description = 'Protects you from dust.',
        client = {
            export = 'vl_outpost.rust_nomad',
        },
    },

    ['arctic_hazmat'] = {
        label = 'Arctic Suit',
        weight = 5000,
        consume = 0,
        stack = false,
        description = 'Protects you from low temperatures.',
        client = {
            export = 'vl_outpost.arctic_hazmat',
        },
    },

    -- VoidLine: qbx_divegear/qbx_diving retired in favour of vl_diving_gear
    -- (see server.cfg near `ensure [qbx]`) -- this is that resource's item,
    -- not the old diving_gear/diving_fill above (left in place so anyone
    -- still holding one doesn't end up with an unknown item).
    ['scuba_tank'] = {
        label = 'Scuba Tank',
        weight = 4000,
        stack = false,
        consume = 1,
        description = 'A full oxygen tank and mask for diving underwater.',
        client = {
            export = 'vl_diving_gear.scuba_tank',
        },
    },

    ['antipatharia_coral'] = {
        label = 'Antipatharia',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'Dendrogyra',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'Jerrycan',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Nitrous',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Wine',
        weight = 500,
    },

    ['grape'] = {
        label = 'Grape',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Grape Juice',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Coffee',
        weight = 200,
    },

    ['vodka'] = {
        label = 'Vodka',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Whiskey',
        weight = 200,
    },

    ['beer'] = {
        label = 'Beer',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Sandwich',
        weight = 200,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = { model = `prop_sandwich_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 2500,
            notification = 'You ate a sandwich'
        },
    },

    ['notepad'] = {
        label = 'Notepad',
        weight = 100,
    },

    ['walking_stick'] = {
        label = 'Walking Stick',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'Lighter',
        weight = 200,
    },

    -- Added for the vl_dailygoods vendor. No cigarette item existed anywhere on
    -- this server, so the shop had nothing to sell; registered here alongside
    -- 'lighter' rather than in the shop resource, so anything else can use it.
    ['cigarette'] = {
        label = 'Cigarette',
        weight = 5,
    },

    -- PLACEHOLDERS for vl_outpost's pet shop, so it is demonstrably working.
    -- Rename or replace these with the real pet items when you have them; the
    -- shop reads its list from vl_outpost/shared/config.lua and needs no code
    -- change to follow.
    ['pet_food'] = {
        label = 'Pet Food',
        weight = 300,
    },

    ['pet_collar'] = {
        label = 'Pet Collar',
        weight = 100,
    },

    ['pet_toy'] = {
        label = 'Pet Toy',
        weight = 150,
    },

    ['binoculars'] = {
        label = 'Binoculars',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Sticky Note',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Empty Evidence Bag',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'Filled Evidence Bag',
        weight = 200,
    },

    ['harness'] = {
        label = 'Harness',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Handcuffs',
        weight = 200,
    },
     ['radio'] = {
        label = 'Radio',
        weight = 1000,
        stack = false,
        close = true,
        description = 'A handheld radio.',
    },
    
    ['police_radio'] = {
        label = 'Police Radio',
        weight = 1000,
        stack = false,
        close = true,
        description = 'A police radio for law enforcement channels.',
    },
    
    ['ems_radio'] = {
        label = 'EMS Radio',
        weight = 1000,
        stack = false,
        close = true,
        description = 'An EMS radio for medical service channels.',
    },

    -- of_stash deployable boxes. Using one of these drops a crate in the world
    -- that becomes a stash; the item comes back when it is picked up empty.
    -- The keys must match Config.Boxes.sizes[].item in of_stash/config/config.lua.
    ['stash_box_small'] = {
        label = 'Small Storage Box',
        weight = 2000,
        stack = false,
        close = true,
        description = 'A small crate. Use it to place a personal stash you can share with others.',
        client = { export = 'of_stash.useStashBox' }
    },

    ['stash_box_medium'] = {
        label = 'Medium Storage Box',
        weight = 4000,
        stack = false,
        close = true,
        description = 'A medium crate. Use it to place a personal stash you can share with others.',
        client = { export = 'of_stash.useStashBox' }
    },

    ['stash_box_large'] = {
        label = 'Large Storage Box',
        weight = 7000,
        stack = false,
        close = true,
        description = 'A large crate. Use it to place a personal stash you can share with others.',
        client = { export = 'of_stash.useStashBox' }
    },

    -- =========================================================================
    -- VoidLine: wearable clothing.
    --
    -- Using one puts it on, using it again takes it off (vl_clothing/client.lua).
    -- `consume = 0` is what stops ox eating the garment on use.
    --
    -- `wearComponent` = SetPedComponentVariation slot, `wearProp` =
    -- SetPedPropIndex slot. They are NOT called `component`/`prop`: ox already
    -- uses client.component for weapon attachments (client.lua:657) and
    -- client.prop for use-animation props (client.lua:374), and shadowing
    -- either breaks those.
    -- drawable/texture are freemode indices and differ between the male and
    -- female ped, so a garment may look different on each -- adjust per item.
    -- Components 0 and 2 (face, hair) are refused by illenium on freemode peds
    -- and deliberately have no items here.
    -- =========================================================================

    ['clothing_mask'] = {
        label = 'Mask',
        weight = 150,
        consume = 0,
        stack = false,
        description = 'Covers the face. Wear it or take it off.',
        -- Root-level marker: ox strips `client` from item definitions on the
        -- server (modules/items/shared.lua), so the server cannot see the
        -- export name. This survives on both sides.
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 1, drawable = 52, texture = 0 },
    },

    ['clothing_tshirt'] = {
        label = 'T-Shirt',
        weight = 200,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 11, drawable = 3, texture = 0 },
    },

    ['clothing_hoodie'] = {
        label = 'Hoodie',
        weight = 400,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 11, drawable = 8, texture = 0 },
    },

    ['clothing_vest'] = {
        label = 'Vest',
        weight = 900,
        consume = 0,
        stack = false,
        description = 'Worn over the torso. Cosmetic -- this is not body armour.',
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 9, drawable = 1, texture = 0 },
    },

    ['clothing_pants'] = {
        label = 'Trousers',
        weight = 350,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 4, drawable = 1, texture = 0 },
    },

    ['clothing_shoes'] = {
        label = 'Boots',
        weight = 500,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 6, drawable = 25, texture = 0 },
    },

    ['clothing_backpack'] = {
        label = 'Backpack',
        weight = 800,
        consume = 0,
        stack = false,
        description = 'Cosmetic only -- it does not add carrying capacity.',
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 5, drawable = 45, texture = 0 },
    },

    ['clothing_hat'] = {
        label = 'Cap',
        weight = 120,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearProp = 0, drawable = 8, texture = 0 },
    },

    ['clothing_glasses'] = {
        label = 'Sunglasses',
        weight = 80,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearProp = 1, drawable = 5, texture = 0 },
    },

    ['clothing_watch'] = {
        label = 'Watch',
        weight = 100,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearProp = 6, drawable = 3, texture = 0 },
    },

    -- Remaining slots, so every wearable component/prop has an item.
    -- Set names follow j_clothe's coverage (torso, tshirt, arms, jeans, shoes,
    -- bag, chain, mask, helmet, ears, watches, glasses, bracelet).

    ['clothing_undershirt'] = {
        label = 'Undershirt',
        weight = 150,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 8, drawable = 15, texture = 0 },
    },

    ['clothing_gloves'] = {
        label = 'Gloves',
        weight = 100,
        consume = 0,
        stack = false,
        description = 'Worn on the arms -- gloves share the arm component in GTA.',
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 3, drawable = 4, texture = 0 },
    },

    ['clothing_chain'] = {
        label = 'Chain',
        weight = 90,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearComponent = 7, drawable = 1, texture = 0 },
    },

    ['clothing_earrings'] = {
        label = 'Earrings',
        weight = 40,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearProp = 2, drawable = 2, texture = 0 },
    },

    ['clothing_bracelet'] = {
        label = 'Bracelet',
        weight = 60,
        consume = 0,
        stack = false,
        wearable = true,
        client = { export = 'vl_clothing.wear', wearProp = 7, drawable = 1, texture = 0 },
    },

    -- VoidLine: af-pager. Using it opens the pager UI; pages are addressed by
    -- the pager ID af-pager assigns to each character.
    --
    -- NOTE THE TWO ABSENT KEYS -- both omissions are load-bearing.
    --
    -- No `client.export`: af-pager registers its use handler through qbx_core's
    -- CreateUseableItem, and ox_inventory only reaches that (server.lua:495 ->
    -- modules/bridge/qbx/server.lua:39, server.UseItem) for items with no
    -- client handler of their own.
    --
    -- No `consume = 0` either, which is the non-obvious one. In server.lua the
    -- `elseif consume then` branch is tested BEFORE the server.UseItem branch,
    -- and 0 is truthy in Lua -- so `consume = 0` sends the item down ox's
    -- internal path and af-pager is never called. Leaving consume nil is also
    -- what stops the pager being eaten: that branch returns immediately after
    -- dispatching, before anything is removed.
    ['pager'] = {
        label = 'Pager',
        weight = 120,
        stack = false,
        close = true,
        description = 'Send and receive short messages by pager ID.',
    },

    -- af-expeditions. Given by searching corpse_dock_1 during a cargo_ship
    -- expedition and consumed to open the sealed crate -- without it that
    -- expedition cannot be completed. Definition copied verbatim from
    -- af-expeditions/ITEMS.txt.
    ['container_key'] = {
        label = 'Container Key',
        weight = 50,
        stack = false,
        close = true,
        description = 'Rusted key from a dock worker. Opens a sealed crate.',
    },

    -- af-gps. Same CreateUseableItem hook pattern as af-pager above: no
    -- client.export and no consume, so ox_inventory routes the use through
    -- qbx_core -> af-gps/server/main.lua.
    ['gps'] = {
        label = 'GPS',
        weight = 300,
        stack = false,
        close = true,
        description = 'Handheld GPS terminal. Shows your live position on a radar map.',
    },

    ['pager_antenna'] = {
        label = 'Relay Antenna',
        weight = 8000,
        stack = true,
        close = true,
        description = 'Deployable relay tower. Extends pager coverage by 1500m.',
    },

    -- =========================================================================
    -- [af] resource pack: camping, farming, furnaces, gathering, recycler.
    -- Definitions taken from each resource's SETUP.txt / readme.txt.
    -- Icons live in web/images and were shipped by the resources themselves.
    -- =========================================================================

    ['beef'] = {
        label = 'Beef',
        weight = 300,
        stack = true,
    },

    ['coffe_beans'] = {
        label = 'Coffee Beans',
        weight = 50,
        stack = true,
    },

    ['corn'] = {
        label = 'Corn',
        weight = 120,
        stack = true,
    },

    ['eggs'] = {
        label = 'Eggs',
        weight = 80,
        stack = true,
    },

    ['garlic'] = {
        label = 'Garlic',
        weight = 40,
        stack = true,
    },

    ['mushrooms'] = {
        label = 'Mushrooms',
        weight = 100,
        stack = true,
    },

    ['onion'] = {
        label = 'Onion',
        weight = 90,
        stack = true,
    },

    ['parsley'] = {
        label = 'Parsley',
        weight = 30,
        stack = true,
    },

    ['potatos'] = {
        label = 'Potatoes',
        weight = 150,
        stack = true,
    },

    ['potatos_carrots'] = {
        label = 'Potatoes & Carrots',
        weight = 180,
        stack = true,
    },

    ['raw_chicken'] = {
        label = 'Raw Chicken',
        weight = 250,
        stack = true,
    },

    ['raw_fish'] = {
        label = 'Raw Fish',
        weight = 220,
        stack = true,
    },

    ['salt'] = {
        label = 'Salt',
        weight = 20,
        stack = true,
    },

    ['grilled_fish'] = {
        label = 'Grilled Fish',
        weight = 220,
        stack = true,
        close = true,
    },

    ['roasted_chicken'] = {
        label = 'Roasted Chicken',
        weight = 280,
        stack = true,
        close = true,
    },

    ['mushroom_soup'] = {
        label = 'Mushroom Soup',
        weight = 350,
        stack = true,
        close = true,
    },

    ['soup'] = {
        label = 'Vegetable Soup',
        weight = 350,
        stack = true,
        close = true,
    },

    ['stew'] = {
        label = 'Stew',
        weight = 450,
        stack = true,
        close = true,
    },

    ['grilled_vegetables'] = {
        label = 'Grilled Vegetables',
        weight = 300,
        stack = true,
        close = true,
    },

    ['coffe'] = {
        label = 'Coffee',
        weight = 200,
        stack = true,
        close = true,
    },

    ['tent_01'] = {
        label = 'Small Tent',
        weight = 5000,
        stack = false,
        close = true,
        description = 'Place a small camping tent.',
    },

    ['tent_02'] = {
        label = 'Medium Tent',
        weight = 6500,
        stack = false,
        close = true,
        description = 'Place a medium camping tent.',
    },

    ['tent_03'] = {
        label = 'Large Tent',
        weight = 8000,
        stack = false,
        close = true,
        description = 'Place a large camping tent.',
    },

    ['campfire'] = {
        label = 'Campfire',
        weight = 3000,
        stack = false,
        close = true,
        description = 'Place a campfire to cook food.',
    },

    ['water_catcher'] = {
        label = 'Water Catcher',
        weight = 4500,
        stack = false,
        close = true,
        description = 'Place a barrel to collect rainwater.',
    },

    ['camp_stash'] = {
        label = 'Camp Stash',
        weight = 5000,
        stack = false,
        close = true,
        description = 'Place a storage chest linked to ox_inventory.',
    },

    ['camp_chair'] = {
        label = 'Camp Chair',
        weight = 2500,
        stack = false,
        close = true,
        description = 'Place a camping chair. Use target to sit.',
    },

    ['camp_table'] = {
        label = 'Camp Table',
        weight = 4000,
        stack = false,
        close = true,
        description = 'Place a camping table.',
    },

    ['camp_bed'] = {
        label = 'Camp Bed',
        weight = 6000,
        stack = false,
        close = true,
        description = 'Place a camping bed. Use target to sleep and recover health.',
    },

    ['barbed_wire'] = {
        label = 'Barbed Wire',
        weight = 3500,
        stack = false,
        close = true,
        description = 'Place a barbed wire barrier.',
    },

    ['palisade'] = {
        label = 'Palisade',
        weight = 5000,
        stack = false,
        close = true,
        description = 'Place a wooden palisade barrier.',
    },

    ['gate'] = {
        label = 'Gate',
        weight = 6500,
        stack = false,
        close = true,
        description = 'Place a gate with hinged doors.',
    },

    ['planter_small'] = {
        label = 'Small Planter',
        weight = 8000,
        stack = false,
        close = true,
        description = 'Planter with 3 slots. The first planter in a zone creates the farm.',
    },

    ['planter_large'] = {
        label = 'Large Planter',
        weight = 15000,
        stack = false,
        close = true,
        description = 'Planter with 9 slots.',
    },

    ['waterpump'] = {
        label = 'Water Pump',
        weight = 12000,
        stack = false,
        close = true,
        description = 'Feeds sprinklers through piping (max 8). Must be placed in water.',
    },

    ['water_tank'] = {
        label = 'Water Tank',
        weight = 10000,
        stack = false,
        close = true,
        description = 'Feeds sprinklers through piping (max 8). Can be placed anywhere on the farm.',
    },

    ['sprinkler'] = {
        label = 'Sprinkler',
        weight = 3000,
        stack = false,
        close = true,
        description = 'Hydrates plants in range when connected to a pump.',
    },

    ['water_splitter'] = {
        label = 'Water Splitter',
        weight = 4000,
        stack = false,
        close = true,
        description = 'Splits water: 1 inlet, 3 outlets.',
    },

    ['water_cable'] = {
        label = 'Water Cable',
        weight = 500,
        stack = true,
        close = true,
        description = 'Use in the inventory to enter piping mode and link pump, splitter and sprinkler.',
    },

    ['fertilizer'] = {
        label = 'Fertilizer',
        weight = 300,
        stack = true,
        close = true,
        description = 'Fertilises plants in a planter (+25% nutrients per use).',
    },

    ['tomato'] = {
        label = 'Tomato',
        weight = 100,
        stack = true,
    },

    ['potato'] = {
        label = 'Potato',
        weight = 80,
        stack = true,
    },

    ['pumpkin'] = {
        label = 'Pumpkin',
        weight = 2000,
        stack = true,
    },

    ['potato_seed'] = {
        label = 'Potato Seeds',
        weight = 10,
        stack = true,
    },

    ['pumpkin_seed'] = {
        label = 'Pumpkin Seeds',
        weight = 10,
        stack = true,
    },

    ['tomato_seed'] = {
        label = 'Tomato Seeds',
        weight = 10,
        stack = true,
    },

    ['corn_seed'] = {
        label = 'Corn Seeds',
        weight = 10,
        stack = true,
    },

    ['wood'] = {
        label = 'Wood',
        weight = 500,
        stack = true,
    },

    ['stone'] = {
        label = 'Stone',
        weight = 800,
        stack = true,
    },

    ['metal_ore'] = {
        label = 'Metal Ore',
        weight = 900,
        stack = true,
    },

    ['sulfur_ore'] = {
        label = 'Sulfur Ore',
        weight = 700,
        stack = true,
    },

    ['hqm_ore'] = {
        label = 'High Quality Metal Ore',
        weight = 1200,
        stack = true,
    },

    ['metal'] = {
        label = 'Metal',
        weight = 600,
        stack = true,
    },

    ['sulfur'] = {
        label = 'Sulfur',
        weight = 400,
        stack = true,
    },

    ['hqm'] = {
        label = 'High Quality Metal',
        weight = 1000,
        stack = true,
    },

    ['small_furnace'] = {
        label = 'Small Furnace',
        weight = 9000,
        stack = false,
        close = true,
        description = 'Place a small furnace to smelt ore.',
    },

    ['large_furnace'] = {
        label = 'Large Furnace',
        weight = 18000,
        stack = false,
        close = true,
        description = 'Place a large furnace to smelt ore.',
    },

    ['recycler'] = {
        label = 'Recycler',
        weight = 12000,
        stack = false,
        close = true,
        description = 'Place a portable recycler to break items down into materials.',
    },

    -- af-gathering tools. The names are NOT configurable -- config.lua only
    -- documents them ("pickaxe and axe are the names of the item tools") and the
    -- logic that checks for them is escrowed, so these two names are fixed.
    ['axe'] = {
        label = 'Axe',
        weight = 2500,
        stack = false,
        description = 'Used to chop trees for wood.',
    },

    ['pickaxe'] = {
        label = 'Pickaxe',
        weight = 3000,
        stack = false,
        description = 'Used to mine stone, sulfur and metal nodes.',
    },

    -- =========================================================================
    -- af-basebuilding.
    --
    -- Names taken from af-basebuilding/README.txt and are NOT configurable --
    -- the placement logic that looks them up is escrowed (shared/pieces.lua is
    -- FXAP-encrypted), so a rename silently breaks building.
    --
    -- wood / stone / metal / hqm are deliberately absent here: they already
    -- exist further up, added for af-gathering, and both scripts use the same
    -- four names. One definition, two consumers.
    -- =========================================================================

    ['hammer'] = {
        label = 'Building Hammer',
        weight = 1000,
        stack = false,
        close = true,
        description = 'Upgrade, repair, rotate and demolish base pieces.',
    },

    ['building_plan'] = {
        label = 'Building Plan',
        weight = 500,
        stack = false,
        close = true,
        description = 'Blueprint tool. Place foundations, walls, ceilings and stairs.',
    },

    ['tool_cupboard'] = {
        label = 'Tool Cupboard',
        weight = 500,
        stack = true,
        close = true,
        close = true,
        description = 'Claims a 40m build radius and stores the upkeep material for the base.',
    },

    ['codepad'] = {
        label = 'Code Lock',
        weight = 500,
        stack = true,
        close = true,
        description = 'Fit to a door. Default code is 0000 -- change it after placing.',
    },

    ['largewood_box'] = {
        label = 'Large Wood Box',
        weight = 500,
        stack = true,
        close = true,
        close = true,
        description = 'Deployable storage container.',
    },

    -- Sentry gun. Not listed in README.txt like the rest of this block, so the
    -- key name is unverified against the escrowed pieces.lua lookup -- if
    -- placement doesn't work with this exact name, get the confirmed item key
    -- from the seller (same way every other af-basebuilding name here did).
    -- Tuning (fire rate, damage, max per base) lives in shared/config.lua's
    -- Config.Sentry, which is NOT escrowed.
    ['sentry_gun'] = {
        label = 'Sentry Gun',
        weight = 2000,
        stack = false,
        close = true,
        description = 'Automated turret. Place it to defend a base -- fires on hostiles in its firing arc.',
    },

    -- Doors and windows
    ['wood_door'] = { label = 'Wood Door', weight = 500, stack = true, close = true },
    ['metal_door'] = { label = 'Metal Door', weight = 500, stack = true, close = true },
    ['hqm_door'] = { label = 'HQM Door', weight = 500, stack = true, close = true },
    ['garage_door'] = { label = 'Garage Door', weight = 500, stack = true, close = true },
    ['metal_shopfront'] = { label = 'Metal Shopfront', weight = 500, stack = true, close = true },
    ['metal_shutter_a'] = { label = 'Metal Shutter A', weight = 500, stack = true, close = true },
    ['metal_shutter_b'] = { label = 'Metal Shutter B', weight = 500, stack = true, close = true },
    ['window_glass'] = { label = 'Window Glass', weight = 500, stack = true, close = true },
    ['wood_window_bars'] = { label = 'Wood Window Bars', weight = 500, stack = true, close = true },
    ['metal_window_bars'] = { label = 'Metal Window Bars', weight = 500, stack = true, close = true },
    ['hqm_window_bars'] = { label = 'HQM Window Bars', weight = 500, stack = true, close = true },

    -- Perimeter (external) pieces
    ['wood_external_wall'] = { label = 'Wood External Wall', weight = 500, stack = true, close = true },
    ['wood_external_gate'] = { label = 'Wood External Gate', weight = 500, stack = true, close = true },
    ['wood_external_door'] = { label = 'Wood External Door', weight = 500, stack = true, close = true },
    ['stone_external_wall'] = { label = 'Stone External Wall', weight = 500, stack = true, close = true },
    ['stone_external_gate'] = { label = 'Stone External Gate', weight = 500, stack = true, close = true },
    ['stone_external_door'] = { label = 'Stone External Door', weight = 500, stack = true, close = true },

    -- Electrical system
    ['battery'] = {
        label = 'Battery',
        weight = 500,
        stack = true,
        close = true,
        description = 'Stores power so lights stay on when generation drops.',
    },

    ['solar_panel'] = {
        label = 'Solar Panel',
        weight = 500,
        stack = true,
        close = true,
        description = 'Generates power between 06:00 and 20:00. Needs clear sky above it.',
    },

    ['windmill'] = {
        label = 'Windmill',
        weight = 500,
        stack = true,
        close = true,
        description = 'Generates power day and night. The higher it sits, the more it makes.',
    },

    ['combiner'] = { label = 'Combiner', weight = 500, stack = true, description = 'Merges two power inputs into one output.', close = true },
    ['big_splitter'] = { label = 'Big Splitter', weight = 500, stack = true, description = 'Splits one input across three outputs.', close = true },
    ['small_splitter'] = { label = 'Small Splitter', weight = 500, stack = true, description = 'Splits one input across two outputs.', close = true },
    ['switcher'] = { label = 'Switch', weight = 500, stack = true, description = 'Cuts or restores power downstream of it.', close = true },
    ['cable'] = { label = 'Cable', weight = 100, stack = true, description = 'Wires one socket to another. Used in electrician mode.', close = true },
    ['electric_light'] = { label = 'Light', weight = 500, stack = true, close = true },
    ['electric_light_2'] = { label = 'Light 2', weight = 500, stack = true, close = true },

    ['electric_box'] = {
        label = 'Electric Box',
        weight = 500,
        stack = true,
        close = true,
        description = 'Power anchor. Other scripts read it to tell whether a spot has power.',
    },

}
