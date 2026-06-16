local Config    = require 'config.config'
local Items     = require 'config.items'
local Utils     = require 'shared.utils'
local Db        = require 'server.db'
local Framework = require 'server.framework'
local Inventory = require 'server.inventory'
local Transfer  = require 'server.transfer'
local Drops     = require 'server.drops'
local Stashes   = require 'server.stashes'

-- source -> ownerId, and source -> currently open secondary inventory id
local owners = {}
local openSecondary = {}

--- Push the given slot ids of an inventory to everyone currently viewing it.
local function pushSlots(inv, slotIds)
    if not inv or not next(inv.viewers) then return end

    local payload = {}
    for i = 1, #slotIds do
        payload[i] = inv:slotPayload(slotIds[i])
    end

    for source in pairs(inv.viewers) do
        TriggerClientEvent('lk_inv:refresh', source, { items = payload })
    end
end

--- Fire a slide-in item notification on a client. kind: 'ui_added'|'ui_removed'.
local function notify(source, name, kind, count)
    if not source then return end
    local def = Inventory.itemDef(name)
    TriggerClientEvent('lk_inv:notify', source,
        { { name = name, label = def and def.label or name }, kind, count })
end

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

    -- Drop the player from any secondary container they were viewing.
    local secondaryId = openSecondary[source]
    if secondaryId then
        local secondary = Inventory.get(secondaryId)
        if secondary then secondary:removeViewer(source) end
    end

    Inventory.remove(source)
    owners[source] = nil
    openSecondary[source] = nil
end)

--- Periodic flush of dirty inventories (players and persistent stashes).
CreateThread(function()
    while true do
        Wait(Config.saveInterval)
        for id, inv in pairs(Inventory.all()) do
            if inv.dirty then
                if inv.type == 'player' then
                    savePlayer(id)
                elseif inv.persist and inv.owner then
                    local list = {}
                    for _, slot in pairs(inv.items) do list[#list + 1] = slot end
                    Db.save(inv.owner, inv.type, list)
                end
                inv.dirty = false
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, inv in pairs(Inventory.all()) do
        if inv.type == 'player' then
            savePlayer(id)
        elseif inv.persist and inv.owner then
            local list = {}
            for _, slot in pairs(inv.items) do list[#list + 1] = slot end
            Db.save(inv.owner, inv.type, list)
        end
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

    inv:addViewer(source)

    local right
    if secondaryId then
        -- A live container (drop) or a registered stash loaded on demand.
        local secondary = Inventory.get(secondaryId) or Stashes.ensure(secondaryId)
        if secondary then
            openSecondary[source] = secondaryId
            secondary:addViewer(source)
            right = secondary:toClient()
        else
            openSecondary[source] = nil
        end
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
        pushSlots(from, { data.fromSlot })
        return true
    end

    local from = resolve(source, data.fromType)
    local to   = resolve(source, data.toType)
    if not from or not to then return false end

    local ok = Transfer.move(from, data.fromSlot, to, data.toSlot, data.count)
    if not ok then return false end

    -- Keep every viewer of both containers in sync.
    pushSlots(from, { data.fromSlot })
    pushSlots(to, { data.toSlot })

    -- Clean up emptied drops
    if from.type == 'drop' and not next(from.items) then
        Drops.remove(from.id)
    end

    return true
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
        pushSlots(inv, { slotId })
        notify(source, slot.name, 'ui_removed', 1)
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
    local src = source
    local inv = Inventory.get(src)
    if inv then inv:removeViewer(src) end

    local secondaryId = openSecondary[src]
    if secondaryId then
        local secondary = Inventory.get(secondaryId)
        if secondary then secondary:removeViewer(src) end
    end

    openSecondary[src] = nil
end)

----------------------------------------------------------------------
-- Public exports for other resources
----------------------------------------------------------------------

exports('AddItem', function(source, name, count, metadata)
    local inv = Inventory.get(source)
    if not inv then return false end

    -- Capture which slot ends up changed so open viewers refresh live.
    local before = inv:findStack(name, metadata) or inv:firstFree()
    local ok = inv:addItem(name, count, metadata)
    if ok then
        if before then pushSlots(inv, { before }) end
        notify(source, name, 'ui_added', count or 1)
    end
    return ok
end)

exports('RemoveItem', function(source, slotId, count)
    local inv = Inventory.get(source)
    if not inv then return false end

    local slot = inv.items[slotId]
    local ok = inv:removeFromSlot(slotId, count)
    if ok then
        pushSlots(inv, { slotId })
        if slot then notify(source, slot.name, 'ui_removed', count or slot.count) end
    end
    return ok
end)

exports('GetInventory', function(source)
    local inv = Inventory.get(source)
    return inv and inv:toClient() or nil
end)

exports('CreateDrop', function(coords, name, count, metadata)
    return Drops.create(coords, name, count, metadata)
end)
