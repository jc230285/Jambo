local ADDON, NS = ...
local Rot = NS.Rot

-- Helper: Get Resource Values
local function GetResourceInfo(unit, resource, incoming)
    local current, max = 0, 0
    local name = "Unknown"
    
    if resource == "hp" then
        name = "Health"
        current = UnitHealth(unit)
        max = UnitHealthMax(unit)
        if incoming and UnitGetIncomingHeals then
            current = current + (UnitGetIncomingHeals(unit) or 0)
        end
        
    elseif resource == "mana" then
        name = "Mana"
        current = UnitPower(unit, 0) -- 0 = Mana
        max = UnitPowerMax(unit, 0)
        
    elseif resource == "rage" then
        name = "Rage"
        current = UnitPower(unit, 1) -- 1 = Rage
        max = UnitPowerMax(unit, 1)
        
    elseif resource == "energy" then
        name = "Energy"
        current = UnitPower(unit, 3) -- 3 = Energy
        max = UnitPowerMax(unit, 3)
        
    elseif resource == "combo" then
        name = "Combo Pts"
        -- Classic Era: Combo points are Player vs Target
        current = GetComboPoints("player", "target")
        max = 5
    end
    
    return current, max, name
end

Rot:RegisterCondition("RESOURCE", function(cond, step)
    local unit = cond.unit or "player"
    local resource = cond.resource or "hp"
    
    -- 1. Get Values
    local cur, max, resName = GetResourceInfo(unit, resource, cond.includeIncoming)
    
    -- 2. Calculate Comparison Value
    local checkVal = tonumber(cond.value) or 0
    
    -- Handle Percent
    local curVal = cur
    if cond.percent and max > 0 then
        curVal = (cur / max) * 100
    end
    
    -- 3. Compare
    local op = cond.operator or "<"
    local pass = false
    
    if op == "<" then pass = (curVal < checkVal)
    elseif op == ">" then pass = (curVal > checkVal)
    elseif op == "<=" then pass = (curVal <= checkVal)
    elseif op == ">=" then pass = (curVal >= checkVal)
    elseif op == "=" then pass = (math.abs(curVal - checkVal) < 0.1)
    elseif op == "!=" then pass = (math.abs(curVal - checkVal) > 0.1)
    end
    
    -- 4. Note/Value for UI
    local symbol = cond.percent and "%" or ""
    local note = string.format("%s %s %s%s", resName, op, checkVal, symbol)
    local valDisp = string.format("%.0f%s", curVal, symbol)
    
    return pass, note, valDisp
end)