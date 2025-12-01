local ADDON, NS = ...
local Rot = NS.Rot

-- Helper: Get Spell ID for condition checking
local function GetSpellIDForCondition(stepName, condSpellName)
    local targetName = (condSpellName == "Auto" or condSpellName == nil) and stepName or condSpellName
    local groups = Rot:GetGroupedSpells()
    local g = groups[targetName]
    
    if g and g.ranks then
        -- Find first slotted rank to check shared cooldowns/range
        for _, r in ipairs(g.ranks) do 
            if r.SLOT > 0 then return r.ID end 
        end
        -- If none slotted, return any rank ID (checks like Mana/Range might still work via API)
        if g.ranks[1] then return g.ranks[1].ID end
    end
    return nil
end

function Rot:EvaluateConditions(step)
    if not step.conditions or #step.conditions == 0 then return true, {} end
    
    local allPass = true
    local results = {}
    
    for i, cond in ipairs(step.conditions) do
        local pass = false
        
        -- === COMBAT ===
        if cond.type == "COMBAT" then
            local inCombat = UnitAffectingCombat("player")
            -- cond.value is the *required* state (true=in combat, false=out)
            if cond.value == true then pass = (inCombat == true)
            else pass = (inCombat == false) end
            
        -- === SPELL READY ===
        elseif cond.type == "SPELL_READY" then
            local spellID = GetSpellIDForCondition(step.name, cond.spell)
            
            if spellID then
                local isReady = true
                
                -- 1. Slot Check
                if cond.checkSlot then
                    -- We verified slot existence in GetSpellIDForCondition somewhat,
                    -- but let's be strict if requested.
                    -- (Requires finding slot again or trusting logic)
                end
                
                -- 2. Usable (Mana/Stance)
                if isReady and cond.checkMana then
                    local usable, noMana = IsUsableSpell(spellID)
                    if not usable or noMana then isReady = false end
                end
                
                -- 3. Range
                if isReady and cond.checkRange then
                    -- 1=True, 0=False, nil=Invalid Target
                    local inRange = IsSpellInRange(GetSpellInfo(spellID), cond.unit or "target")
                    if inRange == 0 then isReady = false end
                end
                
                -- 4. Off Cooldown (Binary)
                if isReady and cond.checkCD then
                    local start, duration = GetSpellCooldown(spellID)
                    if start > 0 and duration > 1.5 then isReady = false end
                end
                
                -- 5. Cooldown Time (Advanced)
                if isReady and cond.checkCDTime then
                    local start, duration = GetSpellCooldown(spellID)
                    local remain = 0
                    if start > 0 then remain = duration - (GetTime() - start) end
                    
                    local val = tonumber(cond.cdValue) or 0
                    local op = cond.op or "<"
                    
                    if op == "<" and not (remain < val) then isReady = false
                    elseif op == ">" and not (remain > val) then isReady = false
                    elseif op == "=" and not (math.abs(remain - val) < 0.1) then isReady = false
                    elseif op == "!=" and (math.abs(remain - val) < 0.1) then isReady = false
                    end
                end
                
                pass = isReady
            else
                pass = false -- Spell not found
            end
        end
        
        -- "Condition Must Be TRUE" logic (cond.expected defaults to true)
        -- If user unchecked "Expected", they want the condition to FAIL (NOT logic)
        local expected = (cond.expected == nil) and true or cond.expected
        if pass ~= expected then pass = false else pass = true end
        
        table.insert(results, { type=cond.type, pass=pass, val=cond.value })
        if not pass then allPass = false end
    end
    
    return allPass, results
end

function Rot:AddCondition(stepIndex, data)
    local step = NS.db.steps[stepIndex]
    if step then
        step.conditions = step.conditions or {}
        table.insert(step.conditions, data)
    end
end

function Rot:RemoveCondition(stepIndex, condIndex)
    local step = NS.db.steps[stepIndex]
    if step and step.conditions then
        table.remove(step.conditions, condIndex)
    end
end