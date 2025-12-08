-- Namespace
local addonName, ns = ...
local Jambo = CreateFrame("Frame")
local mainFrame
local minimapButton
local bars = {}

-- ============================================================================
--  CONFIG & STYLING
-- ============================================================================
local WIDTH = 300
local HEADER_HEIGHT = 24
local TEXTURE = "Interface\\Buttons\\WHITE8x8"

-- Colors
local C_BAR = {0.09, 0.52, 0.82, 1}       -- Blue (Current Rank)
local C_POT_BAG = {1, 0.6, 0, 0.5}        -- Orange (Have mats in bag)
local C_POT_BANK = {0.2, 0.8, 0.2, 0.5}   -- Green (Have mats in bank)

local C_READY = {0.2, 0.8, 0.2, 1}    -- Green Button
local C_TRAIN = {0.8, 0.2, 0.2, 1}    -- Red Button

-- Text Colors
local TXT_ORANGE = "|cffeda55f"
local TXT_GREEN = "|cff33ff33"
local TXT_RED = "|cffff0000"
local TXT_WHITE = "|cffffffff"
local TXT_GREY = "|cffaaaaaa"
local TXT_YELLOW = "|cffffd100"
local TXT_CYAN = "|cff00ccff"

if not JamboProfDB then JamboProfDB = {} end

-- ============================================================================
--  STATE MANAGEMENT
-- ============================================================================
local function IsCollapsed(name)
    return JamboProfDB.collapsed and JamboProfDB.collapsed[name]
end

local function SetCollapsed(name, state)
    if not JamboProfDB.collapsed then JamboProfDB.collapsed = {} end
    JamboProfDB.collapsed[name] = state
end

-- ROBUST RECIPE CHECKER
local function IsRecipeKnown(recipeName)
    if not recipeName then return true end

    -- 1. Try Direct ID check (Fastest)
    local _, _, _, _, _, _, spellID = GetSpellInfo(recipeName)
    if spellID and IsSpellKnown(spellID) then return true end

    -- 2. Scan Spellbook (Robust - handles Ranks/different IDs)
    -- This iterates through your actual spellbook to find a name match.
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSpells do
            local spellName = GetSpellBookItemName(j, BOOKTYPE_SPELL)
            if spellName == recipeName then
                return true
            end
        end
    end

    return false 
end

-- ============================================================================
--  LOGIC ENGINE
-- ============================================================================

