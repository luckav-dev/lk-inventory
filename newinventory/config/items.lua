--- Item registry. Each entry describes a single item.
---
--- Fields:
---   label       display name
---   weight      grams per unit
---   stack       can multiple units share a slot
---   close       close the inventory when used
---   usable      exposes a "Use" action (server use handler optional)
---   description tooltip text
---   image       custom image filename (defaults to "<name>.png")
---   ground      world model spawned when the item is dropped (realism).
---               Weapons fall back to their own weapon object automatically.
---   degrade     minutes until durability reaches 0 (optional)
---
--- This is intentionally a small starter set. Add your own freely.
return {
    water = {
        label = 'Water', weight = 500, stack = true, close = false, usable = true,
        description = 'A refreshing bottle of water.',
        ground = 'prop_ld_flow_bottle',
    },
    burger = {
        label = 'Burger', weight = 220, stack = true, close = false, usable = true,
        description = 'Greasy but it does the job.',
        ground = 'prop_cs_burger_01',
    },
    bandage = {
        label = 'Bandage', weight = 100, stack = true, close = false, usable = true,
        ground = 'prop_cs_tablet',
    },
    phone = {
        label = 'Phone', weight = 190, stack = false, close = true, usable = true,
        ground = 'prop_npc_phone_02',
    },
    money = {
        label = 'Cash', weight = 0, stack = true, close = false, usable = false,
    },
    lockpick = {
        label = 'Lockpick', weight = 120, stack = true, close = true, usable = true,
        ground = 'prop_tool_screwdvr02',
    },
    scrapmetal = {
        label = 'Scrap Metal', weight = 280, stack = true, close = false, usable = false,
        ground = 'prop_rub_scrap_03',
    },

    -- Weapons: the ground model is resolved from the weapon hash automatically,
    -- so they appear as the actual gun lying on the floor.
    WEAPON_PISTOL = {
        label = 'Pistol', weight = 1200, stack = false, close = true, usable = true,
        weapon = true, ammoName = 'ammo_9',
    },
    WEAPON_KNIFE = {
        label = 'Knife', weight = 600, stack = false, close = true, usable = true,
        weapon = true,
    },
    ammo_9 = {
        label = '9mm Rounds', weight = 4, stack = true, close = false, usable = false,
        ammo = true, ground = 'prop_box_ammo04a',
    },
}
