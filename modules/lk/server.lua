if not lib or not IsDuplicityVersion() then return end

local pinStashes = {}
local unlocked = {}

local function stashKey(stash)
    return tostring(stash or '')
end

local function sourceUnlocked(source, stash)
    stash = stashKey(stash)
    return unlocked[source] and unlocked[source][stash] == true
end

local function setUnlocked(source, stash)
    stash = stashKey(stash)
    unlocked[source] = unlocked[source] or {}
    unlocked[source][stash] = true
end

local function normalizeConfig(config)
    if type(config) == 'string' or type(config) == 'number' then
        return { pin = tostring(config) }
    end

    if type(config) ~= 'table' then return end
    if not config.pin then return end

    return {
        pin = tostring(config.pin),
        label = config.label,
    }
end

local function RegisterPinStash(stashName, config)
    if type(stashName) ~= 'string' then return false end

    local normalized = normalizeConfig(config)
    if not normalized then return false end

    pinStashes[stashName] = normalized
    return true
end

local function SetStashPin(stashName, pin)
    return RegisterPinStash(stashName, { pin = pin })
end

local function ClearStashPin(stashName)
    if type(stashName) ~= 'string' then return false end

    pinStashes[stashName] = nil

    for source in pairs(unlocked) do
        unlocked[source][stashName] = nil
    end

    return true
end

for stashName, config in pairs(lib.load('data.pins') or {}) do
    RegisterPinStash(stashName, config)
end

exports('RegisterPinStash', RegisterPinStash)
exports('SetStashPin', SetStashPin)
exports('ClearStashPin', ClearStashPin)

lib.callback.register('lk_inventory:checkStashPin', function(source, stash)
    stash = stashKey(stash)
    local config = pinStashes[stash]

    return {
        required = config ~= nil,
        unlocked = not config or sourceUnlocked(source, stash),
        label = config and config.label or nil,
    }
end)

lib.callback.register('lk_inventory:unlockStashPin', function(source, data)
    local stash = stashKey(type(data) == 'table' and data.stash or nil)
    local pin = type(data) == 'table' and tostring(data.pin or '') or ''
    local config = pinStashes[stash]

    if not config then
        return { success = true }
    end

    if pin == config.pin then
        setUnlocked(source, stash)
        TriggerClientEvent('lk_inventory:pinUnlocked', source, stash)
        return { success = true }
    end

    return { success = false, error = 'PIN incorrecto' }
end)

exports[shared.resource]:registerHook('swapItems', function(payload)
    local source = payload.source

    if not source then return end

    local fromInventory = stashKey(payload.fromInventory)
    local toInventory = stashKey(payload.toInventory)

    if pinStashes[fromInventory] and not sourceUnlocked(source, fromInventory) then
        return false
    end

    if pinStashes[toInventory] and not sourceUnlocked(source, toInventory) then
        return false
    end
end)

AddEventHandler('playerDropped', function()
    unlocked[source] = nil
end)
