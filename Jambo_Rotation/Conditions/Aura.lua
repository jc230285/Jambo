local ADDON, NS = ...
local Rot = NS.Rot

Rot:RegisterCondition("AURA", function(cond, step)
    local unit = cond.unit or "player"
    
    -- 1. Determine Filter (HELPFUL vs HARMFUL)
    local filter = cond.isDebuff and "HARMFUL" or "HELPFUL"
    if cond.sourceIsPlayer then filter = filter .. "|PLAYER" end
    
    local found = false
    local foundExpiration = 0
    local foundCount = 0
    local foundName = ""

    -- 2. Scan Auras
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitAura(unit, i, filter)
        if not name then break end
        
        local match = true
        
        -- Name / ID Match
        if cond.spellID and cond.spellID > 0 then
            if spellId ~= tonumber(cond.spellID) then match = false end
        elseif cond.nameContains and cond.nameContains ~= "" then
            if not string.find(string.lower(name), string.lower(cond.nameContains), 1, true) then 
                match = false 
            end
        elseif not cond.anyAura then
            -- If no name/id specified and not "Any Aura", what are we looking for?
            -- Assume match if Dispel type checked below, otherwise fail if empty config
            if not cond.dispelTypes or #cond.dispelTypes == 0 then match = false end
        end
        
        -- Dispel Type Match
        if match and cond.dispelTypes and #cond.dispelTypes > 0 then
            local dtMatch = false
            for _, dt in ipairs(cond.dispelTypes) do
                if debuffType == dt then dtMatch = true; break end
            end
            if not dtMatch then match = false end
        end
        
        -- Time Remaining Check
        if match and cond.checkTime then
            local remain = 0
            if expirationTime and expirationTime > 0 then
                remain = expirationTime - GetTime()
            end
            
            local val = tonumber(cond.timeValue) or 0
            local op = cond.timeOp or "<"
            
            if op == "<" and not (remain < val) then match = false
            elseif op == ">" and not (remain > val) then match = false
            elseif op == "<=" and not (remain <= val) then match = false
            elseif op == ">=" and not (remain >= val) then match = false
            end
        end

        if match then
            found = true
            foundName = name
            foundExpiration = expirationTime
            foundCount = count
            break
        end
    end

    -- 3. Results
    local pass = found
    if cond.missing then pass = not found end
    
    local note = foundName ~= "" and foundName or (cond.isDebuff and "Debuff" or "Buff")
    if cond.missing then note = "Missing " .. note end
    
    -- Value to show in UI (Time remaining or Stacks)
    local valDisp = 0
    if found then
        if foundExpiration and foundExpiration > 0 then
            valDisp = string.format("%.1fs", foundExpiration - GetTime())
        else
            valDisp = "Active" -- Permanent aura
        end
    else
        valDisp = "None"
    end

    return pass, note, valDisp
end)