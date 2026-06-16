# LK Inventory (`lk_inv`) — original build

A from-scratch FiveM inventory backend written specifically for this project. It
is **not** a fork or reskin of ox_inventory — the Lua, data model, database
schema and NUI protocol are all original. The web UI is the project's own Svelte
interface, copied in unchanged.

> Status: feature-complete core; advanced systems built out across the phases
> below. Pure logic is unit-tested; FiveM-native paths await a live-server pass.

## Things this does that ox_inventory doesn't
- **Real dropped objects** — a dropped weapon lies on the floor as the actual
  gun; other items use a configured prop (ox shows a generic bag).
- **Load affects you** — carrying near your weight limit slows you down.
- **Cargo affects the vehicle** — a heavy trunk makes the vehicle accelerate
  noticeably slower (engine torque scales with load).
- **Trunk size by vehicle** — capacity is derived from the vehicle class/model:
  trucks ≫ vans > 4x4 > cars > sports > bikes, with per-model overrides.
- **Container weight is real** — a bag's contents count toward your total weight.
- **Built-in anti-dump** — token-bucket rate limits + per-player/global drop caps.
- **Visible equipment on the body** — holstered weapons show on your back/thigh
  and a worn backpack appears when you carry a bag (the equipped gun hides).
- **Carry heavy items in hand** — a `box`-type item is picked up with a carry
  animation, slows you, blocks sprint/weapons, and is set down as a real object.
- **Frisk / rob players** — search a downed or hands-up player's inventory, with
  a server-side authorization gate so you can't open arbitrary inventories.
- **Searchable dumpsters** — rummage configured world props for random loot
  (server-rolled, with a cooldown).

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

**Phase 5 — realism & hardening**
- **Container weight propagation**: a bag's slot weight includes its contents and
  counts toward the holder's total.
- **Give cash**: giving the `money` item transfers framework account cash
  between players.
- **Weight slows movement**: past 85% of max weight the ped's move rate scales
  down (up to −25%). (`client/weight.lua`)
- **Perishable items**: items with `degrade` carry an expiry the UI counts down.
- **Anti-exploit**: drags from/to shops & crafting benches are rejected
  (purchases go through buy/craft); secondary containers must be the one the
  player has open.
- **Idle container unloading** + `exports.lk_inv:DeleteContainer(id)`.

## NUI protocol
The backend speaks the exact contract the Svelte UI expects: it sends `init`,
`setupInventory`, `refreshSlots`, `itemNotify`, … and answers the UI's
`fetchNui` callbacks (`swapItems`, `useItem`, `giveItem`, `getItemData`, …). See
`client/nui.lua`.

**Phase 6 — accounts & tests**
- **Bank purchases**: shop entries can set `currency = 'bank'` to charge the
  framework bank account instead of cash.
- **Unit tests**: pure inventory/transfer/container logic is covered by a Lua
  test suite (`tests/run.lua`, 27 checks) runnable under stock Lua 5.4.
- **Nested containers blocked**: a bag can't be placed inside another bag,
  preventing weight-propagation cycles.

**Phase 7 — vehicle realism & anti-dump**
- **Class/model-based trunk & glovebox size** (`config/config.lua` → `vehicles`):
  trucks/industrial carry the most, then utility, vans, SUVs, 4x4, muscle,
  cars (default), sports, super, bikes; per-model overrides supported.
- **Cargo handling penalty**: trunk load reduces engine torque up to −40% at
  full (`client/cargo.lua`, server `lk_inv:trunkLoad`).
- **Anti-dump / anti-dupe**: per-player token-bucket rate limits on swap/use/
  drop (`server/security.lua`), plus per-player and global active-drop caps.
  Suspicious actions fire `lk_inv:exploit` for external anti-cheats.

**Phase 8 — visible body equipment & carrying**
- **Holstered weapons on the body** + **worn backpack** (`client/visuals.lua`):
  the server pushes the player's weapon/bag set; the client attaches the real
  props to bones (rifles back, pistols thigh). The drawn weapon is hidden.
- **Carry heavy items** (`client/carry.lua`): items with a `carry` definition
  are held in-hand with an animation, slow movement, disable sprint/weapons,
  and drop as a world object when set down (press **E**).

> Note: container contents count toward the holder's total weight by design
> (realism), so a bag organises space without expanding total capacity.
>
> Body-visual bone ids/offsets in `config.visuals` are approximate — tune them
> on a live server.

**Phase 9 — frisking, dumpsters & open security**
- **Frisk players** (`client/search.lua`, `lk_inv:searchPlayer`): `/search` the
  nearest player; the server allows it only when they're down (dead) or flagged
  searchable, and within reach. `/handsup` (X) makes you frisk-able; other
  resources can flag a player via `exports.lk_inv:SetSearchable`.
- **Dumpster search** (`client/dumpsters.lua`, `lk_inv:searchDumpster`): press E
  at a dumpster for server-rolled loot (`config/dumpsters.lua`), with a cooldown.
- **Open authorization**: opening a player body, vehicle trunk/glovebox or
  dumpster now requires the matching prep step (proximity/condition checked
  server-side); drops require proximity. Stops clients opening inventories by
  guessing ids.

## Roadmap (remaining)
- Live testing pass on a real server (FiveM-native paths: NUI, drops, weapons,
  vehicles)
- Dropped-item physics and an inspect / 3D item view
- Recursive weight propagation for bags-in-bags (currently nesting is blocked)

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