local function GetStepInfo(profName, currentRank)
    local path = ns.guideData[profName]
    if not path then return nil end

    local lines = {}
    local activeSteps = {}
    
    -- Accumulators for the bar
    local totalBagGain = 0
    
    -- Button Logic state
    local btnAction, btnType, overrideColor = nil, "spell", nil
    local foundTrain = false
    local foundCraft = false
    
    -- 1. COLLECT ALL MATCHING STEPS
    for _, step in ipairs(path) do
        if currentRank >= step.min and currentRank < step.max then
            table.insert(activeSteps, step)
            
            -- Calculate gains for the bar
            local bagGain = 0
            if step.reagents then
                local sBag = 9999
                for itemID, countPer in pairs(step.reagents) do
                    local inBag = C_Item.GetItemCount(itemID, false)
                    sBag = math.min(sBag, math.floor(inBag / countPer))
                end
                if sBag == 9999 then sBag = 0 end
                bagGain = sBag
            elseif step.type == "GATHER" and step.altReagents then
                -- Smelting check inside Gather steps
                local sBag = 9999
                for sID, sReq in pairs(step.altReagents) do
                    local c = C_Item.GetItemCount(sID, false)
                    local p = math.floor(c / sReq)
                    sBag = math.min(sBag, p)
                end
                if sBag < 9999 and sBag > 0 then bagGain = sBag end
            end
            
            if (currentRank + bagGain) > totalBagGain then totalBagGain = currentRank + bagGain end
        end
    end

    if #activeSteps == 0 then
        return { text="Maxed for Guide", mainText="Done", bagGain=0, bankGain=0, max=currentRank }
    end
    
    -- Reset totalBagGain to relative gain for display
    totalBagGain = totalBagGain - currentRank
    if totalBagGain < 0 then totalBagGain = 0 end

    -- 2. GENERATE TEXT & BUTTON FOR COLLECTED STEPS
    for _, step in ipairs(activeSteps) do
        local pointsNeeded = step.max - currentRank
        local known = IsRecipeKnown(step.recipeName)
        
        -- A. TOOLS CHECK (DISABLED per request)
        -- if step.tools then ... end

        -- B. TRAIN CHECK (Red)
        -- Only show if we strictly DO NOT know the recipe.
        if (step.type == "LEARN" or (step.type == "RECIPE" and step.recipeName)) then
            if not known then
                local txt = step.recipeName or step.text
                table.insert(lines, TXT_RED .. "[TRAIN] " .. txt .. "|r")
                
                if not foundCraft then
                    btnAction = nil 
                    overrideColor = C_TRAIN
                    foundTrain = true
                end
            end
        end

        -- C. GATHER (Orange)
        if step.type == "GATHER" then
            table.insert(lines, TXT_ORANGE .. "[GATHER] " .. step.text .. "|r")
            if step.zone then
                table.insert(lines, TXT_GREY .. " Zone: " .. step.zone .. "|r")
            end
        end

        -- D. CRAFT / MATS CHECK
        if step.type == "RECIPE" then
            -- Calc reagents
            local sBag = 9999
            local sTotal = 9999
            for itemID, countPer in pairs(step.reagents or {}) do
                local cBag = C_Item.GetItemCount(itemID, false)
                local cTotal = C_Item.GetItemCount(itemID, true)
                sBag = math.min(sBag, math.floor(cBag / countPer))
                sTotal = math.min(sTotal, math.floor(cTotal / countPer))
            end
            if sBag == 9999 then sBag = 0 end
            if sTotal == 9999 then sTotal = 0 end

            if sBag > 0 then
                -- Have mats in Bag
                if known then
                    -- Prepend to top of lines for visibility
                    table.insert(lines, 1, TXT_GREEN .. "[CRAFT] " .. step.recipeName .. ": Make " .. sBag .. "|r")
                    if not foundCraft then
                        foundCraft = true
                        btnAction = step.recipeName
                        btnType = "spell"
                        overrideColor = C_READY
                    end
                else
                    table.insert(lines, TXT_YELLOW .. "[MATS] Have mats for " .. sBag .. " " .. step.recipeName .. " (Train first)|r")
                end
            elseif sTotal > 0 then
                -- Have mats in Bank
                table.insert(lines, TXT_CYAN .. "[BANK] " .. step.recipeName .. ": Have mats for " .. sTotal .. " in Bank|r")
            else
                -- Missing Mats
                -- Only show Farm list if we know it OR if we haven't listed a train instruction yet
                if known or not foundTrain then
                    local missingList = ""
                    for itemID, countPer in pairs(step.reagents or {}) do
                        local neededTotal = pointsNeeded * countPer
                        local have = C_Item.GetItemCount(itemID, false)
                        if have < neededTotal then
                            local name = GetItemInfo(itemID) or "Item"
                            if missingList ~= "" then missingList = missingList .. ", " end
                            missingList = missingList .. (neededTotal - have) .. " " .. name
                        end
                    end
                   
                   if missingList ~= "" then
                       table.insert(lines, TXT_ORANGE .. "[FARM] " .. step.recipeName .. ": " .. missingList .. "|r")
                   else
                       table.insert(lines, TXT_GREY .. "[RECIPE] " .. step.recipeName .. "|r")
                   end
                end
            end
        end
    end

    -- Determine Main Status Text
    local mainText = "Check Details"
    if foundCraft then mainText = TXT_GREEN .. "Ready to Craft"
    elseif foundTrain then mainText = TXT_RED .. "Visit Trainer"
    elseif #activeSteps > 0 and activeSteps[1].type == "GATHER" then mainText = TXT_ORANGE .. "Gathering"
    end

    local maxCap = activeSteps[#activeSteps].max

    return {
        text = table.concat(lines, "\n"),
        mainText = mainText,
        bagGain = totalBagGain,
        bankGain = 0, 
        canCraft = foundCraft,
        recipe = btnAction,
        btnType = btnType,
        overrideColor = overrideColor,
        max = maxCap
    }
end

local function GetProfData()
    local profs = {}
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, modifier, maxRank = GetSkillLineInfo(i)
        if not isHeader and ns.guideData[name] then
            local actualRank = rank + (modifier or 0)
            if actualRank < 300 then
                local stepInfo = GetStepInfo(name, actualRank)
                table.insert(profs, { name=name, rank=actualRank, max=maxRank, step=stepInfo })
            end
        end
    end
    return profs
end

-- ============================================================================
--  UI GENERATION
-- ============================================================================

local function CreateMainWindow()
    if mainFrame then return mainFrame end
    mainFrame = CreateFrame("Frame", "JamboProfWindow", UIParent, "BackdropTemplate")
    
    -- Removed background for main window (transparent)
    mainFrame:SetBackdrop(nil)
    
    mainFrame:Hide()
    mainFrame:SetSize(WIDTH, 100)
    mainFrame:SetPoint("CENTER")
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if not JamboProfDB then JamboProfDB = {} end
        JamboProfDB.pos = {point, relPoint, x, y}
    end)
    
    if JamboProfDB and JamboProfDB.pos then
        local p = JamboProfDB.pos
        mainFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    -- Close Button (attached to top right of virtual frame)
    local closeBtn = CreateFrame("Button", nil, mainFrame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeBtn.text:SetPoint("CENTER", 0, 1)
    closeBtn.text:SetText("X")
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)
    
    return mainFrame
