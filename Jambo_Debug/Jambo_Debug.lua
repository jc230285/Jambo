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

-- Test spell data (Fire Blast)
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
    elseif CheckInteractDistance("target", 4) then
        table.insert(lines, "  |cffffff00<= 28 yards|r (Follow range)")
    else
        table.insert(lines, "  |cffff0000> 28 yards|r (Out of follow range)")
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
    table.insert(lines, "To test range:")
    table.insert(lines, "1. Put Fire Blast on action bar")
    table.insert(lines, "2. Target an enemy")
    table.insert(lines, "3. Walk toward/away from target")
    table.insert(lines, "4. Watch IsActionInRange values")
    table.insert(lines, "")
    table.insert(lines, "Expected Fire Blast range: 20 yards")
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
