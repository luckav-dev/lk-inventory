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
    },

    -- Open/close behaviour
    open = {
        command   = 'inv',
        keybind   = 'TAB',
        screenBlur = true,
        useTarget  = false,
    },

    -- How often (ms) dirty inventories are flushed to the database
    saveInterval = 5 * 60 * 1000,

    -- Logging verbosity: 0 = errors only, 1 = info, 2 = debug
    logLevel = 1,
}
