local Utils = require 'shared.utils'

--- Thin framework abstraction. Exposes a uniform interface regardless of the
--- underlying framework so the inventory core never references qb-core/ESX
--- directly. QBCore is wired up first; others can be added the same way.
---@class Framework
---@field name string
---@field getPlayer fun(source: integer): { id: string, name: string }|nil
---@field onLoaded fun(cb: fun(source: integer, id: string, name: string))
---@field onDropped fun(cb: fun(source: integer))
local Framework = {}

local function detect()
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

local loadedCbs, droppedCbs = {}, {}

function Framework.onLoaded(cb) loadedCbs[#loadedCbs + 1] = cb end
function Framework.onDropped(cb) droppedCbs[#droppedCbs + 1] = cb end

local function fireLoaded(source, id, name)
    for i = 1, #loadedCbs do loadedCbs[i](source, id, name) end
end

local function fireDropped(source)
    for i = 1, #droppedCbs do droppedCbs[i](source) end
end

CreateThread(function()
    Framework.name = detect()
    Utils.log('info', 'framework detected:', Framework.name)

    if Framework.name == 'qb' or Framework.name == 'qbx' then
        local export = Framework.name == 'qb' and exports['qb-core'] or exports.qbx_core
        -- Wait for the core to be reachable, then bridge its lifecycle events.
        while GetResourceState(Framework.name == 'qb' and 'qb-core' or 'qbx_core') ~= 'started' do Wait(100) end

        local Core = Framework.name == 'qb' and export:GetCoreObject() or nil

        Framework.getPlayer = function(source)
            local p = Framework.name == 'qb' and Core.Functions.GetPlayer(source) or export:GetPlayer(source)
            if not p then return nil end
            local pd = p.PlayerData
            return {
                id = pd.citizenid,
                name = ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname),
            }
        end

        AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
            local pd = (player and player.PlayerData) or nil
            if not pd then return end
            fireLoaded(pd.source, pd.citizenid,
                ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname))
        end)
        AddEventHandler('QBCore:Server:OnPlayerUnload', fireDropped)
    elseif Framework.name == 'esx' then
        local ESX = exports.es_extended:getSharedObject()
        Framework.getPlayer = function(source)
            local p = ESX.GetPlayerFromId(source)
            if not p then return nil end
            return { id = p.identifier, name = p.getName and p.getName() or p.name }
        end
        RegisterNetEvent('esx:playerLoaded', function(source, xPlayer)
            fireLoaded(source, xPlayer.identifier, xPlayer.getName and xPlayer.getName() or xPlayer.name)
        end)
        AddEventHandler('esx:playerDropped', fireDropped)
    else
        -- Standalone: identify by license, load on first spawn.
        Framework.getPlayer = function(source)
            local id = GetPlayerIdentifierByType(source, 'license') or ('src:' .. source)
            return { id = id, name = GetPlayerName(source) or ('Player ' .. source) }
        end
        AddEventHandler('playerJoining', function()
            local src = source
            local p = Framework.getPlayer(src)
            if p then fireLoaded(src, p.id, p.name) end
        end)
    end
end)

AddEventHandler('playerDropped', function()
    fireDropped(source)
end)

return Framework