end

local function UpdateDisplay()
    if InCombatLockdown() then return end
    if not mainFrame then CreateMainWindow() end
    
    local profs = GetProfData()
    local yOffset = -10
    local totalHeight = 20

    for _, b in pairs(bars) do b:Hide() end

    for i, p in ipairs(profs) do
        if not bars[i] then
            local b = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
            b:SetWidth(WIDTH - 12)
            ns.SetElvUIBorder(b) -- Keep border/background on the BAR only
            
            -- HEADER BARS
            -- 1. Bag Bar (Orange)
            b.bagBar = CreateFrame("StatusBar", nil, b)
            b.bagBar:SetSize(WIDTH - 100, 16)
            b.bagBar:SetPoint("TOPLEFT", 6, -4) 
            b.bagBar:SetStatusBarTexture(TEXTURE)
            b.bagBar:SetStatusBarColor(unpack(C_POT_BAG))
            
            -- 2. Current Bar (Blue)
            b.bar = CreateFrame("StatusBar", nil, b)
            b.bar:SetAllPoints(b.bagBar)
            b.bar:SetStatusBarTexture(TEXTURE)
            b.bar:SetStatusBarColor(unpack(C_BAR))
            
            -- TEXT ON BAR
            b.name = b.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.name:SetPoint("LEFT", 4, 0)
            
            b.rank = b.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.rank:SetPoint("RIGHT", -4, 0)
            
            -- ACTION BUTTON
            b.btn = CreateFrame("Button", nil, b, "SecureActionButtonTemplate, BackdropTemplate")
            b.btn:SetSize(50, 16)
            b.btn:SetPoint("TOPRIGHT", -4, -4)
            ns.SetElvUIBorder(b.btn)
            b.btn.text = b.btn:CreateFontString(nil, "OVERLAY", "SystemFont_Tiny")
            b.btn.text:SetPoint("CENTER")
            
            -- DETAIL TEXT
            b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.info:SetPoint("TOPLEFT", b.bar, "BOTTOMLEFT", 0, -4)
            b.info:SetWidth(WIDTH - 20)
            b.info:SetJustifyH("LEFT")
            b.info:SetJustifyV("TOP")
            b.info:SetSpacing(2)
            
            -- CLICK TO FOLD LOGIC (Entire Bar)
            b:EnableMouse(true)
            b:SetScript("OnMouseDown", function()
                local s = not IsCollapsed(p.name)
                SetCollapsed(p.name, s)
                UpdateDisplay()
            end)
            
            bars[i] = b
        end
        
        local b = bars[i]
        b:Show()
        b:SetPoint("TOP", 0, yOffset)
        
        -- --- DATA UPDATE ---
        local step = p.step
        local bagGain = step and step.bagGain or 0
        
        b.bar:SetMinMaxValues(0, p.max)
        b.bagBar:SetMinMaxValues(0, p.max)
        
        b.bar:SetValue(p.rank)
        b.bagBar:SetValue(p.rank + bagGain)
        
        local rText = p.rank
        if bagGain > 0 then rText = rText .. TXT_ORANGE .. "+" .. bagGain .. "|r" end
        b.name:SetText(p.name)
        b.rank:SetText(rText .. " / " .. p.max)
        
        -- Button
        if step and step.recipe then
            b.btn:Show()
            b.btn:SetBackdropColor(unpack(step.overrideColor or C_READY))
            local label = "DO IT"
            if step.overrideColor == C_TRAIN then label = "TRAIN" end
            b.btn.text:SetText(label)
            b.btn:SetAttribute("type", step.btnType)
            if step.btnType == "item" then b.btn:SetAttribute("item", step.recipe)
            else b.btn:SetAttribute("spell", step.recipe) end
        else
            b.btn:Hide()
        end
        
        -- --- FOLDING LOGIC ---
        local collapsed = IsCollapsed(p.name)
        
        if step then
            b.info:SetText(step.text)
        else
            b.info:SetText("Maxed")
        end
        
        local frameHeight = HEADER_HEIGHT
        if collapsed then
            b.info:Hide()
        else
            b.info:Show()
            local textHeight = b.info:GetStringHeight()
            frameHeight = HEADER_HEIGHT + textHeight + 8
        end
        
        b:SetHeight(frameHeight)
        yOffset = yOffset - (frameHeight + 4)
        totalHeight = totalHeight + frameHeight + 4
    end
    
    mainFrame:SetHeight(math.abs(totalHeight) + 10)
