-- Jambo Gear UI with Tabs: Gear Sets, Options (with Automation Dropdown), Stat Weights Editor

local JG = _G.JamboGear

if not JG then return end

-- ==========================================================
-- 1. MAIN FRAME & TABS
-- ==========================================================

function JG:CreateMainFrame()
    if self.gui then return end

    self.gui = CreateFrame("Frame", "JamboGearFrame", UIParent, "BasicFrameTemplateWithInset")
    local f = self.gui
    f:SetSize(800, 600)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function() if JG.UpdateAllContainerFrameOverlays then JG:UpdateAllContainerFrameOverlays() end end)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText("Jambo Gear")
    
    -- Close Button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Tabs
    self:CreateTabs(f)
    
    -- Initial Tab
    self:SwitchToTab(1)
end

function JG:CreateTabs(parent)
    local tabNames = {"Gear Sets", "Options", "Stat Weights"}
    self.tabs = {}
    
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, parent, "TabButtonTemplate")
        tab:SetSize(120, 30)
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 10 + (i-1)*130, -30)
        tab:SetText(name)
        tab:SetScript("OnClick", function() JG:SwitchToTab(i) end)
        self.tabs[i] = tab
    end
end

function JG:SwitchToTab(tabIndex)
    -- Hide all tab contents
    if self.gearSetsTab then self.gearSetsTab:Hide() end
    if self.optionsTab then self.optionsTab:Hide() end
    if self.weightsTab then self.weightsTab:Hide() end
    
    -- Show selected tab
    if tabIndex == 1 then
        self:CreateGearSetsTab()
        self.gearSetsTab:Show()
    elseif tabIndex == 2 then
        self:CreateOptionsTab()
        self.optionsTab:Show()
    elseif tabIndex == 3 then
        self:CreateWeightsTab()
        self.weightsTab:Show()
    end
    
    -- Update tab highlights
    for i, tab in ipairs(self.tabs) do
        if i == tabIndex then
            PanelTemplates_SelectTab(tab)
        else
            PanelTemplates_DeselectTab(tab)
        end
    end
end

-- ==========================================================
-- 2. GEAR SETS TAB
-- ==========================================================

function JG:CreateGearSetsTab()
    if self.gearSetsTab then return end
    
    local tab = CreateFrame("Frame", nil, self.gui)
    tab:SetAllPoints()
    self.gearSetsTab = tab
    
    -- Scan Button
    local scanBtn = CreateFrame("Button", nil, tab, "UIPanelButtonTemplate")
    scanBtn:SetSize(100, 25)
    scanBtn:SetPoint("TOPLEFT", 10, -10)
    scanBtn:SetText("Scan Gear")
    scanBtn:SetScript("OnClick", function() JG:ScanAndUpdateGear() end)
    
    -- Gear Sets List
    self:CreateGearSetsList(tab)
end

function JG:CreateGearSetsList(parent)
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetSize(760, 500)
    listFrame:SetPoint("TOPLEFT", 10, -50)
    
    -- ScrollFrame for sets
    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 500)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(760, 500)
    scrollFrame:SetScrollChild(content)
    
    self.gearSetsContent = content
    self:UpdateGearSetsList()
end

function JG:UpdateGearSetsList()
    if not self.gearSetsContent then return end
    
    -- Clear existing
    for _, child in ipairs({self.gearSetsContent:GetChildren()}) do child:Hide() end
    
    local classConfig = self:GetCurrentClassConfig()
    if not classConfig or not classConfig.gearSets then return end
    
    local yOffset = -10
    for setName, setData in pairs(classConfig.gearSets) do
        local setFrame = CreateFrame("Frame", nil, self.gearSetsContent)
        setFrame:SetSize(740, 40)
        setFrame:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Set Name
        local nameText = setFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", 10, 0)
        nameText:SetText(setName)
        
        -- Equip Button
        local equipBtn = CreateFrame("Button", nil, setFrame, "UIPanelButtonTemplate")
        equipBtn:SetSize(60, 20)
        equipBtn:SetPoint("RIGHT", -10, 0)
        equipBtn:SetText("Equip")
        equipBtn:SetScript("OnClick", function() JG:SwapToOptimalGear(setName) end)
        
        yOffset = yOffset - 45
    end
end

-- ==========================================================
-- 3. OPTIONS TAB
-- ==========================================================

