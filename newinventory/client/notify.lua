local Config = require 'config.config'

--- Notification abstraction. Lets a server use ox_lib's notifications, the
--- native GTA feed, or its own system — auto-detected by default so we never
--- force ox_lib's style or collide with another notification resource.
local Notify = {}

local function provider()
    local p = Config.notify.provider
    if p == 'oxlib' or p == 'native' or p == 'custom' then return p end
    -- auto: prefer ox_lib's notify when present.
    if GetResourceState('ox_lib') == 'started' and lib and lib.notify then
        return 'oxlib'
    end
    return 'native'
end

--- @param data { title?: string, description: string, type?: 'success'|'error'|'inform' }
function Notify.send(data)
    if type(data) ~= 'table' or not data.description then return end
    local p = provider()

    if p == 'oxlib' then
        lib.notify({
            title = data.title,
            description = data.description,
            type = data.type or 'inform',
            position = Config.notify.position,
        })
    elseif p == 'custom' then
        -- The server/another resource decides how to render it.
        TriggerEvent('lk_inv:notification', data)
    else
        -- Native GTA notification feed (always available, no dependency).
        BeginTextCommandThefeedPost('STRING')
        local text = data.title and ('~b~' .. data.title .. '~s~\n' .. data.description) or data.description
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- Allow other inventory modules and the server to trigger a notification.
RegisterNetEvent('lk_inv:notify_msg', function(data) Notify.send(data) end)

_G.LkNotify = Notify
return Notify
