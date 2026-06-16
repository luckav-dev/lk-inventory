local Utils = require 'shared.utils'

--- Thin framework abstraction. Exposes a uniform interface regardless of the
--- underlying framework so the inventory core never references qb-core/ESX
--- directly. QBCore/Qbox and ESX are wired up; standalone is the fallback.
---@class Framework
local Framework = {
    name = 'standalone',
}

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

-- Defaults (overridden per framework). Returning nil from getMoney signals the
-- caller to fall back to the in-inventory `money` item.
function Framework.getPlayer(_) return nil end
function Framework.getMoney(_, _) return nil end
function Framework.addMoney(_, _, _) return false end
function Framework.removeMoney(_, _, _) return false end
function Framework.getGroups(_) return {} end

CreateThread(function()
    Framework.name = detect()
    Utils.log('info', 'framework detected:', Framework.name)

    if Framework.name == 'qb' or Framework.name == 'qbx' then
        local coreRes = Framework.name == 'qb' and 'qb-core' or 'qbx_core'
        while GetResourceState(coreRes) ~= 'started' do Wait(100) end

        local QB = Framework.name == 'qb' and exports['qb-core']:GetCoreObject() or exports.qbx_core
        local getP = function(src)
            return Framework.name == 'qb' and QB.Functions.GetPlayer(src) or QB:GetPlayer(src)
        end

        Framework.getPlayer = function(src)
            local p = getP(src)
            if not p then return nil end
            local pd = p.PlayerData
            return { id = pd.citizenid,
                     name = ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname) }
        end

        Framework.getMoney = function(src, account)
            local p = getP(src)
            return p and p.PlayerData.money[account or 'cash'] or nil
        end
        Framework.addMoney = function(src, account, amount)
            local p = getP(src); if not p then return false end
            return p.Functions.AddMoney(account or 'cash', amount) and true
        end
        Framework.removeMoney = function(src, account, amount)
            local p = getP(src); if not p then return false end
            return p.Functions.RemoveMoney(account or 'cash', amount) and true
        end
        Framework.getGroups = function(src)
            local p = getP(src); if not p then return {} end
            local pd = p.PlayerData
            return {
                [pd.job.name] = pd.job.grade.level,
                [pd.gang.name] = pd.gang.grade.level,
            }
        end

        AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
            local pd = player and player.PlayerData
            if pd then fireLoaded(pd.source, pd.citizenid,
                ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname)) end
        end)
        AddEventHandler('QBCore:Server:OnPlayerUnload', fireDropped)
    elseif Framework.name == 'esx' then
        local ESX = exports.es_extended:getSharedObject()

        Framework.getPlayer = function(src)
            local p = ESX.GetPlayerFromId(src)
            if not p then return nil end
            return { id = p.identifier, name = p.getName and p.getName() or p.name }
        end
        Framework.getMoney = function(src, account)
            local p = ESX.GetPlayerFromId(src); if not p then return nil end
            if account == 'bank' then
                local acc = p.getAccount('bank'); return acc and acc.money or 0
            end
            return p.getMoney()
        end
        Framework.addMoney = function(src, account, amount)
            local p = ESX.GetPlayerFromId(src); if not p then return false end
            if account == 'bank' then p.addAccountMoney('bank', amount) else p.addMoney(amount) end
            return true
        end
        Framework.removeMoney = function(src, account, amount)
            local p = ESX.GetPlayerFromId(src); if not p then return false end
            if account == 'bank' then p.removeAccountMoney('bank', amount) else p.removeMoney(amount) end
            return true
        end
        Framework.getGroups = function(src)
            local p = ESX.GetPlayerFromId(src); if not p then return {} end
            return { [p.job.name] = p.job.grade }
        end

        RegisterNetEvent('esx:playerLoaded', function(src, xPlayer)
            fireLoaded(src, xPlayer.identifier, xPlayer.getName and xPlayer.getName() or xPlayer.name)
        end)
        AddEventHandler('esx:playerDropped', fireDropped)
    else
        Framework.getPlayer = function(src)
            local id = GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
            return { id = id, name = GetPlayerName(src) or ('Player ' .. src) }
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
