<div align="center">

# LK Inventory

A premium, fully redesigned inventory system for FiveM built on the [ox_inventory](https://github.com/overextended/ox_inventory) backend with a custom **Svelte + TypeScript** NUI frontend.

[![Version](https://img.shields.io/badge/version-2.47.5-e42a2d?style=for-the-badge)](https://github.com/luckav-dev/lk-inventory)
[![FiveM](https://img.shields.io/badge/FiveM-ready-2cd63c?style=for-the-badge)](https://fivem.net)
[![Lua](https://img.shields.io/badge/Lua_5.4-000080?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![Svelte](https://img.shields.io/badge/Svelte-FF3E00?style=for-the-badge&logo=svelte&logoColor=white)](https://svelte.dev)

</div>

---

## Preview

<div align="center">

<img src="https://i.imgur.com/YrvYzRF.png" width="800" alt="Classic Layout" />

<br/><br/>

<img src="https://i.imgur.com/MUjvjGF.png" width="800" alt="Inventory Overview" />

<br/><br/>

<img src="https://i.imgur.com/li5kSBA.png" width="800" alt="Compact Layout" />

<br/><br/>

<img src="https://i.imgur.com/W4LXvR6.png" width="800" alt="Stash View" />

<br/><br/>

<img src="https://i.imgur.com/b59sf1A.png" width="800" alt="Weapon Modification" />

<br/><br/>

<img src="https://i.imgur.com/iiQwshA.png" width="800" alt="Crafting System" />

</div>

---

## Features

- **Dual Layout System** — Classic side-by-side layout and a compact stacked-right layout, switchable in-game
- **Custom Svelte NUI** — Fully rewritten frontend using Svelte, TypeScript, and SCSS with TT Lakes typography
- **Drag & Drop** — Smooth item dragging with a scaled preview, quantity splitting with Shift, and slot swapping
- **Hotbar System** — 5-slot quick access bar with in-game HUD overlay and hotkey badges
- **Weight System** — Visual weight bar with real-time tracking per inventory
- **Context Menu** — Right-click actions: Use, Give, Destroy, Favorite, and Send with quantity selector
- **Clothing Toggle Panel** — 12 clothing category toggles (hat, mask, glasses, ears, neck, torso, vest, bag, pants, shoes, watch, bracelets)
- **Weapon Modification** — Tactical weapon mod overlay with socket-based attachment management
- **Crafting System** — Built-in crafting panel with recipe selection, material tracking, and progress bar
- **Stash PIN Lock** — Numeric keypad PIN overlay for secured stashes with error feedback
- **Shop System** — NPC shops with price tags, cash/bank display, and purchase validation
- **Accent Color Customization** — In-game color picker with presets and custom hex input
- **Notifications** — Slide-in item notifications with icons for add/remove events
- **Tooltip System** — Hover tooltips with item metadata, durability, serial numbers, and ammo info
- **Responsive Scaling** — Automatic aspect-ratio and height-based scaling for any resolution
- **30 Languages** — Full localization support

---

## Dependencies

| Resource | Required |
|---|---|
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ |
| [ox_lib](https://github.com/overextended/ox_lib) | ✅ |
| OneSync | ✅ |
| Server build 6116+ | ✅ |

---

## Installation

1. Download or clone this repository into your `resources` folder
   ```
   git clone https://github.com/luckav-dev/lk-inventory.git
   ```

2. The NUI is pre-built — no additional build step is needed. If you want to modify the frontend:
   ```
   cd lk-inventory/web
   pnpm install
   pnpm run build
   ```

3. Keep the folder named `lk_inventory` (no need to rename it to `ox_inventory`) — the resource provides the `ox_inventory` alias and re-registers all of its exports under that name, so `es_extended` and any third-party script using `exports.ox_inventory` keep working. Just make sure you don't have another resource named `ox_inventory` installed at the same time

4. Select your framework with the `inventory:framework` convar in `server.cfg`. Supported values: `esx`, `qb` (QBCore), `qbx` (Qbox), `ox` (ox_core), `nd` (ND_Core). Default is `esx`:
   ```
   setr inventory:framework "qb"
   ```

5. Add to your `server.cfg`, starting the inventory **after** your framework (the `ensure` name must match your folder name):
   ```
   ensure oxmysql
   ensure ox_lib
   ensure qb-core
   ensure lk_inventory
   ```

6. Import the required database tables from `ox_inventory` if you haven't already

---

## Project Structure

```
lk-inventory/
├── client.lua              # Client-side logic
├── server.lua              # Server-side logic
├── init.lua                # Resource initialization
├── fxmanifest.lua          # Resource manifest
├── data/                   # Items, weapons, shops, stashes, crafting configs
├── locales/                # 30 language files
├── modules/                # Modular systems
│   ├── bridge/             # Framework bridge (ESX/QBCore)
│   ├── clothing/           # Clothing toggle system
│   ├── crafting/           # Crafting logic
│   ├── inventory/          # Core inventory logic
│   ├── items/              # Item definitions & handlers
│   ├── shops/              # Shop system
│   ├── weapon/             # Weapon handling
│   └── ...
└── web/                    # Svelte NUI frontend
    ├── src/
    │   ├── components/     # Svelte components
    │   ├── stores/         # State management
    │   ├── styles/         # SCSS stylesheets
    │   └── lib/            # Utilities
    └── build/              # Production build (ready to use)
```

---

## NUI Development

The frontend is built with **Svelte + Vite + TypeScript + SCSS**.

```bash
cd web
pnpm install
pnpm run dev
```

Open `http://localhost:5173` in your browser to see the debug mockup with sample inventory data.

---

## License

This project is licensed under the **GPL-3.0** license. See [LICENSE](LICENSE) for details.

Based on [ox_inventory](https://github.com/overextended/ox_inventory) by [Overextended](https://github.com/overextended).

---

<div align="center">
  <sub>Made by <strong>luckav-dev</strong></sub>
</div>
