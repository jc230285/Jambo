-- Jambo Rotation - Range Checking Module
-- Provides efficient range detection for spells

local ADDON, NS = ...

NS.Range = NS.Range or {}
local Range = NS.Range

-- Cache action slots for spells to avoid repeated scanning
local actionSlotCache = {}
local cacheTime = 0
local CACHE_DURATION = 5 -- Rebuild cache every 5 seconds

-- Known distance checkpoints using CheckInteractDistance
-- These are EXTREMELY fast (orders of magnitude faster than IsActionInRange)
local DISTANCE_CHECKPOINTS = {
    { yards = 10, checkType = 3 },   -- Duel distance
    { yards = 28, checkType = 4 },   -- Follow distance
}

-- Build/rebuild action slot cache
local function RebuildActionCache()
    local now = GetTime()
    if now - cacheTime < CACHE_DURATION then return end
    
    wipe(actionSlotCache)
    
    for slot = 1, 120 do
        local actionType = GetActionInfo(slot)
        if actionType == "spell" then
            local actionName = GetActionText(slot)
            if not actionName then
                GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                GameTooltip:SetAction(slot)
                actionName = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
                GameTooltip:Hide()
            end
            
            if actionName then
                actionSlotCache[actionName] = slot
            end
        end
    end
    
    cacheTime = now
end

-- Get cached action slot for a spell name
local function GetActionSlot(spellName)
    RebuildActionCache()
    return actionSlotCache[spellName]
end

-- Fast distance estimate using CheckInteractDistance
-- Returns: estimated max yards target is within
function Range:EstimateDistance(unit)
    if not UnitExists(unit) then return nil end
    
    -- Check from smallest to largest distance
    if CheckInteractDistance(unit, 3) then
        return 10 -- Within duel range
    elseif CheckInteractDistance(unit, 4) then
        return 28 -- Within follow range
    else
        return 40 -- Beyond follow range (estimate)
    end
end

-- Check if spell is in range using the most appropriate method
-- Returns: true/false/nil (nil = no target or cannot determine)
function Range:IsSpellInRange(spellName, unit)
    unit = unit or "target"
    
    if not UnitExists(unit) then return nil end
    
    -- Method 1: Try IsActionInRange if we have the spell on action bars (ONLY for alive targets)
    if not UnitIsDead(unit) then
        local slot = GetActionSlot(spellName)
        if slot then
            local inRange = IsActionInRange(slot, unit)
            if inRange ~= nil then
                return inRange == 1
            end
        end
    end
    
    -- Method 2: Fallback to distance estimation using CheckInteractDistance
    -- This works for both alive and dead targets, extremely fast
    local maxRange = NS.Book and NS.Book[spellName] and NS.Book[spellName].range
    if not maxRange then
        -- Default ranges for common spell types if not in book
        if spellName:find("Auto Attack") then
            maxRange = 5
        else
            maxRange = 30 -- Assume typical caster range
        end
    end
    
    local estimatedDistance = self:EstimateDistance(unit)
    if not estimatedDistance then return nil end
    
    -- If spell range is <= 10 yards, check duel distance
    if maxRange <= 10 then
        return CheckInteractDistance(unit, 3)
    end
    
    -- If spell range is <= 28 yards, check follow distance
    if maxRange <= 28 then
        return CheckInteractDistance(unit, 4)
    end
    
    -- For longer ranges, we can't accurately check with CheckInteractDistance
    -- Return true if within follow range (conservative estimate)
    return estimatedDistance <= 28
end

-- Get range status string for display
-- Returns: "InRange", "OutOfRange", "NoLim", or "NoTarget"
function Range:GetRangeStatus(spellName, unit)
    unit = unit or "target"
    
    if not UnitExists(unit) then return "NoTarget" end
    
    -- Check if spell has a range requirement
    local slot = GetActionSlot(spellName)
    if slot and not ActionHasRange(slot) then
        return "NoLim" -- No range limit
    end
    
    local inRange = self:IsSpellInRange(spellName, unit)
    
    if inRange == nil then return "NoLim" end
    if inRange then return "InRange" end
    return "OutOfRange"
end

-- Get numeric range status (for backward compatibility)
-- Returns: 1 (in range), 0 (out of range), nil (no limit/no target)
function Range:GetRangeNumeric(spellName, unit)
    local status = self:GetRangeStatus(spellName, unit)
    if status == "InRange" then return 1 end
    if status == "OutOfRange" then return 0 end
    return nil
end

-- Clear cache (call when action bars change)
function Range:ClearCache()
    wipe(actionSlotCache)
    cacheTime = 0
end

-- Debug: Print cache contents
function Range:DebugCache()
    print("=== Action Slot Cache ===")
    for name, slot in pairs(actionSlotCache) do
        print(string.format("%s: slot %d", name, slot))
    end
end
