# of_stash

**Overflow** — a standalone stash & storage-unit creator for FiveM with in-game admin tooling.

Create stashes for players, jobs and gangs from an in-game admin panel (no config editing), place
them in the world with a live point creator, and optionally sell or rent **storage units** — including
physical, world-placed units players rent at the door and share with friends.

Built to work across frameworks and inventories through a bridge layer. First-class support today:
**Qbox + ox_inventory**, with adapters in place for QBCore, ESX and standalone.

---

## Features

- **In-game admin tool** (`/stashadmin`) — create / edit / delete stashes without touching files.
- **Access types** — personal, job, gang (with min grade), shared list, or a PIN code.
- **In-world point creator** — place & rotate the point/prop where you look, with height & fine controls.
- **Interaction per stash** — `ox_target` / `qb-target`, a marker + key, a physical prop, or a floating point.
- **Storage units** — buy/rent tiers from rental points; per-player units with rent expiry & renewal.
- **Physical rentable units** — admins mark a stash rentable; players rent it at its location, open it by
  walking up, and invite **nearby players** to share access.
- **Nearby-player pickers** — assign personal owners / invite people by name, never by raw identifier.
- Clean, theme-tokenised UI (React + Vite + Tailwind, framer-motion + GSAP).

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql)
- An inventory (ox_inventory recommended) and, optionally, a target resource (ox_target / qb-target).
- ox_lib is used when present (notifications, code-entry dialog) but is not required.

## Installation

1. Drop `of_stash` into your resources folder.
2. `ensure of_stash` in your `server.cfg` (after your framework, inventory and oxmysql).
3. The `of_stashes` table is created automatically on first start (or import `of_stash.sql`).
4. Grant admin access — either an ace:
   ```
   add_ace group.admin of_stash.admin allow
   ```
   or rely on your framework admin group (configurable in `config/config.lua`).

The built UI ships in `dist/`, so no build step is required to run it.

## Configuration

Everything lives in `config/config.lua`:

- `Framework` / `Inventory` / `Target` / `Notify` — `'auto'` detects, or pin them explicitly.
- `Admin` — ace, groups, jobs, command and keybind for the admin tool.
- `Stash` — default slots/weight, marker and blip styling.
- `StorageUnits` — enable the economy, currency, tiers (price/rent/slots/weight), rental points and
  the player command that opens "My Units".

## Deployable boxes

Three usable items let a player drop a box in the world, which becomes a stash. The item is consumed
on placement and handed back when it's picked up (only possible while it's empty). Sizes, props, the
per-player limit and item names live in `Config.Boxes`, along with how boxes behave:

| Option | Effect |
|---|---|
| `cleanupOnRestart` | Placed boxes (and their contents) are wiped when the server restarts, so the map never accumulates abandoned crates. |
| `openPolicy` | `'owner'` keeps a box private to its owner and whoever they invited (with access management); `'anyone'` makes it a raidable public stash. |
| `pickupPolicy` | `'owner'` lets only the owner take it back; `'anyone'` lets anybody — combine with `pickupRequiresEmpty` so a thief has to loot it first. |

Add the items to `ox_inventory/data/items.lua`:

```lua
['stash_box_small'] = {
    label = 'Small Storage Box',
    weight = 2000,
    stack = false,
    close = true,
    description = 'A small crate. Use it to place a personal stash you can share with others.',
    client = { export = 'of_stash.useStashBox' }
},
-- repeat for stash_box_medium (weight 4000) and stash_box_large (weight 7000)
```

The same `of_stash.useStashBox` export handles all three — it reads the item name from the payload.

## Commands

| Command | Who | What |
|---|---|---|
| `/stashadmin` | Admins | Opens the stash admin tool (create / edit / delete / teleport). |
| `/giveunit <id> <tier> [days]` | Admins | Hands a virtual storage unit to a player. No `days` = permanent. |
| `/units` | Players | Opens "My Units" — renew a rental, manage access, open a unit remotely. |

All names are configurable (`Config.Admin.command`, `Config.Admin.giveUnitCommand`,
`Config.StorageUnits.command`); set any to `false` to disable it.

## Exports

Hand a virtual storage unit to a player from your VIP, donation or reward system:

```lua
-- online player, permanent
exports.of_stash:grantUnit(source, 'medium')

-- by identifier (works offline), expires in 30 days
exports.of_stash:grantUnit(citizenid, 'large', { days = 30 }, function(ok, idOrReason)
    print(ok, idOrReason)
end)
```

Virtual units are handed out rather than sold by default — flip `Config.StorageUnits.sellVirtual`
to also offer them for sale at rental points.

Locales are in `config/locale/*.lua`. Extend behaviour without editing the core through
`config/hooks.lua`.

## Framework / inventory support

| | Framework | Inventory |
|---|---|---|
| **Tested** | Qbox | ox_inventory |
| Implemented, untested | QBCore, ESX, standalone | qb-inventory, linden/esx, standalone (hook-based) |

Every adapter implements the full contract, but only Qbox + ox_inventory has been verified on a
live server — treat the others as a solid starting point and report anything that misbehaves.

Two things worth knowing:

- **Most ESX and QBCore servers run ox_inventory anyway**, in which case only the framework adapter
  differs and the (well-tested) ox inventory path is used.
- **ESX has no gangs**, so gang-owned stashes don't apply there.

Adding support is a matter of dropping an adapter in `framework/` — see the existing ones. Anything
an adapter can't do falls through to `config/hooks.lua`, so an exotic inventory can be wired up
without touching the core.

---

Made by Overflow · free for the community.
