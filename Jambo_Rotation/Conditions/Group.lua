local ADDON, NS = ...
local Rot = NS.Rot

Rot:RegisterCondition("IN_GROUP", function(cond, step)
    local inRaid = IsInRaid()
    local inGroup = IsInGroup()
    
    local status = "Solo"
    if inRaid then status = "Raid"
    elseif inGroup then status = "Party" end
    
    local pass = false
    if cond.groupType == "ANY" and inGroup then pass = true
    elseif cond.groupType == "RAID" and inRaid then pass = true
    elseif cond.groupType == "PARTY" and (inGroup and not inRaid) then pass = true
    elseif cond.groupType == "SOLO" and not inGroup then pass = true
    end
    
    return pass, status, ""
end)