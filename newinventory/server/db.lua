local Utils = require 'shared.utils'

--- Persistence layer. Uses its own table/schema (independent of any other
--- inventory resource): a single row per (owner, type) holding the slot list
--- as JSON.
local Db = {}

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `lk_inventories` (
    `owner_id`   VARCHAR(80)  NOT NULL,
    `inv_type`   VARCHAR(40)  NOT NULL DEFAULT 'player',
    `slots_json` LONGTEXT     NULL,
    `last_saved` TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner_id`, `inv_type`)
)
]]

function Db.init()
    MySQL.query(SCHEMA, {}, function()
        Utils.log('info', 'database ready (table lk_inventories)')
    end)
end

--- @param ownerId string
--- @param invType string?
--- @return table slots  array of stored slots (empty when none)
function Db.load(ownerId, invType)
    local stored = MySQL.scalar.await(
        'SELECT slots_json FROM lk_inventories WHERE owner_id = ? AND inv_type = ?',
        { ownerId, invType or 'player' }
    )

    if not stored then return {} end

    local ok, decoded = pcall(json.decode, stored)
    return (ok and type(decoded) == 'table') and decoded or {}
end

--- @param ownerId string
--- @param invType string?
--- @param slots table  array of slots to persist
function Db.save(ownerId, invType, slots)
    MySQL.prepare(
        [[INSERT INTO lk_inventories (owner_id, inv_type, slots_json)
          VALUES (?, ?, ?)
          ON DUPLICATE KEY UPDATE slots_json = VALUES(slots_json)]],
        { ownerId, invType or 'player', json.encode(slots or {}) }
    )
end

--- @param ownerId string
--- @param invType string?
function Db.delete(ownerId, invType)
    MySQL.prepare('DELETE FROM lk_inventories WHERE owner_id = ? AND inv_type = ?',
        { ownerId, invType or 'player' })
end

--- @return boolean exists
function Db.exists(ownerId, invType)
    return MySQL.scalar.await(
        'SELECT 1 FROM lk_inventories WHERE owner_id = ? AND inv_type = ?',
        { ownerId, invType or 'player' }) ~= nil
end

return Db
