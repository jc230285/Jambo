local ADDON, NS = ...

NS.Engine = NS.Engine or {}
local E = NS.Engine

local Utils = NS.Utils

local function resolveSpell(step)
    if not step or not step.name then return nil end
    local key = step.name
    if step.criteria and step.criteria ~= "RANK" then key = step.name .. "_" .. step.criteria end
    return NS.Book[key] or NS.Book[step.name]
end

function E:CheckSpell(step)
    local data = resolveSpell(step)
    if not data then return false, "Unknown" end

    local usable, noMana
    if data.slot and data.slot > 0 then usable, noMana = IsUsableAction(data.slot) else usable, noMana = IsUsableSpell(data.name) end
    if not usable then return false, noMana and "No Mana" or "Unusable" end

    local start, duration = 0, 0
    if data.slot and data.slot > 0 then start, duration = GetActionCooldown(data.slot) else start, duration = GetSpellCooldown(data.id or data.name) end
    if duration and duration > 1.5 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0.1 then return false, string.format("CD %.1fs", remaining) end
    end

    if data.slot and data.slot > 0 and UnitExists("target") then
        local inRange = IsActionInRange(data.slot)
        if inRange == 0 then return false, "Range" end
    end
    return true, "Ready"
end

function E:CheckResource(c)
    local unit = c.unit or "player"
    if not UnitExists(unit) then return false, "No Unit" end

    local current, max = 0, 0
    if c.resType == "HEALTH" then
        current = UnitHealth(unit)
        max = UnitHealthMax(unit)
        if c.incHeal then current = current + (UnitGetIncomingHeals(unit) or 0) end
    else
        local pType = Utils.GetPowerTypeID(c.resType)
        current = UnitPower(unit, pType)
        max = UnitPowerMax(unit, pType)
    end

    local value = current
    if c.mode == "percent" and max > 0 then value = (current / max) * 100 end
    if c.mode == "deficit" then value = max - current end

    return Utils.Compare(value, c.op, c.val), Utils.FormatVal(value)
end

function E:CheckAura(c)
    local unit = c.unit or "target"
    if not UnitExists(unit) then return false, "No Unit" end

    local needleName = c.auraName and string.lower(c.auraName) or ""
    local needleID = tonumber(c.auraName)
    local filter = c.isDebuff and "HARMFUL" or "HELPFUL"
    if c.ownOnly then filter = filter .. "|PLAYER" end

    local found, stacks, expires = false, 0, 0
    
    -- If we're doing status checking with empty name, check both HARMFUL and HELPFUL
    local filtersToCheck = {filter}
    if needleName == "" and c.checkStatus and c.statusTypes and #c.statusTypes > 0 then
        filtersToCheck = {"HARMFUL", "HELPFUL"}
        if c.ownOnly then 
            filtersToCheck = {"HARMFUL|PLAYER", "HELPFUL|PLAYER"}
        end
    end
    
    for _, checkFilter in ipairs(filtersToCheck) do
        for i = 1, 40 do
            local name, _, count, _, _, exp, _, isStealable, _, sid = UnitAura(unit, i, checkFilter)
        if not name then break end
        local match = false
        
        -- Check name/ID matching first
        if needleID and sid == needleID then match = true end
        if not needleID and needleName ~= "" and string.find(string.lower(name), needleName, 1, true) then match = true end
        if not needleID and needleName == "" then match = true end  -- Match any aura if no name specified
        
        -- Check if stealable requirement is met
        if match and c.isStealable and not isStealable then match = false end
        
        -- Check status type if specified (this should work even with empty aura names)
        if c.checkStatus and c.statusTypes and #c.statusTypes > 0 then
            local hasStatus = false
            for _, statusType in ipairs(c.statusTypes) do
                local statusMatch = false
                if statusType == "Slowed" then 
                    statusMatch = string.find(string.lower(name), "slow", 1, true) ~= nil or string.find(string.lower(name), "crippl", 1, true) ~= nil
                elseif statusType == "Stunned" then 
                    statusMatch = string.find(string.lower(name), "stun", 1, true) ~= nil or string.find(string.lower(name), "bash", 1, true) ~= nil or string.find(string.lower(name), "hammer", 1, true) ~= nil
                elseif statusType == "Incapacitated" then 
                    statusMatch = string.find(string.lower(name), "incapacitat", 1, true) ~= nil or string.find(string.lower(name), "sleep", 1, true) ~= nil or string.find(string.lower(name), "sap", 1, true) ~= nil
                elseif statusType == "Feared" then 
                    statusMatch = string.find(string.lower(name), "fear", 1, true) ~= nil or string.find(string.lower(name), "terror", 1, true) ~= nil
                elseif statusType == "Charmed" then 
                    statusMatch = string.find(string.lower(name), "charm", 1, true) ~= nil or string.find(string.lower(name), "mind control", 1, true) ~= nil
                elseif statusType == "Rooted" then 
                    statusMatch = string.find(string.lower(name), "root", 1, true) ~= nil or string.find(string.lower(name), "entangle", 1, true) ~= nil or string.find(string.lower(name), "nature's grasp", 1, true) ~= nil
                elseif statusType == "Silenced" then 
                    statusMatch = string.find(string.lower(name), "silence", 1, true) ~= nil or string.find(string.lower(name), "mute", 1, true) ~= nil
                elseif statusType == "Bleeding" then 
                    statusMatch = string.find(string.lower(name), "bleed", 1, true) ~= nil or string.find(string.lower(name), "rend", 1, true) ~= nil or string.find(string.lower(name), "deep wounds", 1, true) ~= nil
                elseif statusType == "Poisoned" then 
                    statusMatch = string.find(string.lower(name), "poison", 1, true) ~= nil or string.find(string.lower(name), "venom", 1, true) ~= nil
                end
                if statusMatch then
                    hasStatus = true
                    break  -- Found at least one matching status
                end
            end
            
            -- If we have status checking enabled, override match based on status
            if needleName == "" then
                -- Empty name: only match if status matches
                match = hasStatus
            else
                -- Named aura: must match name AND status (if status checking enabled)
                if not hasStatus then match = false end
            end
        end
        
        if match then 
            found = true
            stacks = count or 0
            -- Fix stack count: if stacks are 9, treat as 1
            if stacks == 9 then stacks = 1 end
            expires = exp or 0
            break 
        end
    end
    
    if found then break end -- Stop checking other filters if we found something
