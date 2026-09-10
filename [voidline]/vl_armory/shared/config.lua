Config = {}

Config.Coords = vector4(3080.91, 5463.50, 23.70, 127)
Config.InteractDistance = 1.5

-- Item names must match your ox_inventory item/weapon registrations exactly.
-- Ammo items give Config.AmmoPerClick each click; everything else gives 1.
Config.AmmoPerClick = 50

Config.Items = {
    { name = 'weapon_carbinerifle', label = 'M16 Rifle',   amount = 1,  weapon = true },
    { name = 'ammo-rifle',          label = 'Rifle Ammo',  amount = Config.AmmoPerClick, ammo = true },
    { name = 'weapon_nightstick',   label = 'Nightstick',  amount = 1,  weapon = true },
    { name = 'weapon_stungun',      label = 'Taser',       amount = 1,  weapon = true },
    { name = 'weapon_bzgas',        label = 'BZ Gas',      amount = 1,  weapon = true },
    { name = 'handcuffs',           label = 'Handcuffs',   amount = 1 },
    { name = 'armour',              label = 'Body Armor',  amount = 1 },
    { name = 'weapon_pistol',       label = 'Pistol',      amount = 1,  weapon = true },
    { name = 'ammo-9',              label = 'Pistol Ammo', amount = Config.AmmoPerClick, ammo = true },
    -- 'firstaid' is a targeted-revive item that only works on a nearby
    -- downed player (qbx_ambulancejob) -- it does nothing when used on
    -- yourself and isn't restricted to EMS by job check, it's just built
    -- for that one use case. 'bandage' is a genuine, job-agnostic self-heal
    -- item (globally registered via CreateUseableItem, no job check).
    { name = 'bandage',             label = 'Bandage',     amount = 1 },
}
