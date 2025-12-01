local ADDON, NS = ...
local Rot = NS.Rot

NS.UI = NS.UI or {}
local UI = NS.UI

local ROW_HEIGHT = 45
local MAX_ROWS = 8

-- Helper: Consistent Frame Style
local function ApplyJamboStyle(f)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        edgeFile = "Interface\\Buttons\\WHITE8x8", 
        edgeSize = 1, 
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    
    if not f.dragLib then
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.dragLib = true
    end
end

function UI:Init()
    if UI.frame then UI.frame:Show(); return end
    
    local f = CreateFrame("Frame", "JamboRotFrame", UIParent, "BackdropTemplate")
    f:SetSize(600, 500)
    f:SetPoint("CENTER")
    f:SetToplevel(true)
    ApplyJamboStyle(f)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -8)
    f.title:SetText("Jambo Rotation V2.2")
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- --- EDITOR PANEL ---
    local editFrame = CreateFrame("Frame", nil, f)
    editFrame:SetPoint("TOPLEFT", 0, -30)
    editFrame:SetPoint("TOPRIGHT", 0, -30)
    editFrame:SetHeight(60)
    
    local btnSpell = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    btnSpell:SetSize(200, 24); btnSpell:SetPoint("TOPLEFT", 20, -15); btnSpell:SetText("Select Spell...")
    
    local ddCrit = CreateFrame("Frame", "JamboRotCritDD", editFrame, "UIDropDownMenuTemplate")
    ddCrit:SetPoint("TOPLEFT", 230, -12); UIDropDownMenu_SetWidth(ddCrit, 120); UIDropDownMenu_SetText(ddCrit, "Highest Rank")
    
    local btnAction = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    btnAction:SetSize(80, 24); btnAction:SetPoint("LEFT", ddCrit, "RIGHT", -5, 2); btnAction:SetText("Add")
    
    -- State
    local selectedName = nil
    local selectedCrit = "RANK"
    local editModeIndex = nil

    -- Spell List Popup
    local listFrame = CreateFrame("Frame", "JamboRotSpellList", f, "BackdropTemplate")
    listFrame:SetSize(250, 300); listFrame:SetPoint("TOPLEFT", btnSpell, "BOTTOMLEFT", 0, 0); listFrame:SetFrameStrata("DIALOG"); listFrame:Hide()
    ApplyJamboStyle(listFrame)
    local listScroll = CreateFrame("ScrollFrame", "JamboRotListScroll", listFrame, "FauxScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 10, -10); listScroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local spellDataList = {}

    local function UpdateListScroll()
        FauxScrollFrame_Update(listScroll, #spellDataList, 15, 16)
        local offset = FauxScrollFrame_GetOffset(listScroll)
        if not listFrame.buttons then listFrame.buttons = {} end
        for i=1, 15 do
            if not listFrame.buttons[i] then
                local b = CreateFrame("Button", nil, listFrame)
                b:SetSize(210, 16); b:SetPoint("TOPLEFT", 10, -10-(i-1)*16)
                b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.txt:SetPoint("LEFT")
                b:SetScript("OnClick", function(self) 
                    selectedName = self.name; btnSpell:SetText(selectedName); listFrame:Hide()
                    if not editModeIndex then selectedCrit = "RANK"; UIDropDownMenu_SetText(ddCrit, "Highest Rank") end
                end)
                listFrame.buttons[i] = b
            end
            local idx = offset + i
            if idx <= #spellDataList then
                local info = spellDataList[idx]
                listFrame.buttons[i].name = info.name; listFrame.buttons[i].txt:SetText(info.name)
                listFrame.buttons[i]:Show()
            else listFrame.buttons[i]:Hide() end
        end
    end
    listScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 16, UpdateListScroll) end)

    btnSpell:SetScript("OnClick", function()
        local groups = Rot:GetGroupedSpells()
        spellDataList = {}
        for name, data in pairs(groups) do table.insert(spellDataList, data) end
        table.sort(spellDataList, function(a,b) return a.name < b.name end)
        UpdateListScroll(); if listFrame:IsShown() then listFrame:Hide() else listFrame:Show() end
    end)

    UIDropDownMenu_Initialize(ddCrit, function(self, level)
        if not selectedName then return end
        local groups = Rot:GetGroupedSpells(); local g = groups[selectedName]; if not g then return end
        local function AddOpt(text, val)
            local info = UIDropDownMenu_CreateInfo(); info.text = text; info.arg1 = val
            info.func = function(_, v) selectedCrit = v; UIDropDownMenu_SetText(ddCrit, text) end; UIDropDownMenu_AddButton(info)
        end
        AddOpt("Highest Rank", "RANK")
        if g.hasHPS then AddOpt("Best HPS", "HPS") end
        if g.hasHPM then AddOpt("Best HPM", "HPM") end
        if g.hasDPS then AddOpt("Best DPS", "DPS") end
        if g.hasDPM then AddOpt("Best DPM", "DPM") end
    end)

    btnAction:SetScript("OnClick", function()
        if selectedName then
            if editModeIndex then
                Rot:UpdateStep(editModeIndex, selectedName, selectedCrit)
                editModeIndex = nil; btnAction:SetText("Add"); btnSpell:SetText("Select Spell..."); selectedName = nil
            else Rot:AddStep(selectedName, selectedCrit) end
            UI:RefreshList()
        end
    end)

    -- --- ROTATION LIST ---
    local scroll = CreateFrame("ScrollFrame", "JamboRotScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -100); scroll:SetPoint("BOTTOMRIGHT", -40, 20)
    scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UI.RefreshList) end)
    UI.scroll = scroll
    
    UI.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT); row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i-1)*ROW_HEIGHT); row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
        
        row:SetScript("OnClick", function(self)
            local step = NS.db.steps[self.idx]
            if step then
                editModeIndex = self.idx; selectedName = step.name; selectedCrit = step.criteria
                btnSpell:SetText(selectedName); UIDropDownMenu_SetText(ddCrit, (selectedCrit=="RANK" and "Highest Rank" or selectedCrit))
                btnAction:SetText("Update")
            end
        end)
        
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("TOPLEFT", 5, -5)
        row.condText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.condText:SetPoint("BOTTOMLEFT", 5, 5); row.condText:SetTextColor(0.8, 0.8, 0.8)

        local function MkBtn(txt, w, fn)
            local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate"); b:SetSize(w, 18); b:SetText(txt); b:SetScript("OnClick", fn); return b
        end
        row.del = MkBtn("X", 20, function() Rot:RemoveStep(row.idx); UI:RefreshList() end); row.del:SetPoint("RIGHT", 0, 0)
        row.down = MkBtn("v", 20, function() Rot:MoveStep(row.idx, 1); UI:RefreshList() end); row.down:SetPoint("RIGHT", row.del, "LEFT", -2, 0)
        row.up = MkBtn("^", 20, function() Rot:MoveStep(row.idx, -1); UI:RefreshList() end); row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
        row.conds = MkBtn("Conds", 45, function() UI:OpenConditionManager(row.idx) end); row.conds:SetPoint("RIGHT", row.up, "LEFT", -5, 0)
        UI.rows[i] = row
    end
    
    UI.frame = f
    UI:RefreshList()
    C_Timer.NewTicker(0.5, function() if f:IsShown() then UI:RefreshList() end end)
