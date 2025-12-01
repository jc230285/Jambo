local ADDON, NS = ...
local Rot = NS.Rot

local function GetSpellID(name)
    local raw = _G.JamboSpells and _G.JamboSpells.data.spells
    if not raw then return nil end
    for _, info in ipairs(raw) do
        if info.NAME == name and info.SLOT > 0 then return info.ID end
    end
    for _, info in ipairs(raw) do
        if info.NAME == name then return info.ID end
    end
    return nil
end

Rot:RegisterCondition("SPELL_READY", function(cond, step)
    local targetName = (cond.spell == "Auto" or cond.spell == nil) and step.name or cond.spell
    local spellID = GetSpellID(targetName)
    
    if not spellID then return false, "NoID", 0 end
    
    local isReady = true
    local checks = {}
    local cdRemain = 0
    
    -- A. Mana
    if cond.checkMana then
        table.insert(checks, "M")
        local usable, noMana = IsUsableSpell(spellID)
        if not usable or noMana then isReady = false end
    end
    
    -- B. Range
    if cond.checkRange then
        table.insert(checks, "R")
        if isReady then
            local inRange = IsSpellInRange(GetSpellInfo(spellID), cond.unit or "target")
            if inRange == 0 then isReady = false end
        end
    end
    
    -- C. Slot
    if cond.checkSlot then
        table.insert(checks, "S")
    end
    
    -- D. Cooldown (Time)
    if cond.checkCDTime then
        table.insert(checks, "T")
        local start, duration = GetSpellCooldown(spellID)
        if start > 0 then cdRemain = duration - (GetTime() - start) end
        if cdRemain < 0 then cdRemain = 0 end

        if isReady then
            local val = tonumber(cond.cdValue) or 0
            local op = cond.op or "<"
            if op == "<" and not (cdRemain < val) then isReady = false
            elseif op == ">" and not (cdRemain > val) then isReady = false
            elseif op == "=" and not (math.abs(cdRemain - val) < 0.1) then isReady = false
            end
        end
    end
    
    local note = table.concat(checks, " ")
    local valueStr = string.format("%.1fs", cdRemain)
    
    return isReady, note, valueStr
end)
-- Timestamp: 2023-12-04 15:00:00