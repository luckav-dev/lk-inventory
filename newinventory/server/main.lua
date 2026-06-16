local Config    = require 'config.config'
local Items     = require 'config.items'
local Utils     = require 'shared.utils'
local Db        = require 'server.db'
local Framework = require 'server.framework'
local Inventory = require 'server.inventory'
local Transfer  = require 'server.transfer'
local Drops     = require 'server.drops'
local Stashes   = require 'server.stashes'
local Shops     = require 'server.shops'
local Crafting  = require 'server.crafting'
local Money     = require 'server.money'
local Security  = require 'server.security'

--- Trunk/glovebox capacity for a vehicle, by model override → class → default.
local function vehicleSpace(class, model, vtype)
    local cfg = Config.vehicles
    local space = (model and cfg.modelSpace[model]) or cfg.classSpace[class] or cfg.default
    local s = (vtype == 'glovebox' and (space.glove or cfg.default.glove))
        or (space.trunk or cfg.default.trunk)
    return s.slots, s.weight
end

--- True if the player meets any of the required group/grade pairs.
local function hasAnyGroup(source, groups)
    local pg = Framework.getGroups(source) or {}
    for name, minGrade in pairs(groups) do
        local g = pg[name]
        if g ~= nil and g >= (minGrade or 0) then return true end
    end
    return false
end

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

