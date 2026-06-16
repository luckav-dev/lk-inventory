-- Unit tests for the pure inventory logic (model + transfer). These run under
-- stock Lua 5.4 with light mocks; they are NOT loaded by FiveM.
--   Run from the resource root:  LK_ROOT=. lua5.4 tests/run.lua

package.path = (os.getenv('LK_ROOT') or '.') .. '/?.lua;' .. package.path

-- Deterministic, order-independent serializer good enough for metadata equality.
local function enc(v)
    local t = type(v)
    if t ~= 'table' then
        if t == 'string' then return string.format('%q', v) end
        return tostring(v)
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. '=' .. enc(v[k]) end
    return '{' .. table.concat(parts, ',') .. '}'
end
json = { encode = enc, decode = function() return {} end }

-- FiveM's vector constructor (config files use it).
function vec3(x, y, z) return { x = x, y = y, z = z } end

local Inventory = require 'server.inventory'
local Transfer  = require 'server.transfer'

local passed, failed = 0, 0
local function check(name, cond)
    if cond then
        passed = passed + 1
        print('  ok   ' .. name)
    else
        failed = failed + 1
        print('  FAIL ' .. name)
    end
end

local function newInv(id, opts)
    opts = opts or {}
    opts.slots = opts.slots or 10
    opts.maxWeight = opts.maxWeight or 100000
    return Inventory.create(id, opts)
end

-- addItem: basic, stacking, no-stack, weight reject
do
    local inv = newInv('p1')
    check('addItem returns true', inv:addItem('water', 2) == true)
    check('water in slot 1', inv.items[1] and inv.items[1].name == 'water')
    check('water count 2', inv.items[1].count == 2)
    check('weight = 2*500', inv.weight == 1000)

    inv:addItem('water', 3)
    check('water stacks to 5', inv.items[1].count == 5)

    inv:addItem('phone')
    inv:addItem('phone')
    check('phone does not stack (slot 2 & 3)', inv.items[2] and inv.items[3] and inv.items[2].name == 'phone')

    local tiny = newInv('p2', { maxWeight = 600 })
    check('first water fits', tiny:addItem('water') == true)  -- 500
    check('second water rejected (weight)', tiny:addItem('water') == false)
end

-- removeFromSlot: partial and full
do
    local inv = newInv('p3')
    inv:addItem('water', 5)
    inv:removeFromSlot(1, 2)
    check('partial remove leaves 3', inv.items[1].count == 3)
    check('weight recalculated', inv.weight == 1500)
    inv:removeFromSlot(1, 3)
    check('full remove clears slot', inv.items[1] == nil)
    check('weight zero', inv.weight == 0)
end

-- Transfer: move to empty, stack, swap, split, weight reject
do
    local a = newInv('a1'); local b = newInv('b1')
    a:addItem('water', 4)

    check('move full to empty', Transfer.move(a, 1, b, 1, 4) == true)
    check('source emptied', a.items[1] == nil)
    check('dest has 4 water', b.items[1] and b.items[1].count == 4)

    -- split
    local c = newInv('c1'); local d = newInv('d1')
    c:addItem('water', 6)
    Transfer.move(c, 1, d, 1, 2)
    check('split leaves 4 in source', c.items[1].count == 4)
    check('split puts 2 in dest', d.items[1].count == 2)

    -- stack onto matching
    Transfer.move(c, 1, d, 1, 4)
    check('stack merges to 6', d.items[1].count == 6)

    -- swap two different items
    local e = newInv('e1')
    e:addItem('water', 1)   -- slot 1
    e:addItem('phone')      -- slot 2
    Transfer.move(e, 1, e, 2, 1)
    check('swap: slot1 now phone', e.items[1].name == 'phone')
    check('swap: slot2 now water', e.items[2].name == 'water')

    -- weight reject across inventories
    local big = newInv('big'); local small = newInv('small', { maxWeight = 300 })
    big:addItem('water', 1) -- 500g
    check('cross-move rejected by weight', Transfer.move(big, 1, small, 1, 1) == false)
    check('source intact after reject', big.items[1] and big.items[1].count == 1)
end

-- Containers: id assigned, self-nest blocked
do
    local inv = newInv('cont1')
    inv:addItem('bag')
    local bagSlot = inv.items[1]
    check('bag gets a container id', bagSlot.metadata and bagSlot.metadata.container ~= nil)

    -- simulate the bag's own inventory existing and try to nest the bag in itself
    local cid = bagSlot.metadata.container
    local bagInv = Inventory.create(cid, { type = 'container', slots = 5, maxWeight = 40000 })
    check('nesting bag into itself is blocked', Transfer.move(inv, 1, bagInv, 1, 1) == false)

    -- A second, different bag must also be rejected from going into a container.
    inv:addItem('bag')
    local otherBag = Inventory.create('cont_other', { type = 'container', slots = 5, maxWeight = 40000 })
    check('nesting any bag in a container is blocked', Transfer.move(inv, 2, otherBag, 1, 1) == false)
end

-- Charges: limited-use items initialise their `uses` metadata
do
    local inv = newInv('uses1')
    inv:addItem('spray')
    check('spray initialises uses=10', inv.items[1].metadata and inv.items[1].metadata.uses == 10)
end

-- Container weight propagation: holder slot reflects contents
do
    local holder = newInv('h1')
    holder:addItem('bag')
    local cid = holder.items[1].metadata.container
    local bag = Inventory.create(cid, { type = 'container', slots = 5, maxWeight = 40000 })
    bag:addItem('water', 2) -- 1000g inside the bag

    holder:recalcWeight()
    local eff = holder:effectiveWeight(holder.items[1])
    check('bag effective weight = base + contents', eff == (Inventory.slotWeight('bag', 1) + 1000))
    check('holder total includes bag contents', holder.weight == eff)
end

print(('\n%d passed, %d failed'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
