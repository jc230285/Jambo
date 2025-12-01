local ADDON, NS = ...
local Rot = NS.Rot

Rot:RegisterCondition("UNIT_TYPE", function(cond, step)
    local unit = cond.unit or "target"
    if not UnitExists(unit) then return false, "No Unit", "None" end
    
    local values = { strsplit(",", string.lower(cond.values or "")) }
    local matched = false
    local matchType = ""
    
    for _, v in ipairs(values) do
        v = strtrim(v)
        
        -- 1. Reaction
        if v == "enemy" and UnitIsEnemy("player", unit) then matched = true; matchType="Enemy"
        elseif v == "friendly" and UnitIsFriend("player", unit) then matched = true; matchType="Friendly"
        
        -- 2. Creature Type
        elseif UnitCreatureType(unit) and string.lower(UnitCreatureType(unit)) == v then 
            matched = true; matchType=UnitCreatureType(unit)
            
        -- 3. Roles (Classic Heuristic)
        elseif v == "tank" then
            -- Classic doesn't have robust roles, assume Tank if holding aggro or specific classes?
            -- Fallback requested: "fallback to DPS" if logic fails implies we return false for tank
            -- Real logic: Check UnitGroupRolesAssigned (Retail) or heuristics
            local role = UnitGroupRolesAssigned(unit)
            if role == "TANK" then matched = true; matchType="Tank" end
        
        elseif v == "dps" then
            local role = UnitGroupRolesAssigned(unit)
            if role == "DAMAGER" or role == "NONE" then matched = true; matchType="DPS" end
        
        elseif v == "healer" then
            local role = UnitGroupRolesAssigned(unit)
            if role == "HEALER" then matched = true; matchType="Healer" end
            
        elseif v == "player" and UnitIsPlayer(unit) then matched = true; matchType="Player"
        end
        
        if matched then break end
    end
    
    return matched, (matched and matchType or "No Match"), (cond.values or "")
end)