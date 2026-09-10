-- Emotes you add in the file will automatically be added to AnimationList.lua
-- If you have multiple custom list files they MUST be added between AnimationList.lua and Emote.lua in fxmanifest.lua!
-- Don't change 'CustomDP' it is local to this file!
local CustomDP = {}

CustomDP.Expressions = {}
CustomDP.Walks = {}
CustomDP.Shared = {}
CustomDP.Dances = {}
CustomDP.AnimalEmotes = {}
CustomDP.Exits = {}
CustomDP.Emotes = {}
CustomDP.PropEmotes = {
    ["bsdrink"] = {
        "amb@world_human_drinking@coffee@male@idle_a",
        "idle_c",
        "BS Drink",
        AnimationOptions = {
            Prop = "prop_food_bs_juice02",
            PropBone = 28422,
            PropPlacement = {0.02, 0.0, -0.10, 0.0, 0.0, -0.50},
            EmoteLoop = true,
            EmoteMoving = true
        }
    },
    ["fries"] = {
        "mp_player_inteat@burger",
        "mp_player_int_eat_burger",
        "Fries",
        AnimationOptions = {
            Prop = "prop_food_bs_chips",
            PropBone = 60309,
            PropPlacement = {-0.0100, 0.0200, -0.0100, -175.1935, 97.6975, 13.9598},
            EmoteMoving = true
        }
    },
    ["fbbq"] = {
        "amb@prop_human_bbq@male@idle_a",
        "idle_b",
        "fbbq",
        AnimationOptions = {
            Prop = "prop_fish_slice_01",
            PropBone = 28422,
            PropPlacement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
            --
            EmoteLoop = true,
            EmoteMoving = false
        }
    },
    ["hitvape"] = {
        "mp_player_inteat@burger",
        "mp_player_int_eat_burger",
        "Hit Vape",
        AnimationOptions = {
            Prop = "ba_prop_battle_vape_01",
            PropBone = 18905,
            PropPlacement = {0.08, -0.00, 0.03, -150.0, 90.0, -10.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    -- Jim-BurgerShot
    ["milk"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Milk",
        AnimationOptions = {
            Prop = "v_res_tt_milk",
            PropBone = 18905,
            PropPlacement = {0.10, 0.008, 0.07, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["bscoke"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "BS Coke",
        AnimationOptions = {
            Prop = "prop_food_bs_juice01",
            PropBone = 18905,
            PropPlacement = {0.04, -0.10, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["bscoffee"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "BS Coffee",
        AnimationOptions = {
            Prop = "prop_food_bs_coffee",
            PropBone = 18905,
            PropPlacement = {0.08, -0.10, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["glass"] = {
        "amb@world_human_drinking@coffee@male@idle_a",
        "idle_c",
        "Tall Glass",
        AnimationOptions = {
            Prop = "prop_wheat_grass_glass",
            PropBone = 28422,
            PropPlacement = {0.0, 0.0, -0.1, 0.0, 0.0, 0.0},
            EmoteLoop = true,
            EmoteMoving = true
        }
    },
    ["torpedo"] = {
        "mp_player_inteat@burger",
        "mp_player_int_eat_burger_fp",
        "Torpedo",
        AnimationOptions = {
            Prop = "prop_food_bs_burger2",
            PropBone = 18905,
            PropPlacement = {0.10, -0.07, 0.091, 15.0, 135.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["bsfries"] = {
        "mp_player_inteat@burger",
        "mp_player_int_eat_burger_fp",
        "Fries",
        AnimationOptions = {
            Prop = "prop_food_bs_chips",
            PropBone = 18905,
            PropPlacement = {0.09, -0.06, 0.05, 300.0, 150.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["donut2"] = {
        "mp_player_inteat@burger",
        "mp_player_int_eat_burger",
        "Donut2",
        AnimationOptions = {
            Prop = "prop_donut_02",
            PropBone = 18905,
            PropPlacement = {0.13, 0.05, 0.02, -50.0, 100.0, 270.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    -- Jim-Tequilala
    ["whiskeyb"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "(Don't Use) Whiskey Bottle",
        AnimationOptions = {
            Prop = "prop_cs_whiskey_bottle",
            PropBone = 60309,
            PropPlacement = {0.0, 0.0, 0.0, 0.0, 0.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["rumb"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "(Don't Use) Rum Bottle",
        AnimationOptions = {
            Prop = "prop_rum_bottle",
            PropBone = 18905,
            PropPlacement = {0.03, -0.18, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["icream"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Irish Cream Bottle",
        AnimationOptions = {
            Prop = "prop_bottle_brandy",
            PropBone = 18905,
            PropPlacement = {0.00, -0.26, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["ginb"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "(Don't Use) Gin Bottle",
        AnimationOptions = {
            Prop = "prop_tequila_bottle",
            PropBone = 18905,
            PropPlacement = {0.00, -0.26, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["vodkab"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "(Don't Use) Vodka Bottle",
        AnimationOptions = {
            Prop = "prop_vodka_bottle",
            PropBone = 18905,
            PropPlacement = {0.00, -0.26, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["guitarelectric3"] = {
        "amb@world_human_musician@guitar@male@idle_a",
        "idle_b",
        "Guitar Electric 3",
        AnimationOptions = {
            Prop = "prop_el_guitar_02",
            PropBone = 24818,
            PropPlacement = {-0.1, 0.31, 0.1, 0.0, 20.0, 150.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["guitarelectric4"] = {
        "amb@world_human_musician@guitar@male@idle_a",
        "idle_b",
        "Guitar Electric 4",
        AnimationOptions = {
            Prop = "vw_prop_casino_art_guitar_01a",
            PropBone = 24818,
            PropPlacement = {-0.1, 0.31, 0.1, 0.0, 20.0, 150.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["guitarelectric5"] = {
        "amb@world_human_musician@guitar@male@idle_a",
        "idle_b",
        "Guitar Electric 5",
        AnimationOptions = {
            Prop = "sf_prop_sf_el_guitar_02a",
            PropBone = 24818,
            PropPlacement = {-0.1, 0.31, 0.1, 0.0, 20.0, 150.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["drummer"] = {
        "anim@scripted@freemode_npc@fix_astu_prod_drums@",
        "art_ig2_drums_p1",
        "Drummer",
        AnimationOptions = {
            Prop = "sf_prop_sf_drum_stick_01a",
            PropBone = 60309,
            PropPlacement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
            SecondProp = "sf_prop_sf_drum_stick_01a",
            SecondPropBone = 28422,
            SecondPropPlacement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
            EmoteMoving = false,
            EmoteLoop = true
        }
    },
    ["crisps"] = {
        "amb@world_human_drinking@coffee@male@idle_a",
        "idle_c",
        "Chrisps",
        AnimationOptions = {
            Prop = "v_ret_ml_chips2",
            PropBone = 28422,
            PropPlacement = {0.01, -0.05, -0.1, 0.0, 0.0, 90.0},
            EmoteLoop = true,
            EmoteMoving = true
        }
    },
    ["beer1"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Dusche",
        AnimationOptions = {
            Prop = "prop_beerdusche",
            PropBone = 18905,
            PropPlacement = {0.04, -0.14, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["beer2"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Logger",
        AnimationOptions = {
            Prop = "prop_beer_logopen",
            PropBone = 18905,
            PropPlacement = {0.03, -0.18, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["beer3"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "AM Beer",
        AnimationOptions = {
            Prop = "prop_beer_amopen",
            PropBone = 18905,
            PropPlacement = {0.03, -0.18, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["beer4"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Pisswasser1",
        AnimationOptions = {
            Prop = "prop_beer_pissh",
            PropBone = 18905,
            PropPlacement = {0.03, -0.18, 0.10, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["beer5"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Pisswasser2",
        AnimationOptions = {
            Prop = "prop_amb_beer_bottle",
            PropBone = 18905,
            PropPlacement = {0.12, 0.008, 0.03, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["beer6"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Pisswasser3",
        AnimationOptions = {
            Prop = "prop_cs_beer_bot_02",
            PropBone = 18905,
            PropPlacement = {0.12, 0.008, 0.03, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["ecola"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "E-cola",
        AnimationOptions = {
            Prop = "prop_ecola_can",
            PropBone = 18905,
            PropPlacement = {0.12, 0.008, 0.03, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["sprunk"] = {
        "mp_player_intdrink",
        "loop_bottle",
        "Sprunk",
        AnimationOptions = {
            Prop = "v_res_tt_can03",
            PropBone = 18905,
            PropPlacement = {0.12, 0.008, 0.03, 240.0, -60.0},
            EmoteMoving = true,
            EmoteLoop = true
        }
    },
    ["market"] = {
        "missfbi4prepp1",
        "idle",
        "Shop with basket",
        AnimationOptions = {
            Prop = "bzzz_prop_shop_basket_a",
            PropBone = 57005,
            PropPlacement = {0.34, -0.25, -0.24, -146.0, 115.0, 19.0},
            EmoteLoop = true,
            EmoteMoving = true
        }
    },
    ["market2"] = {
        "missfbi4prepp1",
        "idle",
        "Shop with basket",
        AnimationOptions = {
            Prop = "bzzz_prop_shop_basket_b",
            PropBone = 57005,
            PropPlacement = {0.34, -0.25, -0.24, -146.0, 115.0, 19.0},
            EmoteLoop = true,
            EmoteMoving = true
        }
    }
    -- ["hitvape"] = {
    --     "mp_player_inteat@burger",
    --     "mp_player_int_eat_burger",
    --         "Hit Vape",
    --     AnimationOptions = {
    --         Prop = 'brum_voopoo_drag2',
    --         PropBone = 18905,
    --         PropPlacement = {
    --             0.12, 0.05, 0.03, -60.0, 140.0, 360.0
    --         },
    --         EmoteMoving = true,
    --         EmoteLoop = true,
    --          PtfxAsset = "core",
    --             PtfxName = "exp_grd_bzgas_smoke",
    --             PtfxNoProp = true,
    --             PtfxPlacement = {
    --                 -0.0100,
    --                 0.0600,
    --                 0.6600,
    --                 0.0,
    --                 0.0,
    --                 0.0,
    --                 2.0
    --             },
    --             PtfxInfo = Config.Languages[Config.MenuLanguage]['vape'],
    --             PtfxWait = 0,
    --             PtfxCanHold = true
    --     }
    -- },
}

-----------------------------------------------------------------------------------------
-- | I don't think you should change the code below unless you know what you are doing |--
-----------------------------------------------------------------------------------------

-- Add the custom emotes to RPEmotes main array
function LoadAddonEmotes()
    for arrayName, array in pairs(CustomDP) do if RP[arrayName] then for emoteName, emoteData in pairs(array) do RP[arrayName][emoteName] = emoteData end end end
    -- Free memory
    CustomDP = nil
end
