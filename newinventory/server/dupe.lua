local Inventory = require 'server.inventory'

--- Duplication detection. Every non-stackable item instance carries a unique
--- identifier (`__uid`, or a weapon serial / container id). A given identifier
--- must exist in exactly one place at a time, so finding it in two inventories
--- means it was duplicated. This module only *detects*; the caller decides what
--- to do (log / flag / remove the copy).
local Dupe = {}

local function identifierOf(slot)
    local m = slot.metadata
    if not m then return nil end
    return m.__uid or m.serial or m.container
end

--- @return table[] duplicates  list of { invId, slotId, id } for each extra copy
function Dupe.scan()
    local seen, dupes = {}, {}

    for invId, inv in pairs(Inventory.all()) do
        for slotId, slot in pairs(inv.items) do
            local id = identifierOf(slot)
            if id then
                if seen[id] then
                    dupes[#dupes + 1] = { invId = invId, slotId = slotId, id = id, name = slot.name }
                else
                    seen[id] = true
                end
            end
        end
    end

    return dupes
end

return Dupe