function JG:CreateOptionsTab()
    if self.optionsTab then return end
    
    local tab = CreateFrame("Frame", nil, self.gui)
    tab:SetAllPoints()
    self.optionsTab = tab
    
    -- Automation Dropdown
    self:CreateAutomationDropdown(tab)
    
    -- Other options...
end

function JG:CreateAutomationDropdown(parent)
    local dropdown = CreateFrame("Frame", "JamboGearAutomationDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 10, -10)
    
    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_SetText(dropdown, "Automation Mode")
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = "None"
        info.value = "None"
        info.func = function() JG:ApplyAutomationMode("None") UIDropDownMenu_SetText(dropdown, "None") end
        UIDropDownMenu_AddButton(info)
        
        info.text = "Healer"
        info.value = "Healer"
        info.func = function() JG:ApplyAutomationMode("Healer") UIDropDownMenu_SetText(dropdown, "Healer") end
        UIDropDownMenu_AddButton(info)
        
        info.text = "Tank"
        info.value = "Tank"
        info.func = function() JG:ApplyAutomationMode("Tank") UIDropDownMenu_SetText(dropdown, "Tank") end
        UIDropDownMenu_AddButton(info)
        
        info.text = "DPS"
        info.value = "DPS"
        info.func = function() JG:ApplyAutomationMode("DPS") UIDropDownMenu_SetText(dropdown, "DPS") end
        UIDropDownMenu_AddButton(info)
    end)
    
    -- Set initial text
    local currentMode = self.db.profile.automationMode or "None"
    UIDropDownMenu_SetText(dropdown, currentMode)
end

-- ==========================================================
-- 4. STAT WEIGHTS TAB
-- ==========================================================

function JG:CreateWeightsTab()
    if self.weightsTab then return end
    
    local tab = CreateFrame("Frame", nil, self.gui)
    tab:SetAllPoints()
    self.weightsTab = tab
    
    -- Spec Dropdown
    self:CreateWeightsSpecDropdown(tab)
    
    -- Weights Editor
    self:CreateWeightsEditor(tab)
end

function JG:CreateWeightsSpecDropdown(parent)
    local dropdown = CreateFrame("Frame", "JamboGearWeightsSpecDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 10, -10)
    
    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_SetText(dropdown, "Select Spec")
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        JG:CheckWeightsInit()
        local classWeights = JG.db.profile.weights[JG.playerClass] or {}
        
        for specName, _ in pairs(classWeights) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = specName
            info.value = specName
            info.func = function() JG:UpdateWeightsTab(specName) UIDropDownMenu_SetText(dropdown, specName) end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

function JG:CreateWeightsEditor(parent)
    local editorFrame = CreateFrame("Frame", nil, parent)
    editorFrame:SetSize(760, 500)
    editorFrame:SetPoint("TOPLEFT", 10, -50)
    
    self.weightsEditor = editorFrame
end

function JG:UpdateWeightsTab(specName)
    if not self.weightsEditor then return end
    
    -- Clear existing
    for _, child in ipairs({self.weightsEditor:GetChildren()}) do child:Hide() end
    
    JG:CheckWeightsInit()
    local weights = JG.db.profile.weights[JG.playerClass] and JG.db.profile.weights[JG.playerClass][specName]
    if not weights then return end
    
    local yOffset = -10
    for statName, value in pairs(weights) do
        local statFrame = CreateFrame("Frame", nil, self.weightsEditor)
        statFrame:SetSize(740, 30)
        statFrame:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Stat Name
        local nameText = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", 10, 0)
        nameText:SetText(statName)
        
        -- Edit Box
        local editBox = CreateFrame("EditBox", nil, statFrame, "InputBoxTemplate")
        editBox:SetSize(100, 20)
        editBox:SetPoint("RIGHT", -10, 0)
        editBox:SetText(tostring(value))
        editBox:SetScript("OnEnterPressed", function(self)
            local newVal = tonumber(self:GetText())
            if newVal then
                weights[statName] = newVal
                JG:Print("Updated " .. statName .. " to " .. newVal)
                JG:ScanAndUpdateGear() -- Refresh
            end
        end)
        
        yOffset = yOffset - 35
    end
end

-- ==========================================================
-- 5. UTILITY
-- ==========================================================

function JG:UpdateGUI()
    if self.gearSetsContent then self:UpdateGearSetsList() end
end