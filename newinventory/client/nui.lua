local Client = require 'client.main'

--- Find the closest player's server id (used for giving items).
local function closestPlayer()
    local me = cache.ped
    local myCoords = GetEntityCoords(me)
    local closest, closestDist

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= me and DoesEntityExist(ped) then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist < 3.0 and (not closestDist or dist < closestDist) then
                closest, closestDist = GetPlayerServerId(playerId), dist
            end
        end
    end

    return closest
end

--- Every handler MUST call cb(); a missing cb() permanently stalls NUI fetches.

RegisterNUICallback('uiLoaded', function(_, cb)
    Client.uiLoaded = true
    cb(1)
end)

RegisterNUICallback('exit', function(_, cb)
    Client.closeInventory()
    cb(1)
end)

RegisterNUICallback('closeConfig', function(_, cb)
    Client.closeInventory()
    cb(1)
end)

RegisterNUICallback('swapItems', function(data, cb)
    -- Ground drop: inject the player's validated coords server-side.
    if data and data.toType == 'newdrop' then
        if cache.vehicle then return cb(false) end
        local coords = GetEntityCoords(cache.ped)
        data.coords = vec3(coords.x, coords.y, coords.z)
    end
    cb(lib.callback.await('lk_inv:swap', false, data) or false)
end)

RegisterNUICallback('useItem', function(slot, cb)
    cb(lib.callback.await('lk_inv:useItem', false, slot) or false)
end)

RegisterNUICallback('giveItem', function(data, cb)
    local target = closestPlayer()
    if not target then return cb(false) end
    cb(lib.callback.await('lk_inv:give', false, {
        slot = data and data.slot, count = (data and data.count) or 1, target = target,
    }) or false)
end)

RegisterNUICallback('getItemData', function(name, cb)
    cb(lib.callback.await('lk_inv:getItemData', false, name))
end)

-- Features not yet implemented in this foundation: acknowledge cleanly so the
-- UI never stalls.
RegisterNUICallback('buyItem', function(_, cb) cb(false) end)
RegisterNUICallback('craftItem', function(_, cb) cb(false) end)
RegisterNUICallback('removeAmmo', function(_, cb) cb(false) end)
RegisterNUICallback('removeComponent', function(_, cb) cb(false) end)
RegisterNUICallback('useButton', function(_, cb) cb(false) end)
RegisterNUICallback('lootAllComplete', function(_, cb) cb(1) end)
RegisterNUICallback('toggleClothing', function(_, cb) cb(1) end)
RegisterNUICallback('lk_inventory:checkStashPin', function(_, cb)
    cb({ required = false, unlocked = true })
end)
RegisterNUICallback('lk_inventory:unlockStashPin', function(_, cb)
    cb({ success = true })
end)
