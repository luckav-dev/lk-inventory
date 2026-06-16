local Config    = require 'config.config'
local Inventory = require 'server.inventory'
local Utils     = require 'shared.utils'

--- Ground drops. Each drop is a real inventory (so items can be taken/added)
--- plus world metadata (coords + the model to render). Clients spawn the
--- actual object for realism.
local Drops = {}

--- id -> { coords, model, weapon }
local meta = {}
local seq = 0

local function newId()
    seq = seq + 1
    return ('drop_%d_%d'):format(seq, math.random(1000, 9999))
end

--- Resolve the world model for a dropped item. Weapons render as the weapon
--- itself; other items use their configured `ground` model or the fallback.
local function resolveModel(name)
    local def = Inventory.itemDef(name)
    if def and def.weapon then
        return { weapon = name }
    end
    return { model = (def and def.ground) or Config.drops.fallbackModel }
end

--- Create a ground drop holding one slot of an item.
--- @return string|nil dropId
function Drops.create(coords, name, count, metadata)
    if not coords or not name then return nil end

    local id = newId()
    local inv = Inventory.create(id, {
        type = 'drop',
        label = 'Ground',
        slots = 10,
        maxWeight = Config.drops.maxWeight,
        items = {},
    })

    inv:addItem(name, count, metadata)

    local render = resolveModel(name)
    meta[id] = {
        coords = coords,
        model  = render.model,
        weapon = render.weapon,
    }

    TriggerClientEvent('lk_inv:spawnDrop', -1, id, coords, render)
    Utils.log('debug', 'drop created', id, name, count)
    return id
end

--- Remove a drop entirely (e.g. once emptied).
function Drops.remove(id)
    if not meta[id] then return end
    meta[id] = nil
    Inventory.remove(id)
    TriggerClientEvent('lk_inv:removeDrop', -1, id)
end

--- Send all active drops to a client (on join / resource restart).
function Drops.syncTo(source)
    for id, m in pairs(meta) do
        TriggerClientEvent('lk_inv:spawnDrop', source, id, m.coords,
            { model = m.model, weapon = m.weapon })
    end
end

function Drops.exists(id)
    return meta[id] ~= nil
end

return Drops
