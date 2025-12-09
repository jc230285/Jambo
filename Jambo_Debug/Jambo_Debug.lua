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

-- Test spell data - one spell per range breakpoint per class
-- Excludes: Point-blank AoE spells (Frost Nova, Arcane Explosion, etc.)
local TEST_SPELLS = {
    -- Mage (no melee)
    {name = "Fire Blast", range = 20, class = "MAGE"},
    {name = "Frostbolt", range = 30, class = "MAGE"},
    {name = "Fireball", range = 35, class = "MAGE"},
    {name = "Scorch", range = 30, class = "MAGE"},
    
    -- Warlock (no melee)
    {name = "Corruption", range = 30, class = "WARLOCK"},
    {name = "Shadow Bolt", range = 30, class = "WARLOCK"},
    {name = "Immolate", range = 30, class = "WARLOCK"},
    
    -- Priest (no melee)
    {name = "Shadow Word: Pain", range = 30, class = "PRIEST"},
    {name = "Mind Blast", range = 30, class = "PRIEST"},
    {name = "Smite", range = 30, class = "PRIEST"},
    
    -- Druid
    {name = "Claw", range = 5, class = "DRUID"},
    {name = "Wrath", range = 30, class = "DRUID"},
    {name = "Moonfire", range = 30, class = "DRUID"},
    {name = "Starfire", range = 30, class = "DRUID"},
    
    -- Shaman
    {name = "Primal Strike", range = 5, class = "SHAMAN"},
    {name = "Lightning Bolt", range = 30, class = "SHAMAN"},
    {name = "Earth Shock", range = 20, class = "SHAMAN"},
    {name = "Flame Shock", range = 20, class = "SHAMAN"},
    
    -- Hunter
    {name = "Raptor Strike", range = 5, class = "HUNTER"},
    {name = "Arcane Shot", range = 35, class = "HUNTER"},
    {name = "Serpent Sting", range = 35, class = "HUNTER"},
    {name = "Steady Shot", range = 35, class = "HUNTER"},
    
    -- Paladin
    {name = "Crusader Strike", range = 5, class = "PALADIN"},
    {name = "Judgement", range = 10, class = "PALADIN"},
    {name = "Exorcism", range = 30, class = "PALADIN"},
    
    -- Warrior
    {name = "Heroic Strike", range = 5, class = "WARRIOR"},
    {name = "Charge", range = 25, class = "WARRIOR"},
    {name = "Throw", range = 30, class = "WARRIOR"},
    
    -- Rogue
    {name = "Sinister Strike", range = 5, class = "ROGUE"},
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
    
    -- Method 5b: IsSpellInRange + CheckInteractDistance Test
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== RANGE DETECTION ===|r")
    
    -- CheckInteractDistance first
    local in10 = CheckInteractDistance("target", 3)
    local in28 = CheckInteractDistance("target", 4)
    
    local duelColor = in10 and "|cff00ff00" or "|cffff0000"
    local followColor = in28 and "|cff00ff00" or "|cffff0000"
    table.insert(lines, duelColor .. "Duel (10y): " .. (in10 and "YES" or "NO") .. "|r")
    table.insert(lines, followColor .. "Follow (28y): " .. (in28 and "YES" or "NO") .. "|r")
    
    table.insert(lines, "")
    
    if IsSpellInRange then
        table.insert(lines, "|cff00ff00IsSpellInRange: Available|r")
        table.insert(lines, "")
        
        -- Only test spells that exist
        for _, spell in ipairs(TEST_SPELLS) do
            local spellRange = IsSpellInRange(spell.name, "target")
            
            -- Only show if spell exists (not nil from missing spell)
            if spellRange ~= nil or IsUsableSpell(spell.name) then
                local rangeStr = "nil"
                local color = "|cffaaaaaa"
                
                if spellRange == 1 then 
                    rangeStr = "IN"
                    color = "|cff00ff00"
                elseif spellRange == 0 then 
                    rangeStr = "OUT"
                    color = "|cffff0000"
                end
                
                table.insert(lines, color .. spell.name .. " (" .. spell.range .. "y): " .. rangeStr .. "|r")
            end
        end
        
        table.insert(lines, "")
        table.insert(lines, "|cffffff00Range Bracket:|r")
        
        local fireBlast = IsSpellInRange("Fire Blast", "target")
        local frostbolt = IsSpellInRange("Frostbolt", "target")
        
        if in10 then
            table.insert(lines, "|cff00ff00✓ 0-10 yards|r")
        elseif fireBlast == 1 then
            table.insert(lines, "|cff00ff00✓ 10-20 yards|r")
        elseif in28 then
            table.insert(lines, "|cffffff00✓ 20-28 yards|r")
        elseif frostbolt == 1 then
            table.insert(lines, "|cffffff00✓ 28-30 yards|r")
        else
            table.insert(lines, "|cffff0000✗ 30+ yards|r")
        end
    else
        table.insert(lines, "|cffff0000IsSpellInRange: NOT AVAILABLE|r")
        table.insert(lines, "")
        
        if in10 then
            table.insert(lines, "|cff00ff00✓ 0-10 yards|r")
        elseif in28 then
            table.insert(lines, "|cffffff00✓ 10-28 yards|r")
        else
            table.insert(lines, "|cffff0000✗ 28+ yards|r")
        end
    end
    
    -- Method 5c: LibRangeCheck-3.0 (if available)
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== LIBRANGECHECK-3.0 ===|r")
    local LRC = LibStub and LibStub("LibRangeCheck-3.0", true)
    if LRC then
        table.insert(lines, "|cff00ff00LibRangeCheck-3.0: Available|r")
        
        -- Get range estimate
        local minRange, maxRange = LRC:GetRange("target")
        if minRange and maxRange then
            table.insert(lines, "Range Bracket: " .. minRange .. "-" .. maxRange .. " yards")
            
            -- Show color-coded result
            local color = "|cff00ff00"
            if maxRange > 30 then color = "|cffff0000"
            elseif maxRange > 20 then color = "|cffffff00" end
            table.insert(lines, color .. "Estimated Distance: " .. minRange .. "-" .. maxRange .. "y|r")
        else
            table.insert(lines, "|cffaaaaaa" .. "No range estimate available|r")
        end
        
        -- Get all available checkers for current class
        table.insert(lines, "")
        table.insert(lines, "|cffffff00Available Range Checkers:|r")
        
        -- Try common ranges
        local testRanges = {5, 8, 10, 15, 20, 25, 28, 30, 35, 40}
        for _, range in ipairs(testRanges) do
            local checker = LRC:GetChecker(range)
            if checker then
                local inRange = checker("target")
                local status = inRange and "|cff00ff00IN|r" or "|cffff0000OUT|r"
                table.insert(lines, range .. "y: " .. status)
            end
        end
    else
        table.insert(lines, "|cffff0000LibRangeCheck-3.0: NOT AVAILABLE|r")
        table.insert(lines, "Install LibRangeCheck-3.0 for advanced range checking")
    end
    
    -- Method 5d: IsSpellInRange API Test (Anniversary Edition)
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== RECOMMENDED LOGIC ===|r")
    if IsSpellInRange then
        local fireBlast = IsSpellInRange("Fire Blast", "target")
        local in28 = CheckInteractDistance("target", 4)
        
        table.insert(lines, "local in20 = IsSpellInRange(\"Fire Blast\", \"target\") == 1")
        table.insert(lines, "local in28 = CheckInteractDistance(\"target\", 4)")
        table.insert(lines, "")
        table.insert(lines, "Result:")
        
        if fireBlast == 1 then
            table.insert(lines, "|cff00ff00in20 = true → Target within 20 yards|r")
        elseif in28 then
            table.insert(lines, "|cffffff00in20 = false, in28 = true → Target 20-28y|r")
        else
            table.insert(lines, "|cffff0000Both false → Target beyond 28 yards|r")
        end
    else
        table.insert(lines, "|cffff0000IsSpellInRange not available|r")
        table.insert(lines, "Can only use CheckInteractDistance (10y/28y)")
    end
    
    -- Method 5e: Estimated 20-yard range
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
    
    -- Method 5f: Jambo Range Module (if available)
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
    table.insert(lines, "|cff00ff00=== SUMMARY ===|r")
    table.insert(lines, "✅ IsSpellInRange WORKS in Classic Anniversary!")
    table.insert(lines, "✅ CheckInteractDistance always works")
    table.insert(lines, "")
    table.insert(lines, "|cffffff00Note: Point-blank AoE spells excluded|r")
    table.insert(lines, "|cffffff00(Frost Nova, Arcane Explosion, etc.)|r")
    table.insert(lines, "|cffffff00These don't target enemies, so return nil|r")
    table.insert(lines, "")
    table.insert(lines, "Recommended Code:")
    table.insert(lines, "|cffaaaaaa-- For melee range (5 yards)|r")
    table.insert(lines, "|cffaaaaaalocal in5 = IsSpellInRange('Heroic Strike', 'target') == 1|r")
    table.insert(lines, "|cffaaaaaa-- or use CheckInteractDistance(target, 3) for 10y|r")
    table.insert(lines, "")
    table.insert(lines, "|cffaaaaaa-- For 20-yard spells (Fire Blast)|r")
    table.insert(lines, "|cffaaaaaalocal in20 = IsSpellInRange('Fire Blast', 'target') == 1|r")
    table.insert(lines, "|cffaaaaaalocal in28 = CheckInteractDistance('target', 4)|r")
    table.insert(lines, "")
    table.insert(lines, "|cffaaaaaa-- For 30-yard spells (Frostbolt)|r")
    table.insert(lines, "|cffaaaaaalocal in30 = IsSpellInRange('Frostbolt', 'target') == 1|r")
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