end

    local remaining = 0
    if found and expires > 0 then remaining = expires - GetTime() end

    if c.checkStack then
        if not found and c.stackVal and c.stackVal > 0 then return false, "Missing" end
        if not Utils.Compare(stacks, c.stackOp, c.stackVal) then return false, "Stk:" .. Utils.FormatVal(stacks) end
    end

    if c.checkTime then
        if not Utils.Compare(remaining, c.timeOp, c.timeVal) then return false, "Tm:" .. Utils.FormatVal(remaining) end
    end

    if not c.checkStack and not c.checkTime and not found then return false, "Missing" end

    return true, found and "Found" or "Missing"
end

function E:CheckSpellCond(c, step)
    local spellName = (not c.spellCondName or c.spellCondName == "" or c.spellCondName == "AUTO") and (step and step.name) or c.spellCondName
    if not spellName then return false, "Unk" end
    local data = NS.Book[spellName]
    if not data then return false, "Unk" end

    -- Default operators/values so compares don't fail on nil
    c.cdOp = c.cdOp or "<="
    c.cdVal = c.cdVal or 0

    local cd = 0
    local charges = 0
    if c.chkCD or c.chkRemain then
        local start, duration = 0, 0
        if data.slot and data.slot > 0 then
            start, duration = GetActionCooldown(data.slot)
        else
            start, duration = GetSpellCooldown(data.id or data.name)
        end
        if duration and duration > 1.5 then cd = (start + duration) - GetTime() end
        if cd < 0 then cd = 0 end
        if c.chkCD and not Utils.Compare(cd, c.cdOp, c.cdVal) then return false, "CD:" .. Utils.FormatVal(cd) end
        if c.chkRemain and not Utils.Compare(cd, c.remOp, c.remVal) then return false, "Rem:" .. Utils.FormatVal(cd) end
    end

    if c.chkCharges then
        if data.id then charges = select(1, GetSpellCharges(data.id)) or 0 end
        if not Utils.Compare(charges, c.chargesOp, c.chargesVal) then return false, "Chg:" .. Utils.FormatVal(charges) end
    end

    if c.chkMana then
        local usable, noMana
        if data.slot and data.slot > 0 then usable, noMana = IsUsableAction(data.slot) else usable, noMana = IsUsableSpell(data.name) end
        if noMana then return false, "Mana" end
    end

    if c.chkRange then
        local unit = c.rangeUnit or "target"
        if not UnitExists(unit) then 
            return false, "NoUnit" 
        end
        
        local inRange = nil
        if data.slot and data.slot > 0 then
            inRange = IsActionInRange(data.slot, unit)
        else
            inRange = IsSpellInRange(data.name, unit)
        end
        
        -- inRange: 1=in range, 0=out of range, nil=no range limit
        local rangeStatus = "?"
        if inRange == 1 then rangeStatus = "IN"
        elseif inRange == 0 then rangeStatus = "OUT"
        else rangeStatus = "NIL" end
        
        -- If spell has a range and we're out of range, fail
        if inRange == 0 and data.range and data.range > 0 then 
            return false, "OutOfRange(max:" .. data.range .. ")" 
        end
        -- If inRange is nil but spell has a range, assume out of range to be safe
        if inRange == nil and data.range and data.range > 0 then
            return false, "Range?(" .. rangeStatus .. ",max:" .. data.range .. ")" 
        end
    end

    local parts = {}
    table.insert(parts, "CD:" .. Utils.FormatVal(cd))
    if charges and charges >= 0 then table.insert(parts, "Chg:" .. Utils.FormatVal(charges)) end
    
    -- Add range check status if enabled
    if c.chkRange then
        local unit = c.rangeUnit or "target"
        if UnitExists(unit) then
            local inRange = nil
            if data.slot and data.slot > 0 then
                inRange = IsActionInRange(data.slot, unit)
            else
                inRange = IsSpellInRange(data.name, unit)
            end
            local rangeStr = "?"
            if inRange == 1 then rangeStr = "IN"
            elseif inRange == 0 then rangeStr = "OUT"
            else rangeStr = "NIL" end
            table.insert(parts, "RngChk:" .. rangeStr)
        end
    end
    
    return true, table.concat(parts, " ")