end

local function CreateMinimapButton()
    if minimapButton then return end
    local btn = CreateFrame("Button", "JamboMinimapButton", Minimap)
    btn:SetSize(20, 20)
    btn:SetFrameStrata("FULLSCREEN_DIALOG") 
    ns.SetElvUIBorder(btn)
    btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText("J")
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    btn:RegisterForDrag("LeftButton")
    btn:SetMovable(true)
    btn:SetScript("OnDragStart", function(s) s:StartMoving() end)
    btn:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    btn:SetScript("OnClick", function() 
        if not mainFrame then CreateMainWindow() end
        if mainFrame:IsShown() then mainFrame:Hide() else UpdateDisplay() mainFrame:Show() end
    end)
    minimapButton = btn
end

Jambo:RegisterEvent("PLAYER_LOGIN")
Jambo:RegisterEvent("SKILL_LINES_CHANGED")
Jambo:RegisterEvent("BAG_UPDATE")
Jambo:RegisterEvent("SPELLS_CHANGED")
Jambo:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CreateMainWindow()
        CreateMinimapButton()
        C_Timer.After(2, function() ExpandSkillHeader(0) UpdateDisplay() end)
    else
        if mainFrame and mainFrame:IsShown() then UpdateDisplay() end
    end
end)

SLASH_JAMBOPROF1 = "/jprof"
SlashCmdList["JAMBOPROF"] = function() 
    if not mainFrame then CreateMainWindow() end
    mainFrame:Show()
    UpdateDisplay()
end