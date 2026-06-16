# LK Inventory (`lk_inv`) — original build

A from-scratch FiveM inventory backend written specifically for this project. It
is **not** a fork or reskin of ox_inventory — the Lua, data model, database
schema and NUI protocol are all original. The web UI is the project's own Svelte
interface, copied in unchanged.

> Status: **foundation / Phase 1**. The core loop works end to end; advanced
> systems are scaffolded on the roadmap below.

## Why a separate resource
It lives in its own folder (`lk_inv`) and its own database table
(`lk_inventories`) so it can run alongside the existing `lk-inventory` without
touching it.

## Requirements
- [ox_lib](https://github.com/communityox/ox_lib)
- [oxmysql](https://github.com/communityox/oxmysql)
- A framework (QBCore is wired up; ESX/Qbox/standalone are auto-detected via the
  bridge in `server/framework.lua`)

## Install
```cfg
ensure oxmysql
ensure ox_lib
ensure qb-core
ensure lk_inv
```
Open with `/inv` or the `TAB` keybind (configurable in `config/config.lua`).

## What works now
**Phase 1 — core**
- Server-authoritative slot model with weight + stacking (`server/inventory.lua`)
- Move / split / stack / swap between containers (`server/transfer.lua`)
- Persistence with its own schema (`server/db.lua`, table `lk_inventories`)
- Open/close with NUI focus, screen blur and **game-side ESC** handling
- Item registry with per-item data (`config/items.lua`)
- Use items, give to the nearest player
- **Realism: real ground objects.** Dropping an item spawns the actual world
  object where it lands — weapons appear as the gun on the floor, other items
  use a configured prop. Walk up and press **E** to open the drop.
  (`server/drops.lua` + `client/drops.lua`)

**Phase 2 — containers & live sync**
- **Stashes**: persistent shared storage, defined in `config/stashes.lua` or via
  `exports.lk_inv:RegisterStash`, opened by world points (press **E**) or
  `exports.lk_inv:OpenStash(id)`. Loaded on demand, saved on change.
- **Live multi-viewer sync**: two players in the same stash see each other's
  moves instantly; external `AddItem`/`RemoveItem` reflect live
  (`lk_inv:refresh`).
- **Item notifications** on add/remove/use (`lk_inv:notify`).
- **Hotbar**: number keys **1–5** quick-use items while the inventory is closed.

**Phase 3 — shops**
- **Shops**: defined in `config/shops.lua` or via `exports.lk_inv:RegisterShop`,
  opened by world points (press **E**) or `exports.lk_inv:OpenShop(id)`. Price
  tags render in the UI; buying deducts the `money` item and adds the purchase,
  with weight/funds validation server-side.
- **Vehicle storage**: persistent **trunk** and **glovebox** keyed by number
  plate. Press **H** (configurable) to open the glovebox when seated, or the
  nearest unlocked vehicle's trunk on foot. The server validates proximity by
  network id before opening (anti-exploit).
- **Crafting**: benches defined in `config/crafting.lua` or via
  `exports.lk_inv:RegisterCraftingBench`, opened by world points (press **E**)
  or `exports.lk_inv:OpenCraftingBench(id)`. Recipes show ingredients,
  duration and a live "can craft" check; the server validates ingredients +
  weight, consumes them and grants the result.

**Phase 4 — framework, weapons, containers**
- **Account money bridge**: when QBCore/ESX is present, the framework cash
  account is the source of truth and the in-inventory `money` item mirrors it;
  shops charge real money. Standalone falls back to a plain `money` item.
  (`server/money.lua`, `server/framework.lua`)
- **Stash access control**: stashes can require a job/gang grade via `groups`.
- **Weapons**: use a weapon to equip/holster it; **ammo and durability** persist
  in metadata (durability wears per bullet, weapon jams at 0); **attachments**
  attach by using a component item and detach from the weapon modal, returning
  the component to the inventory. (`client/weapons.lua`)
- **Containers**: items with a `container` definition (e.g. the `bag`) open their
  own persistent inventory; nesting a container in itself is blocked.

## NUI protocol
The backend speaks the exact contract the Svelte UI expects: it sends `init`,
`setupInventory`, `refreshSlots`, `itemNotify`, … and answers the UI's
`fetchNui` callbacks (`swapItems`, `useItem`, `giveItem`, `getItemData`, …). See
`client/nui.lua`.

## Roadmap
- Container **weight propagation** (a bag's weight includes its contents)
- Account-money **give** flow (transfer cash between players)
- Anti-exploit hardening pass + automated tests
- Orphaned-container cleanup (when a bag item is destroyed)
- **Advanced realism (planned)** — weight affecting stamina/movement, item
  degradation over time, dropped-item physics, inspect/3D item view, holstering
  visuals

## Exports
```lua
exports.lk_inv:AddItem(source, name, count, metadata)
exports.lk_inv:RemoveItem(source, slotId, count)
exports.lk_inv:GetInventory(source)
exports.lk_inv:CreateDrop(coords, name, count, metadata)
exports.lk_inv:RegisterStash(def)
exports.lk_inv:RegisterShop(def)
exports.lk_inv:RegisterCraftingBench(def)
exports.lk_inv:OpenStash(id) / OpenShop(id) / OpenCraftingBench(id)
```
