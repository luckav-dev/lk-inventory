local Config    = require 'config.config'
local Items     = require 'config.items'
local Utils     = require 'shared.utils'
local Db        = require 'server.db'
local Framework = require 'server.framework'
local Inventory = require 'server.inventory'
local Transfer  = require 'server.transfer'
local Drops     = require 'server.drops'

-- source -> ownerId, and source -> currently open secondary inventory id
local owners = {}
local openSecondary = {}

--- Item registry in the shape the NUI expects.
local clientItems = (function()
    local out = {}
    for name, def in pairs(Items) do
        out[name] = {
            name = name,
            label = def.label or name,
            stack = def.stack ~= false,
            usable = def.usable == true,
            close = def.close == true,
            count = 0,
            weight = def.weight or 0,
            description = def.description,
            image = def.image,
            ammoName = def.ammoName,
            weapon = def.weapon == true,
            ammo = def.ammo == true,
            component = def.component == true,
            type = def.type,
        }
    end
    return out
end)()

MySQL.ready(Db.init)

--- Load (or create) a player's inventory when they spawn.
Framework.onLoaded(function(source, ownerId, name)
    owners[source] = ownerId
    local stored = Db.load(ownerId, 'player')

    Inventory.create(source, {
        type = 'player',
        owner = ownerId,
        label = name,
        slots = Config.playerSlots,
        maxWeight = Config.playerWeight,
        items = stored,
    })

    Drops.syncTo(source)
    Utils.log('info', ('loaded inventory for %s (%s)'):format(name, ownerId))
end)

local function savePlayer(source)
    local inv = Inventory.get(source)
    local ownerId = owners[source]
    if inv and ownerId then
        local list = {}
        for _, slot in pairs(inv.items) do list[#list + 1] = slot end
        Db.save(ownerId, 'player', list)
    end
end

Framework.onDropped(function(source)
    savePlayer(source)
    Inventory.remove(source)
    owners[source] = nil
    openSecondary[source] = nil
end)

--- Periodic flush of dirty inventories.
CreateThread(function()
    while true do
        Wait(Config.saveInterval)
        for source, inv in pairs(Inventory.all()) do
            if inv.type == 'player' and inv.dirty then
                savePlayer(source)
                inv.dirty = false
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for source, inv in pairs(Inventory.all()) do
        if inv.type == 'player' then savePlayer(source) end
    end
end)

----------------------------------------------------------------------
-- NUI-facing callbacks (the client forwards UI fetchNui calls here)
----------------------------------------------------------------------

--- Resolve a from/to type string to a concrete inventory for `source`.
local function resolve(source, invType)
    if invType == 'player' then return Inventory.get(source) end
    local secondary = openSecondary[source]
    return secondary and Inventory.get(secondary) or nil
end

lib.callback.register('lk_inv:open', function(source, secondaryId)
    local inv = Inventory.get(source)
    if not inv then return nil end

    local right
    if secondaryId and Inventory.get(secondaryId) then
        openSecondary[source] = secondaryId
        right = Inventory.get(secondaryId):toClient()
    else
        openSecondary[source] = nil
    end

    return {
        items = clientItems,
        imagepath = ('nui://%s/web/images'):format(GetCurrentResourceName()),
        left = inv:toClient(),
        right = right,
    }
end)

lib.callback.register('lk_inv:swap', function(source, data)
    if type(data) ~= 'table' then return false end

    -- Drop to ground: client provides validated player coords.
    if data.toType == 'newdrop' then
        local from = Inventory.get(source)
        local slot = from and from.items[data.fromSlot]
        if not slot or not data.coords then return false end

        local count = math.min(data.count or slot.count, slot.count)
        local dropId = Drops.create(data.coords, slot.name, count, slot.metadata)
        if not dropId then return false end

        from:removeFromSlot(data.fromSlot, count)
        return true
    end

    local from = resolve(source, data.fromType)
    local to   = resolve(source, data.toType)
    if not from or not to then return false end

    local ok = Transfer.move(from, data.fromSlot, to, data.toSlot, data.count)

    -- Clean up emptied drops
    if ok and from.type == 'drop' and not next(from.items) then
        Drops.remove(from.id)
    end

    return ok
end)

lib.callback.register('lk_inv:useItem', function(source, slotId)
    local inv = Inventory.get(source)
    local slot = inv and inv.items[slotId]
    if not slot then return false end

    local def = Inventory.itemDef(slot.name)
    if not def or not def.usable then return false end

    -- Let other resources react to item usage.
    TriggerEvent('lk_inv:itemUsed', source, slot.name, slot.metadata)

    -- Consumables (non-weapon) decrement by one on use.
    if not def.weapon then
        inv:removeFromSlot(slotId, 1)
    end

    return true
end)

lib.callback.register('lk_inv:getItemData', function(_, name)
    return clientItems[name]
end)

lib.callback.register('lk_inv:give', function(source, data)
    if type(data) ~= 'table' then return false end
    local target = data.target and tonumber(data.target)
    if not target then return false end

    local from = Inventory.get(source)
    local to = Inventory.get(target)
    local slot = from and from.items[data.slot]
    if not from or not to or not slot then return false end

    local count = math.min(data.count or 1, slot.count)
    if not to:addItem(slot.name, count, slot.metadata) then return false end
    from:removeFromSlot(data.slot, count)
    return true
end)

RegisterNetEvent('lk_inv:closeInventory', function()
    openSecondary[source] = nil
end)

----------------------------------------------------------------------
-- Public exports for other resources
----------------------------------------------------------------------

exports('AddItem', function(source, name, count, metadata)
    local inv = Inventory.get(source)
    return inv and inv:addItem(name, count, metadata) or false
end)

exports('RemoveItem', function(source, slotId, count)
    local inv = Inventory.get(source)
    return inv and inv:removeFromSlot(slotId, count) or false
end)

exports('GetInventory', function(source)
    local inv = Inventory.get(source)
    return inv and inv:toClient() or nil
end)

exports('CreateDrop', function(coords, name, count, metadata)
    return Drops.create(coords, name, count, metadata)
end)