end

function UI:RefreshList()
    if not NS.db then return end
    local list = NS.db.steps
    local offset = FauxScrollFrame_GetOffset(UI.scroll) or 0
    for i = 1, MAX_ROWS do
        local row = UI.rows[i]; local idx = offset + i
        if idx <= #list then
            local step = list[idx]; row:Show(); row.idx = idx
            local crit = (step.criteria == "RANK") and "Max" or step.criteria
            row.text:SetText(string.format("%d. %s (%s)", idx, step.name, crit))
            local cText = ""
            local pass, results = Rot:EvaluateConditions(step)
            local anyFail = false
            if results then
                for _, res in ipairs(results) do
                    local color = res.pass and "|cff00ff00" or "|cffff0000"
                    local valStr = (res.val ~= 999) and (" " .. tostring(res.val)) or ""
                    cText = cText .. string.format("%s[%s %s%s]|r  ", color, res.type, res.note, valStr)
                    if not res.pass then anyFail = true end
                end
            end
            row.condText:SetText(cText)
            if anyFail then row:SetBackdropColor(0.3, 0, 0, 0.5)
            elseif pass and Rot:ResolveStep(step) then row:SetBackdropColor(0, 0.3, 0, 0.5)
            else row:SetBackdropColor(0.15, 0.15, 0.15, 0.5) end
        else row:Hide() end
    end
    FauxScrollFrame_Update(UI.scroll, #list, MAX_ROWS, ROW_HEIGHT)
end

function UI:Toggle() if not UI.frame then UI:Init() end; if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end end