--- Body equipment the client renders: holstered weapons + whether a bag is worn.
local function visualsFor(inv)
    local weapons, bag = {}, false
    for _, slot in pairs(inv.items) do
        local def = Inventory.itemDef(slot.name)
        if def then
            if def.weapon then weapons[#weapons + 1] = { name = slot.name } end
            if def.container then bag = true end
        end
    end
    return { weapons = weapons, bag = bag }
end

--- Send the player's weight ratio (movement penalty) and body visuals.
local function pushWeight(source)
    local inv = Inventory.get(source)
    if not inv then return end
    local ratio = inv.maxWeight > 0 and (inv.weight / inv.maxWeight) or 0
    TriggerClientEvent('lk_inv:weight', source, ratio)
    TriggerClientEvent('lk_inv:visuals', source, visualsFor(inv))
end

--- When a container's contents change, refresh the holder's container slot and
--- recompute their total weight (container weight propagation).
local function updateContainerParent(containerId)
    if not Inventory.get(containerId) then return end
    for src, secId in pairs(openSecondary) do
        if secId == containerId then
            local pInv = Inventory.get(src)
            if pInv then
                for slotId, slot in pairs(pInv.items) do
                    if slot.metadata and slot.metadata.container == containerId then
                        pInv:recalcWeight()
                        pInv.dirty = true
                        pushSlots(pInv, { slotId })
                        pushWeight(src)
                    end
                end
            end
        end
    end
end

--- Fire a slide-in item notification on a client. kind: 'ui_added'|'ui_removed'.
local function notify(source, name, kind, count)
    if not source then return end
    local def = Inventory.itemDef(name)
    TriggerClientEvent('lk_inv:notify', source,
        { { name = name, label = def and def.label or name }, kind, count })
end

--- Total count of `name` carried across all slots (money is the `money` item).
local function itemCount(inv, name)
    local total = 0
    for _, slot in pairs(inv.items) do
        if slot.name == name then total = total + slot.count end
    end
    return total
end

--- Remove `amount` of `name` across slots, appending changed slot ids to `acc`.
--- @return integer[] changed slot ids
local function removeByName(inv, name, amount, acc)
    acc = acc or {}
    for slotId, slot in pairs(inv.items) do
        if amount <= 0 then break end
        if slot.name == name then
            local take = math.min(slot.count, amount)
            inv:removeFromSlot(slotId, take)
            amount = amount - take
            acc[#acc + 1] = slotId
        end
    end
    return acc
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

    -- Render body visuals (holstered weapons / backpack) once the client is up.
    SetTimeout(1500, function() pushWeight(source) end)
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
    Security.clear(source)
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

        -- Unload idle containers (no viewers, empty) to free memory; they reload
        -- from the database the next time the bag is opened.
        for id, inv in pairs(Inventory.all()) do
            if inv.type == 'container' and not next(inv.viewers) and not next(inv.items) then
                Inventory.remove(id)
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

    -- Keep the money item in sync with the framework account for display.
    Money.syncItem(source)

    local right
    if secondaryId then
        -- A live container (drop/bag), a registered stash, a shop, or a bench.
        local secondary = Inventory.get(secondaryId)
            or Stashes.ensure(secondaryId)
            or Shops.ensure(secondaryId)
            or Crafting.ensure(secondaryId)

        -- Stash job/group access control.
        if secondary and secondary.type == 'stash' then
            local def = Stashes.getDef(secondaryId)
            if def and def.groups and not hasAnyGroup(source, def.groups) then
                secondary = nil
            end
        end

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

    pushWeight(source)

    return {
        items = clientItems,
        imagepath = ('nui://%s/web/images'):format(GetCurrentResourceName()),
        left = inv:toClient(),
        right = right,
    }
end)

lib.callback.register('lk_inv:swap', function(source, data)
    if type(data) ~= 'table' then return false end

    local action = data.toType == 'newdrop' and 'drop' or 'swap'
    if not Security.allow(source, action) then
        Security.flag(source, action .. ' rate exceeded')
        return false
    end

    -- Drop to ground: client provides validated player coords.
    if data.toType == 'newdrop' then
        local from = Inventory.get(source)
        local slot = from and from.items[data.fromSlot]
        if not slot or not data.coords then return false end

        local count = math.min(data.count or slot.count, slot.count)
        local dropId = Drops.create(data.coords, slot.name, count, slot.metadata, source)
        if not dropId then return false end

        from:removeFromSlot(data.fromSlot, count)
        pushSlots(from, { data.fromSlot })
        pushWeight(source)
        return true
    end

    local from = resolve(source, data.fromType)
    local to   = resolve(source, data.toType)
    if not from or not to then return false end

    -- Anti-exploit: read-only containers are handled by buy/craft, not drag.
    if from.type == 'shop' or to.type == 'shop'
        or from.type == 'crafting' or to.type == 'crafting' then
        return false
    end

    local ok = Transfer.move(from, data.fromSlot, to, data.toSlot, data.count)
    if not ok then return false end

    -- Keep every viewer of both containers in sync.
    pushSlots(from, { data.fromSlot })
    pushSlots(to, { data.toSlot })

    -- Container weight propagation to the holding inventory.
    if from.type == 'container' then updateContainerParent(from.id) end
    if to.type == 'container' then updateContainerParent(to.id) end

    pushWeight(source)

    -- Clean up emptied drops
    if from.type == 'drop' and not next(from.items) then
        Drops.remove(from.id)
    end

    return true
end)

lib.callback.register('lk_inv:buyItem', function(source, data)
    if type(data) ~= 'table' then return false end

    local shopId = openSecondary[source]
    local shop = shopId and Inventory.get(shopId)
    if not shop or shop.type ~= 'shop' then return false end

    local shopSlot = shop.items[data.fromSlot]
    if not shopSlot then return false end

    local player = Inventory.get(source)
    if not player then return false end

    local count = math.max(1, math.floor(data.count or 1))
    local price = (shopSlot.price or 0) * count
    local buyWeight = Inventory.slotWeight(shopSlot.name, count)

    local account = shopSlot.currency == 'bank' and 'bank' or 'cash'
    if not Money.afford(source, price, account) then return false end
    if not player:canHold(buyWeight) then return false end

    local ok, moneyChanged = Money.chargeAccount(source, price, account)
    if not ok then return false end

    local target = player:findStack(shopSlot.name, {}) or player:firstFree()
    if not target then return false end

    player:addItem(shopSlot.name, count, {})

    pushSlots(player, moneyChanged)
    pushSlots(player, { target })
    pushWeight(source)
    notify(source, shopSlot.name, 'ui_added', count)
    return true
end)

lib.callback.register('lk_inv:craftItem', function(source, data)
    if type(data) ~= 'table' then return false end

    local benchId = openSecondary[source]
    local bench = benchId and Inventory.get(benchId)
    if not bench or bench.type ~= 'crafting' then return false end

    local recipe = bench.items[data.fromSlot]
    if not recipe then return false end

    local player = Inventory.get(source)
    if not player then return false end

    local count = math.max(1, math.floor(data.count or 1))
    local ingredients = recipe.ingredients or {}
    local resultCount = (recipe.count or 1) * count

    -- Verify the player has every ingredient.
    for name, req in pairs(ingredients) do
        if itemCount(player, name) < req * count then return false end
    end

    -- Net weight feasibility (ingredients are removed, result is added).
    local ingWeight = 0
    for name, req in pairs(ingredients) do
        ingWeight = ingWeight + Inventory.slotWeight(name, req * count)
    end
    local resultWeight = Inventory.slotWeight(recipe.name, resultCount)
    if player.weight - ingWeight + resultWeight > player.maxWeight then return false end

    -- Consume ingredients, then add the result.
    local changed = {}
    for name, req in pairs(ingredients) do
        removeByName(player, name, req * count, changed)
    end

    local target = player:findStack(recipe.name, {}) or player:firstFree()
    if not target then return false end
    player:addItem(recipe.name, resultCount, {})
    changed[#changed + 1] = target

    pushSlots(player, changed)
    pushWeight(source)
    notify(source, recipe.name, 'ui_added', resultCount)
    return true
end)

--- Validate a vehicle storage request and load the container keyed by plate.
--- Returns the container id the client should then open, or nil.
lib.callback.register('lk_inv:prepVehicle', function(source, data)
    if type(data) ~= 'table' or not data.netId then return nil end

    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    -- Anti-exploit: the player must actually be next to the vehicle.
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 8.0 then
        return nil
    end

    local plate = GetVehicleNumberPlateText(entity)
    plate = plate and plate:gsub('%s+$', '') or ''
    if plate == '' then return nil end

    local vtype = data.vtype == 'glovebox' and 'glovebox' or 'trunk'
    local id = ('%s_%s'):format(vtype, plate)

    if not Inventory.get(id) then
        -- Size depends on the vehicle (class/model sent by the client).
        local slots, weight = vehicleSpace(tonumber(data.class) or -1,
            data.model and tostring(data.model):lower() or nil, vtype)

        Inventory.create(id, {
            type = vtype,
            owner = id,
            label = ('%s %s'):format(vtype == 'trunk' and 'Trunk' or 'Glovebox', plate),
            slots = slots,
            maxWeight = weight,
            items = Db.load(id, vtype),
            persist = true,
        })
    end

    return id
end)

--- Current cargo load (0..1) of a vehicle's trunk, for the handling penalty.
--- Does not force-load the trunk (returns 0 when it hasn't been opened).
lib.callback.register('lk_inv:trunkLoad', function(source, plate)
    if not plate then return 0 end
    local inv = Inventory.get(('trunk_%s'):format(tostring(plate):gsub('%s+$', '')))
    if not inv or inv.maxWeight <= 0 then return 0 end
    return math.min(inv.weight / inv.maxWeight, 1.0)
end)

lib.callback.register('lk_inv:useItem', function(source, slotId)
    if not Security.allow(source, 'use') then return false end

    local inv = Inventory.get(source)
    local slot = inv and inv.items[slotId]
    if not slot then return false end

    local def = Inventory.itemDef(slot.name)
    if not def or not def.usable then return false end

    -- Weapon: client equips/holsters it.
    if def.weapon then
        return { weapon = { slot = slotId, name = slot.name, metadata = slot.metadata or {} } }
    end

    -- Component: client attaches it to the equipped weapon.
    if def.component then
        return { component = { slot = slotId, name = slot.name } }
    end

    -- Container (bag): open its own inventory, loading it on demand.
    if def.container then
        slot.metadata = slot.metadata or {}
        if not slot.metadata.container then
            slot.metadata.container = ('cont_%d_%d'):format(slotId, math.random(10000, 99999))
            inv.dirty = true
        end
        local cid = slot.metadata.container
        if not Inventory.get(cid) then
            Inventory.create(cid, {
                type = 'container', owner = cid, label = def.label or 'Container',
                slots = def.container.slots or 10, maxWeight = def.container.weight or 20000,
                items = Db.load(cid, 'container'), persist = true,
            })
        end
        return { open = cid }
    end

    -- Carriable heavy item: client picks it up in hand.
    if def.carry then
        return { carry = { slot = slotId, name = slot.name } }
    end

    -- Consumable: notify listeners and decrement by one.
    TriggerEvent('lk_inv:itemUsed', source, slot.name, slot.metadata)
    inv:removeFromSlot(slotId, 1)
    pushSlots(inv, { slotId })
    pushWeight(source)
    notify(source, slot.name, 'ui_removed', 1)
    return true
end)

--- Persist a weapon's live state (ammo/durability/components) from the client.
RegisterNetEvent('lk_inv:syncWeapon', function(slotId, data)
    local src = source
    local inv = Inventory.get(src)
    local slot = inv and inv.items[slotId]
    if not slot or type(data) ~= 'table' then return end

    local def = Inventory.itemDef(slot.name)
    if not def or not def.weapon then return end

    slot.metadata = slot.metadata or {}
    if data.ammo ~= nil then slot.metadata.ammo = data.ammo end
    if data.durability ~= nil then slot.metadata.durability = data.durability end
    if data.components ~= nil then slot.metadata.components = data.components end
    inv.dirty = true
    pushSlots(inv, { slotId })
end)

--- Attach a component item to a weapon. Returns the component name to apply.
lib.callback.register('lk_inv:attachComponent', function(source, data)
    if type(data) ~= 'table' then return false end
    local inv = Inventory.get(source)
    if not inv then return false end

    local weapon = inv.items[data.weaponSlot]
    local comp = inv.items[data.componentSlot]
    if not weapon or not comp then return false end

    local wdef = Inventory.itemDef(weapon.name)
    local cdef = Inventory.itemDef(comp.name)
    if not wdef or not wdef.weapon or not cdef or not cdef.component then return false end

    weapon.metadata = weapon.metadata or {}
    weapon.metadata.components = weapon.metadata.components or {}
    weapon.metadata.components[#weapon.metadata.components + 1] = comp.name

    inv:removeFromSlot(data.componentSlot, 1)
    inv.dirty = true
    pushSlots(inv, { data.weaponSlot, data.componentSlot })
    return comp.name
end)

--- Remove a component from a weapon and return the item to the inventory.
lib.callback.register('lk_inv:removeComponent', function(source, data)
    if type(data) ~= 'table' then return false end
    local inv = Inventory.get(source)
    if not inv then return false end

    local weapon = inv.items[data.slot]
    if not weapon or not weapon.metadata or not weapon.metadata.components then return false end

    local comps = weapon.metadata.components
    local removed
    for i = #comps, 1, -1 do
        if comps[i] == data.component then
            table.remove(comps, i)
            removed = true
            break
        end
    end
    if not removed then return false end

    inv:addItem(data.component, 1, {})
    inv.dirty = true
    pushSlots(inv, { data.slot })
    return data.component
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
    if count < 1 then return false end

    -- Cash uses the framework account when available.
    if slot.name == 'money' and Money.useFramework(source) then
        local amount = math.min(count, Money.get(source))
        if amount <= 0 then return false end
        if not Framework.removeMoney(source, 'cash', amount) then return false end
        Framework.addMoney(target, 'cash', amount)
        pushSlots(from, Money.syncItem(source))
        pushSlots(to, Money.syncItem(target))
        return true
    end

    local before = to:findStack(slot.name, slot.metadata) or to:firstFree()
    if not to:addItem(slot.name, count, slot.metadata) then return false end
    from:removeFromSlot(data.slot, count)

    pushSlots(from, { data.slot })
    if before then pushSlots(to, { before }) end
    pushWeight(source)
    pushWeight(target)
    notify(target, slot.name, 'ui_added', count)
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

exports('DeleteContainer', function(containerId)
    if not containerId then return false end
    Inventory.remove(containerId)
    Db.delete(containerId, 'container')
    return true
end)

exports('GetMoney', function(source)
    return Money.get(source)
end)
