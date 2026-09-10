# ox_inventory items

Paste these into `ox_inventory/data/items.lua`

```lua
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
```

## Notes

The item names must match `Config.Boxes.sizes[].item`. Rename them in both places or the item
will do nothing when used