end

local function triStateCheck(value, expected)
    if not expected or expected == "IGNORE" then return true end
    local want = expected == "TRUE"
    return value == want
end

function E:CheckUnit(c)
    local unit = c.unit or "player"
    if not UnitExists(unit) then return false, "No Unit" end

    -- Combat checks
    local inCombat = UnitAffectingCombat(unit) and true or false
    if c.inCombat and not inCombat then return false, "NotInCombat" end
    if c.outCombat and inCombat then return false, "InCombat" end

    -- Mount checks  
    local mounted = IsMounted()
    if c.mounted and not mounted then return false, "NotMounted" end
    if c.notMounted and mounted then return false, "Mounted" end

    -- Movement checks
    local moving = GetUnitSpeed(unit) > 0
    if c.moving and not moving then return false, "NotMoving" end
    if c.notMoving and moving then return false, "Moving" end

    -- Group type checks
    if c.groupType and c.groupType ~= "any" then
        -- Safe group detection with fallbacks for different WoW versions
        local inParty = false
        local inRaid = false
        
        if GetNumGroupMembers then
            -- Modern API
            local numGroup = GetNumGroupMembers()
            local numRaid = GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE) or 0
            inParty = numGroup > 1 and numRaid == 0
            inRaid = numRaid > 0
        elseif GetNumPartyMembers and GetNumRaidMembers then
            -- Classic API
            inParty = GetNumPartyMembers() > 0
            inRaid = GetNumRaidMembers() > 0
        else
            -- Fallback: assume solo if functions don't exist
            inParty = false
            inRaid = false
        end
        
        if c.groupType == "solo" and (inParty or inRaid) then return false, "NotSolo" end
        if c.groupType == "party" and not (inParty and not inRaid) then return false, "NotParty" end
        if c.groupType == "raid" and not inRaid then return false, "NotRaid" end
    end

    -- Form checks (for druids)
    if c.checkForm then
        local formName = c.formType or "Human Form"
        local currentForm = "Human Form"
        
        -- Get current shapeshift form
        for i = 1, GetNumShapeshiftForms() do
            local _, isActive, _, spellId = GetShapeshiftFormInfo(i)
            if isActive then
                local formSpellName = GetSpellInfo(spellId)
                if formSpellName then
                    currentForm = formSpellName
                    break
                end
            end
        end
        
        if currentForm ~= formName then
            return false, "Form:" .. currentForm
        end
    end

    -- Role checks
    if c.checkRole then
        local roleType = c.roleType or "DPS"  -- Default to DPS if none specified
        local currentRole = "DPS"  -- Default assumption
        
        -- Detect role based on various factors
        if GetNumPartyMembers or GetNumGroupMembers then
            -- Try to get role from party/raid assignment if available
            local assignedRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
            if assignedRole == "TANK" then currentRole = "Tank"
            elseif assignedRole == "HEALER" then currentRole = "Healer"
            elseif assignedRole == "DAMAGER" then currentRole = "DPS"
            else
                -- Fallback: detect by class and talents/abilities
                local _, class = UnitClass("player")
                if class == "WARRIOR" or class == "PALADIN" then
                    -- Check if they have tanking abilities/stance
                    if GetShapeshiftFormInfo and GetShapeshiftFormInfo(2) then  -- Defensive Stance for Warriors
                        local _, isActive = GetShapeshiftFormInfo(2)
                        if isActive then currentRole = "Tank" end
                    elseif class == "PALADIN" then
                        -- Check for Righteous Fury (tanking aura) or similar
                        local hasDefAura = false
                        for i = 1, 40 do
                            local name = UnitAura("player", i, "HELPFUL")
                            if not name then break end
                            if string.find(string.lower(name), "righteous fury", 1, true) or 
                               string.find(string.lower(name), "devotion", 1, true) then
                                hasDefAura = true
                                break
                            end
                        end
                        if hasDefAura then currentRole = "Tank" end
                    end
                elseif class == "PRIEST" or class == "PALADIN" or class == "SHAMAN" or class == "DRUID" then
                    -- Check if they're healing (simplified check)
                    if class == "PRIEST" then currentRole = "Healer" end
                    -- For hybrid classes, default stays DPS unless detected otherwise
                end
                -- All other classes default to DPS
            end
        end
        
        if currentRole ~= roleType then
            return false, "Role:" .. currentRole
        end
    end

    return true, "Pass"
