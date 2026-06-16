--- Movement realism: a heavy load slows the player. The server pushes the
--- current weight ratio (0..1); above a threshold the ped's move rate is scaled
--- down proportionally.

local THRESHOLD = 0.85   -- start slowing past 85% of max weight
local MAX_PENALTY = 0.25 -- up to -25% move rate at full load

local ratio = 0

RegisterNetEvent('lk_inv:weight', function(value)
    ratio = tonumber(value) or 0
end)

CreateThread(function()
    while true do
        if ratio > THRESHOLD then
            local over = math.min((ratio - THRESHOLD) / (1.0 - THRESHOLD), 1.0)
            SetPedMoveRateOverride(cache.ped, 1.0 - over * MAX_PENALTY)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
