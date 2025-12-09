local ADDON, NS = ...

-- Create main debug frame
local frame = CreateFrame("Frame", "JamboDebugFrame", UIParent, "BackdropTemplate")
frame:SetSize(400, 500)
frame:SetPoint("CENTER", 0, 0)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2
})
frame:SetBackdropColor(0, 0, 0, 0.9)
frame:SetBackdropBorderColor(1, 1, 1, 1)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetFrameStrata("HIGH")
frame:Hide()

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("Jambo Range Debug")

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Scroll frame for text
local scrollFrame = CreateFrame("ScrollFrame", "JamboDebugScrollFrame", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

-- Content frame inside scroll
local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(360, 1)
scrollFrame:SetScrollChild(content)

-- Info text (EditBox for copyable text)
local info = CreateFrame("EditBox", nil, content)
info:SetPoint("TOPLEFT", 5, 0)
info:SetPoint("TOPRIGHT", -5, 0)
info:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
info:SetMultiLine(true)
info:SetAutoFocus(false)
info:SetMaxLetters(0)
info:EnableMouse(true)
info:SetScript("OnEscapePressed", function() info:ClearFocus() end)

-- Test spell data - multiple spells with different ranges
local TEST_SPELLS = {
    {name = "Fire Blast", id = 2136, range = 20},
    {name = "Frostbolt", id = 116, range = 30},
    {name = "Scorch", id = 2948, range = 30},
    {name = "Fireball", id = 133, range = 35},
}
local TEST_SPELL_NAME = "Fire Blast"
local TEST_SPELL_ID = 2136

-- Update function
local function UpdateDebugInfo()
    if not UnitExists("target") then
        local noTargetText = "No target selected\n\nTarget an enemy to see range data."
        info:SetText(noTargetText)
        info:SetHeight(100)
        return
    end
    
    local lines = {}
    
    -- Basic target info
    table.insert(lines, "|cff00ff00=== TARGET INFO ===|r")
    table.insert(lines, "Name: " .. (UnitName("target") or "Unknown"))
    table.insert(lines, "Level: " .. (UnitLevel("target") or "??"))
    table.insert(lines, "Class: " .. (UnitClassification("target") or "normal"))
    table.insert(lines, "Exists: " .. tostring(UnitExists("target")))
    table.insert(lines, "IsEnemy: " .. tostring(UnitCanAttack("player", "target")))
    table.insert(lines, "IsDead: " .. tostring(UnitIsDead("target")))
    
    if UnitIsDead("target") then
        table.insert(lines, "")
        table.insert(lines, "|cffff0000WARNING: Target is DEAD!|r")
        table.insert(lines, "|cffff0000IsActionInRange only works on LIVE targets!|r")
        table.insert(lines, "|cffff0000Target a LIVING enemy to test range.|r")
    end
    
    table.insert(lines, "")
    
    -- Spell book info
    table.insert(lines, "|cff00ff00=== SPELL BOOK DATA ===|r")
    local spellName, spellRank = GetSpellInfo(TEST_SPELL_ID)
    if spellName then
        table.insert(lines, "Spell: " .. spellName .. " (" .. (spellRank or "no rank") .. ")")
        table.insert(lines, "ID: " .. TEST_SPELL_ID)
        
        -- Try to find spell in spellbook using GetSpellBookItemName (Classic API)
        local i = 1
        local foundSlot = nil
        while true do
            local name, rank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if not name then break end
            
            if name == TEST_SPELL_NAME then
                foundSlot = i
                break
            end
            i = i + 1
        end
        
        if foundSlot then
            table.insert(lines, "Spellbook Slot: " .. foundSlot)
        else
            table.insert(lines, "Spellbook Slot: NOT FOUND")
        end
    else
        table.insert(lines, "Spell NOT FOUND in game data")
    end
    table.insert(lines, "")
    
    -- Action bar scanning for Fire Blast
    table.insert(lines, "|cff00ff00=== ACTION BAR SCAN ===|r")
    local foundActions = {}
    for slot = 1, 120 do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "spell" then
            local actionName = GetActionText(slot)
            if not actionName then
                -- Try to get from action tooltip
                GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                GameTooltip:SetAction(slot)
                actionName = GameTooltipTextLeft1:GetText()
                GameTooltip:Hide()
            end
            
            if actionName and string.find(string.lower(actionName), "fire blast") then
                table.insert(foundActions, {
                    slot = slot,
                    name = actionName,
                    id = id
                })
            end
        end
    end
    
    if #foundActions > 0 then
        for _, action in ipairs(foundActions) do
            table.insert(lines, "Found in slot " .. action.slot .. ": " .. action.name)
        end
    else
        table.insert(lines, "Fire Blast NOT found on action bars")
    end
    table.insert(lines, "")
    
    -- Range check methods
    table.insert(lines, "|cff00ff00=== RANGE CHECK METHODS ===|r")
    
    -- Method 1: ActionHasRange
    if #foundActions > 0 then
        for _, action in ipairs(foundActions) do
            local hasRange = ActionHasRange(action.slot)
            table.insert(lines, "ActionHasRange(" .. action.slot .. "): " .. tostring(hasRange))
        end
    else
        table.insert(lines, "ActionHasRange: |cffff0000N/A (no action bar slot)|r")
    end
    
    -- Method 2: IsActionInRange (requires spell on action bar)
    if #foundActions > 0 then
        for _, action in ipairs(foundActions) do
            local inRange = IsActionInRange(action.slot)
            local rangeStr = "nil"
            if inRange == 1 then rangeStr = "|cff00ff001 (IN RANGE)|r"
            elseif inRange == 0 then rangeStr = "|cffff00000 (OUT OF RANGE)|r"
            end
            table.insert(lines, "IsActionInRange(" .. action.slot .. "): " .. rangeStr)
        end
    else
        table.insert(lines, "IsActionInRange: |cffff0000N/A (no action bar slot)|r")
    end
    
    -- Method 3: IsActionInRange with unit parameter
    if #foundActions > 0 then
        for _, action in ipairs(foundActions) do
            local inRange = IsActionInRange(action.slot, "target")
            local rangeStr = "nil"
            if inRange == 1 then rangeStr = "|cff00ff001 (IN RANGE)|r"
            elseif inRange == 0 then rangeStr = "|cffff00000 (OUT OF RANGE)|r"
            end
            table.insert(lines, "IsActionInRange(" .. action.slot .. ", 'target'): " .. rangeStr)
        end
    else
        table.insert(lines, "IsActionInRange(slot, 'target'): |cffff0000N/A|r")
    end
    
    -- Method 4: CheckInteractDistance (various distances)
    table.insert(lines, "")
    table.insert(lines, "CheckInteractDistance:")
    local distChecks = {
        {idx = 1, desc = "Inspect (11.11 yards)"},
        {idx = 2, desc = "Trade (11.11 yards)"},
        {idx = 3, desc = "Duel (10 yards)"},
        {idx = 4, desc = "Follow (28 yards)"}
    }
    for _, check in ipairs(distChecks) do
        local result = CheckInteractDistance("target", check.idx)
        local resultStr = result and "|cff00ff00YES|r" or "|cffff0000NO|r"
        table.insert(lines, "  " .. check.desc .. ": " .. resultStr)
    end
    
    -- Method 5: Manual distance checks using CheckInteractDistance
    table.insert(lines, "")
    table.insert(lines, "Distance Estimates:")
    if CheckInteractDistance("target", 3) then
        table.insert(lines, "  |cff00ff00<= 10 yards|r (Duel range)")
        table.insert(lines, "  |cff00ff00SPELL IS IN RANGE (20y)|r")
    elseif CheckInteractDistance("target", 4) then
        table.insert(lines, "  |cffffff00<= 28 yards|r (Follow range)")
        table.insert(lines, "  |cffffff00SPELL IS IN RANGE (20y)|r")
    else
        table.insert(lines, "  |cffff0000> 28 yards|r (Out of follow range)")
        table.insert(lines, "  |cffff0000SPELL OUT OF RANGE (20y)|r")
    end
    
    -- Method 5b: Multi-spell range testing
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== MULTI-SPELL RANGE TEST ===|r")
    
    for _, spell in ipairs(TEST_SPELLS) do
        -- Find spell on action bar
        local spellSlot = nil
        for slot = 1, 120 do
            local actionType, id = GetActionInfo(slot)
            if actionType == "spell" then
                GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                GameTooltip:SetAction(slot)
                local actionName = GameTooltipTextLeft1:GetText()
                GameTooltip:Hide()
                
                if actionName and string.find(string.lower(actionName), string.lower(spell.name)) then
                    spellSlot = slot
                    break
                end
            end
        end
        
        if spellSlot then
            local inRange = IsActionInRange(spellSlot, "target")
            local rangeStr = "nil"
            local color = "|cffaaaaaa"
            if inRange == 1 then 
                rangeStr = "IN RANGE"
                color = "|cff00ff00"
            elseif inRange == 0 then 
                rangeStr = "OUT OF RANGE"
                color = "|cffff0000"
            end
            table.insert(lines, color .. spell.name .. " (" .. spell.range .. "y): " .. rangeStr .. "|r")
        else
            table.insert(lines, "|cffaaaaaa" .. spell.name .. " (" .. spell.range .. "y): NOT ON ACTION BAR|r")
        end
    end
    
    -- Method 5c: IsSpellInRange API Test (Anniversary Edition)
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== IsSpellInRange API TEST ===|r")
    if IsSpellInRange then
        table.insert(lines, "IsSpellInRange: |cff00ff00EXISTS|r")
        
        local spellRange = IsSpellInRange(TEST_SPELL_NAME, "target")
        local rangeStr = "nil"
        local color = "|cffaaaaaa"
        if spellRange == 1 then 
            rangeStr = "1 (IN RANGE)"
            color = "|cff00ff00"
        elseif spellRange == 0 then 
            rangeStr = "0 (OUT OF RANGE)"
            color = "|cffff0000"
        end
        table.insert(lines, color .. "IsSpellInRange('" .. TEST_SPELL_NAME .. "', 'target'): " .. rangeStr .. "|r")
        
        -- Test all spells
        for _, spell in ipairs(TEST_SPELLS) do
            local sr = IsSpellInRange(spell.name, "target")
            local srStr = "nil"
            local srColor = "|cffaaaaaa"
            if sr == 1 then 
                srStr = "IN"
                srColor = "|cff00ff00"
            elseif sr == 0 then 
                srStr = "OUT"
                srColor = "|cffff0000"
            end
            table.insert(lines, srColor .. "  " .. spell.name .. " (" .. spell.range .. "y): " .. srStr .. "|r")
        end
    else
        table.insert(lines, "IsSpellInRange: |cffff0000DOES NOT EXIST|r")
        table.insert(lines, "|cffffff00Classic Anniversary may not have this API|r")
    end
    
    -- Method 5d: Estimated 20-yard range
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== 20 YARD ESTIMATE ===|r")
    if CheckInteractDistance("target", 4) then
        table.insert(lines, "|cff00ff00Target is within 28 yards|r")
        table.insert(lines, "|cffffff00Fire Blast (20y) MIGHT be in range|r")
        if not CheckInteractDistance("target", 3) then
            table.insert(lines, "|cffffff00(Between 10-28 yards - uncertain)|r")
        else
            table.insert(lines, "|cff00ff00(Within 10 yards - DEFINITELY in range)|r")
        end
    else
        table.insert(lines, "|cffff0000Target is beyond 28 yards|r")
        table.insert(lines, "|cffff0000Fire Blast (20y) is OUT OF RANGE|r")
    end
    
    -- Method 5c: Jambo Range Module (if available)
    if _G.JamboRotation and _G.JamboRotation.Range then
        table.insert(lines, "")
        table.insert(lines, "|cff00ff00=== JAMBO RANGE MODULE ===|r")
        local JR = _G.JamboRotation
        local rangeStatus = JR.Range:GetRangeStatus(TEST_SPELL_NAME, "target")
        local rangeNumeric = JR.Range:GetRangeNumeric(TEST_SPELL_NAME, "target")
        local distance = JR.Range:EstimateDistance("target")
        
        table.insert(lines, "Status: " .. rangeStatus)
        table.insert(lines, "Numeric: " .. tostring(rangeNumeric))
        table.insert(lines, "Estimated Distance: " .. (distance and (distance .. " yards") or "nil"))
        
        if rangeStatus == "InRange" then
            table.insert(lines, "|cff00ff00SPELL IS IN RANGE (20y)|r")
        elseif rangeStatus == "OutOfRange" then
            table.insert(lines, "|cffff0000SPELL OUT OF RANGE (20y)|r")
        else
            table.insert(lines, "|cffffff00No range limit or cannot determine|r")
        end
    end
    
    -- Method 6: UnitInRange (party/raid only in Classic)
    table.insert(lines, "")
    local inRange = UnitInRange("target")
    table.insert(lines, "UnitInRange('target'): " .. tostring(inRange) .. " (party/raid only)")
    
    -- Method 7: Spell usability
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== SPELL USABILITY ===|r")
    local usable, noMana = IsUsableSpell(TEST_SPELL_NAME)
    table.insert(lines, "IsUsableSpell: " .. tostring(usable))
    table.insert(lines, "No Mana: " .. tostring(noMana))
    
    if #foundActions > 0 then
        local usableAction, noManaAction = IsUsableAction(foundActions[1].slot)
        table.insert(lines, "IsUsableAction: " .. tostring(usableAction))
        table.insert(lines, "No Mana (action): " .. tostring(noManaAction))
    end
    
    -- Method 8: Spell cooldown
    table.insert(lines, "")
    local start, duration = GetSpellCooldown(TEST_SPELL_NAME, BOOKTYPE_SPELL)
    if start then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            table.insert(lines, "Cooldown: " .. string.format("%.1fs", remaining))
        else
            table.insert(lines, "Cooldown: READY")
        end
    end
    
    -- Additional info
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== ADDITIONAL INFO ===|r")
    table.insert(lines, "To test multi-spell range:")
    table.insert(lines, "1. Put Fire Blast, Frostbolt, Scorch, Fireball on action bar")
    table.insert(lines, "2. Target a LIVING enemy (not dead)")
    table.insert(lines, "3. Walk toward/away from target")
    table.insert(lines, "4. Watch when each spell changes to IN/OUT RANGE")
    table.insert(lines, "")
    table.insert(lines, "Expected ranges:")
    table.insert(lines, "  Fire Blast: 20y | Frostbolt/Scorch: 30y | Fireball: 35y")
    table.insert(lines, "")
    table.insert(lines, "|cffff0000ISSUE: IsActionInRange returns nil in Classic!|r")
    table.insert(lines, "|cffffff00This is a known WoW Classic API limitation.|r")
    table.insert(lines, "|cffffff00Only CheckInteractDistance (10y/28y) works reliably.|r")
    table.insert(lines, "")
    table.insert(lines, "|cffaaaaaa(Click text to select/copy)|r")
    
    local text = table.concat(lines, "\n")
    info:SetText(text)
    info:SetHeight(2000)
end

-- Update every frame
frame:SetScript("OnUpdate", function(self, elapsed)
    if not self.updateTime then self.updateTime = 0 end
    self.updateTime = self.updateTime + elapsed
    
    if self.updateTime >= 0.1 then -- Update 10 times per second
        UpdateDebugInfo()
        self.updateTime = 0
    end
end)

-- Slash command
SLASH_JAMBODEBUG1 = "/jdebug"
SLASH_JAMBODEBUG2 = "/jambo debug"
SlashCmdList["JAMBODEBUG"] = function(msg)
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UpdateDebugInfo()
    end
end

-- Show on load
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        print("|cff00ff00Jambo Debug loaded! Type /jdebug to toggle debug frame|r")
    end
end)
