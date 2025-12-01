local ADDON, NS = ...
local Rot = NS.Rot

Rot:RegisterCondition("MOVING", function(cond, step)
    local unit = cond.unit or "player"
    local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed(unit)
    
    local isMoving = (currentSpeed > 0)
    
    -- cond.value: true = Must be moving, false = Must be stationary
    local pass = (cond.value == isMoving)
    
    local note = isMoving and "Moving" or "Stationary"
    return pass, note, string.format("%.1f", currentSpeed)
end)