end

function E:CheckUnitTarget(c)
    local unit = c.targetUnit or "target"
    if not UnitExists(unit) then return false, "No Unit" end

    -- Raid marker check
    if c.checkRaidMark then
        local markIndex = GetRaidTargetIndex(unit)
        local expectedMark = {
            ["Star"] = 1, ["Circle"] = 2, ["Diamond"] = 3, ["Triangle"] = 4,
            ["Moon"] = 5, ["Square"] = 6, ["Cross"] = 7, ["Skull"] = 8
        }
        local expected = expectedMark[c.raidMark]
        if markIndex ~= expected then 
            return false, "Mark:" .. (markIndex or "none") 
        end
    end

    -- Death state checks
    local isDead = UnitIsDeadOrGhost(unit)
    if c.isDead and not isDead then return false, "NotDead" end
    if c.notDead and isDead then return false, "Dead" end

    -- Hostility checks
    if c.friendly or c.hostile then
        local canAttack = UnitCanAttack("player", unit)
        if c.friendly and canAttack then return false, "NotFriendly" end
        if c.hostile and not canAttack then return false, "NotHostile" end
    end

    -- Player/NPC checks
    if c.isPlayer or c.nonPlayer then
        local isPlayer = UnitIsPlayer(unit)
        if c.isPlayer and not isPlayer then return false, "NotPlayer" end
        if c.nonPlayer and isPlayer then return false, "IsPlayer" end
    end

    -- Attackable check
    if c.attackable then
        if not UnitCanAttack("player", unit) then return false, "NotAttackable" end
    end

    -- Casting check
    if c.casting then
        local spell, _, _, _, endTime = UnitCastingInfo(unit)
        local channeled, _, _, _, endTime2 = UnitChannelInfo(unit)
        if not spell and not channeled then return false, "NotCasting" end
    end

    -- Range check
    if c.checkRange then
        local range = c.rangeVal or 30
        local inRange = CheckInteractDistance(unit, 4) -- General interaction distance
        -- For more precise range checking, we'd need to use spell range checks
        if not inRange and range <= 5 then return false, "OutOfRange" end
    end

    -- Class check
    if c.checkClass then
        local _, unitClass = UnitClass(unit)
        if unitClass ~= string.upper(c.classType or "WARRIOR") then 
            return false, "Class:" .. (unitClass or "unknown") 
        end
    end

    -- Unit type check (creature type)
    if c.checkUnitType and c.unitTypes and #c.unitTypes > 0 then
        local creatureType = UnitCreatureType(unit)
        local found = false
        for _, expectedType in ipairs(c.unitTypes) do
            if creatureType == expectedType then
                found = true
                break
            end
        end
        if not found then 
            return false, "Type:" .. (creatureType or "unknown") 
        end
    end

    return true, "Pass"
end

function E:EvaluateStep(step)
    if step and step.disabled then return false, "Disabled" end
    local ready, msg = E:CheckSpell(step)
    if not ready then return false, msg end

    if step.conditions then
        for idx, cond in ipairs(step.conditions) do
            local pass, val = false, ""
            if cond.type == "RESOURCE" then pass, val = E:CheckResource(cond)
            elseif cond.type == "AURA" then pass, val = E:CheckAura(cond)
            elseif cond.type == "SPELL" then pass, val = E:CheckSpellCond(cond, step)
            elseif cond.type == "UNIT" then pass, val = E:CheckUnitTarget(cond)
            elseif cond.type == "PLAYER" then pass, val = E:CheckUnit(cond)
            else pass, val = false, "BadType" end

            cond.lastVal = val
            -- Apply trueFlag logic: if trueFlag is false, invert the result
            if cond.trueFlag == false then
                cond.lastPass = not pass  -- Invert the result
            else
                cond.lastPass = pass      -- Use result as-is (default behavior)
            end
            
            if not cond.lastPass then return false, "Cond #" .. idx end
        end
    end

    return true, "GO"
end

function E:ResolveSpell(step)
    return resolveSpell(step)
end