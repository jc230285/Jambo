local ADDON, NS = ...
local Rot = NS.Rot

Rot:RegisterCondition("COMBAT", function(cond, step)
    local inCombat = UnitAffectingCombat("player")
    local pass = false
    
    if cond.value == true then pass = (inCombat == true)
    else pass = (inCombat == false) end
    
    local note = inCombat and "In Combat" or "Out of Combat"
    local value = 999 -- Hidden by UI
    
    return pass, note, value
end)