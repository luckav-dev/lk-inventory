---@class LkConfig
--- Central settings for the LK inventory. These are plain Lua values (not
--- convars) so they are easy to read and version with the resource.
return {
    -- Default player capacity
    playerSlots  = 50,
    playerWeight = 50000, -- grams (50 kg)

    -- Ground drops
    drops = {
        -- Spawn a real, visible world object for every drop instead of a
        -- generic bag. Weapons show their own weapon model, items use the
        -- model configured per item (or the fallback below).
        spawnProps    = true,
        fallbackModel = 'prop_cs_cardbox_01',
        pickupKey     = 38,    -- INPUT_PICKUP (E)
        interactDist  = 1.6,
        renderDist    = 20.0,
        despawnAfter  = 15 * 60 * 1000, -- 15 min of nobody nearby (0 = never)
        maxWeight     = 100000,
        maxPerPlayer  = 12,    -- anti-dump: active ground drops a player may own
        maxTotal      = 400,   -- anti-dump: total active ground drops on the server
    },

    -- Anti-exploit token-bucket limits (actions / window-ms).
    security = {
        swap = { rate = 25, per = 1000 },
        drop = { rate = 6,  per = 2000 },
        use  = { rate = 12, per = 1000 },
    },

    -- Open/close behaviour
    open = {
        command   = 'inv',
        keybind   = 'TAB',
        screenBlur = true,
        useTarget  = false,
    },

    -- Vehicle storage (persisted per number plate). Trunk/glovebox size depends
    -- on the vehicle: a truck carries far more than a car, a van more than a
    -- car, a motorcycle less, a 4x4 differs from a sports car, etc.
    vehicles = {
        key       = 'H',   -- opens glovebox when seated, else nearest trunk
        trunkDist = 4.0,   -- how close (on foot) to open a trunk

        -- Fallback for any class not listed below (sedans, SUVs, coupes...).
        default = {
            trunk = { slots = 40, weight = 120000 },
            glove = { slots = 8,  weight = 15000 },
        },

        -- Capacity by GetVehicleClass id.
        classSpace = {
            [8]  = { trunk = { slots = 5,   weight = 8000 },   glove = { slots = 3,  weight = 4000 } },  -- Motorcycles
            [13] = { trunk = { slots = 2,   weight = 3000 },   glove = { slots = 1,  weight = 1500 } },  -- Cycles
            [6]  = { trunk = { slots = 25,  weight = 70000 },  glove = { slots = 8,  weight = 12000 } }, -- Sports
            [7]  = { trunk = { slots = 18,  weight = 50000 },  glove = { slots = 6,  weight = 10000 } }, -- Super
            [4]  = { trunk = { slots = 30,  weight = 90000 },  glove = { slots = 8,  weight = 14000 } }, -- Muscle
            [9]  = { trunk = { slots = 55,  weight = 180000 }, glove = { slots = 10, weight = 20000 } }, -- Off-road (4x4)
            [2]  = { trunk = { slots = 50,  weight = 160000 }, glove = { slots = 10, weight = 20000 } }, -- SUVs
            [12] = { trunk = { slots = 75,  weight = 260000 }, glove = { slots = 10, weight = 22000 } }, -- Vans
            [11] = { trunk = { slots = 85,  weight = 320000 }, glove = { slots = 12, weight = 24000 } }, -- Utility
            [10] = { trunk = { slots = 120, weight = 520000 }, glove = { slots = 12, weight = 26000 } }, -- Industrial (trucks)
            [20] = { trunk = { slots = 120, weight = 520000 }, glove = { slots = 12, weight = 26000 } }, -- Commercial (trucks)
        },

        -- Per-model overrides by spawn name (highest priority).
        modelSpace = {
            boxville  = { trunk = { slots = 95, weight = 380000 } },
            pounder   = { trunk = { slots = 140, weight = 650000 } },
            speedo    = { trunk = { slots = 70, weight = 240000 } },
        },
    },

    -- Surprising realism: cargo weight in the trunk affects vehicle performance.
    cargo = {
        enabled    = true,
        maxPenalty = 0.40, -- up to -40% engine torque at a full trunk
    },

    -- How often (ms) dirty inventories are flushed to the database
    saveInterval = 5 * 60 * 1000,

    -- Logging verbosity: 0 = errors only, 1 = info, 2 = debug
    logLevel = 1,
}
