local ADDON, NS = ...
local Rot = NS.Rot

NS.UI = NS.UI or {}
local UI = NS.UI

local ROW_HEIGHT = 50 -- Taller for notes
local ROW_SPACING = 5
local MAX_ROWS = 7 -- Reduced to fit height with spacing

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
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local a, _, b, x, y = self:GetPoint()
            NS.db.pos = { a, b, x, y }
        end)
        f.dragLib = true
    end
end

function UI:CloseAll()
    if UI.frame then UI.frame:Hide() end
    if UI.condManager then UI.condManager:Hide() end
    if UI.editor then UI.editor:Hide() end
    if UI.ioFrame then UI.ioFrame:Hide() end
end

-- --- IMPORT / EXPORT WINDOW ---
function UI:OpenIO(isExport)
    if UI.ioFrame then UI.ioFrame:Hide() end
    local f = CreateFrame("Frame", "JamboRotIO", UIParent, "BackdropTemplate")
    f:SetSize(400, 300); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    ApplyJamboStyle(f)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10); title:SetText(isExport and "Export Rotation" or "Import Rotation")
    local scroll = CreateFrame("ScrollFrame", "JamboRotIOScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30); scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(350); scroll:SetScrollChild(edit)
    if isExport then
        edit:SetText(Rot:GetExportString()); edit:HighlightText(); edit:SetFocus()
    else
        edit:SetText(""); edit:SetFocus()
        local btnImp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnImp:SetSize(100, 24); btnImp:SetPoint("BOTTOM", 0, 10); btnImp:SetText("Import")
        btnImp:SetScript("OnClick", function()
            local success = Rot:ImportString(edit:GetText())
            if success then print("|cff00ff00[JamboRotation]|r Import Successful"); UI:RefreshList(); f:Hide()
            else print("|cffff0000[JamboRotation]|r Import Failed") end
        end)
    end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2); close:SetScript("OnClick", function() f:Hide() end)
    UI.ioFrame = f; f:Show()
end

function UI:Init()
    if UI.frame then UI.frame:Show(); return end
    
    local f = CreateFrame("Frame", "JamboRotFrame", UIParent, "BackdropTemplate")
    f:SetSize(600, 600) -- Increased height
    if NS.db.pos then f:SetPoint(NS.db.pos[1], UIParent, NS.db.pos[2], NS.db.pos[3], NS.db.pos[4]) else f:SetPoint("CENTER") end
    f:SetToplevel(true)
    ApplyJamboStyle(f)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -8); f.title:SetText("Jambo Rotation V2.4")
    
    -- IO Buttons
    local btnExp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnExp:SetSize(60, 20); btnExp:SetPoint("TOPRIGHT", -30, -8); btnExp:SetText("Export")
    btnExp:SetScript("OnClick", function() UI:OpenIO(true) end)
    local btnImp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnImp:SetSize(60, 20); btnImp:SetPoint("RIGHT", btnExp, "LEFT", -5, 0); btnImp:SetText("Import")
    btnImp:SetScript("OnClick", function() UI:OpenIO(false) end)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2); close:SetScript("OnClick", function() UI:CloseAll() end)

    -- --- EDITOR PANEL ---
    local editFrame = CreateFrame("Frame", nil, f)
    editFrame:SetPoint("TOPLEFT", 0, -30)
    editFrame:SetPoint("TOPRIGHT", 0, -30)
    editFrame:SetHeight(90) -- Increased for Note
    
    local btnSpell = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    btnSpell:SetSize(200, 24); btnSpell:SetPoint("TOPLEFT", 20, -15); btnSpell:SetText("Select Spell...")
    
    local ddCrit = CreateFrame("Frame", "JamboRotCritDD", editFrame, "UIDropDownMenuTemplate")
    ddCrit:SetPoint("TOPLEFT", 230, -12); UIDropDownMenu_SetWidth(ddCrit, 120); UIDropDownMenu_SetText(ddCrit, "Highest Rank")
    
    -- Note Input
    local lblNote = editFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblNote:SetPoint("TOPLEFT", 20, -45); lblNote:SetText("Note:")
    local ebNote = CreateFrame("EditBox", nil, editFrame, "InputBoxTemplate")
    ebNote:SetSize(340, 20); ebNote:SetPoint("LEFT", lblNote, "RIGHT", 10, 0); ebNote:SetAutoFocus(false)
    
    -- Action Buttons
    local btnAction = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    btnAction:SetSize(80, 24); btnAction:SetPoint("LEFT", ebNote, "RIGHT", 10, 0); btnAction:SetText("Add")

    local btnClone = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    btnClone:SetSize(60, 24); btnClone:SetPoint("LEFT", btnAction, "RIGHT", 5, 0); btnClone:SetText("Clone")
    btnClone:Hide()
    
    local btnClear = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    btnClear:SetSize(60, 24); btnClear:SetPoint("LEFT", btnClone, "RIGHT", 5, 0); btnClear:SetText("Clear")
    btnClear:Hide()

    -- State
    local selectedName = nil
    local selectedCrit = "RANK"
    local editModeIndex = nil

    local function ResetEditor()
        editModeIndex = nil; selectedName = nil; selectedCrit = "RANK"
        btnSpell:SetText("Select Spell..."); UIDropDownMenu_SetText(ddCrit, "Highest Rank"); ebNote:SetText("")
        btnAction:SetText("Add"); btnClone:Hide(); btnClear:Hide()
    end
    btnClear:SetScript("OnClick", ResetEditor)

    -- Spell List Popup (Same as before)
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
                b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.txt:SetPoint("LEFT", 5, 0); b.txt:SetWidth(200); b.txt:SetJustifyH("LEFT")
                b:SetScript("OnClick", function(self) 
                    selectedName = self.info.name; btnSpell:SetText(selectedName); listFrame:Hide()
                    if not editModeIndex then selectedCrit = "RANK"; UIDropDownMenu_SetText(ddCrit, "Highest Rank") end
                end)
                listFrame.buttons[i] = b
            end
            local idx = offset + i
            if idx <= #spellDataList then
                local info = spellDataList[idx]; listFrame.buttons[i].info = info
                local color = "|cffffffff"
                if info.type == "ITEM" then color = "|cff00ccff" elseif info.type == "MACRO" then color = "|cffff3333" end
                listFrame.buttons[i].txt:SetText(color .. info.name)
                listFrame.buttons[i]:Show()
            else listFrame.buttons[i]:Hide() end
        end
    end
    listScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 16, UpdateListScroll) end)
    btnSpell:SetScript("OnClick", function()
        local groups = Rot:GetGroupedSpells(); spellDataList = {}
        for name, data in pairs(groups) do table.insert(spellDataList, data) end
        table.sort(spellDataList, function(a,b) return a.name < b.name end)
        if #spellDataList == 0 then print("|cffff0000[JamboRotation]|r No spells found. Jambo_Spells scanning..."); if JamboSpells and JamboSpells.FullScan then JamboSpells:FullScan() end; return end
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
            local note = ebNote:GetText()
            if editModeIndex then
                Rot:UpdateStep(editModeIndex, selectedName, selectedCrit, note)
                ResetEditor()
            else 
                Rot:AddStep(selectedName, selectedCrit, note) 
            end
            UI:RefreshList()
        end
    end)

    btnClone:SetScript("OnClick", function()
        if editModeIndex then
            local source = NS.db.steps[editModeIndex]
            if source then
                local newConds = {}; for _, c in ipairs(source.conditions or {}) do local nc = {}; for k,v in pairs(c) do nc[k]=v end; table.insert(newConds, nc) end
                table.insert(NS.db.steps, editModeIndex + 1, { name = source.name, criteria = source.criteria, note = source.note, conditions = newConds })
                ResetEditor(); UI:RefreshList()
            end
        end
    end)

    -- --- ROTATION LIST ---
    local scroll = CreateFrame("ScrollFrame", "JamboRotScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -110); scroll:SetPoint("BOTTOMRIGHT", -40, 20)
    scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT + ROW_SPACING, UI.RefreshList) end)
    UI.scroll = scroll
    
    UI.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f, "BackdropTemplate")
        -- Apply spacing in height calc
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i-1)*(ROW_HEIGHT + ROW_SPACING))
        row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
        
        -- Border Style
        row:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8", 
            edgeFile="Interface\\Buttons\\WHITE8x8", 
            edgeSize=1, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        row:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
        row:SetBackdropBorderColor(0, 0, 0, 1) -- Black Border
        
        row:SetScript("OnClick", function(self)
            local step = NS.db.steps[self.idx]
            if step then
                editModeIndex = self.idx; selectedName = step.name; selectedCrit = step.criteria
                btnSpell:SetText(selectedName)
                UIDropDownMenu_SetText(ddCrit, (selectedCrit=="RANK" and "Highest Rank" or selectedCrit))
                ebNote:SetText(step.note or "")
                btnAction:SetText("Update"); btnClone:Show(); btnClear:Show()
            end
        end)
        
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("TOPLEFT", 5, -5)
        row.note = row:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny"); row.note:SetPoint("LEFT", row.text, "RIGHT", 10, 0); row.note:SetTextColor(0.7, 0.7, 0.7)
        
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
    local groups = Rot:GetGroupedSpells()

    for i = 1, MAX_ROWS do
        local row = UI.rows[i]; local idx = offset + i
        if idx <= #list then
            local step = list[idx]; row:Show(); row.idx = idx
            
            -- 1. Resolve Display Info
            local displayInfo = ""
            local g = groups[step.name]
            if g then
                local candidates = {}
                for _, info in ipairs(g.ranks) do if info.SLOT and info.SLOT > 0 then table.insert(candidates, info) end end
                if #candidates > 0 then
                    local critKey = step.criteria or "RANK"
                    table.sort(candidates, function(a,b)
                        local vA = a[critKey] or 0; local vB = b[critKey] or 0
                        if vA == vB then return a.RANK > b.RANK end
                        return vA > vB
                    end)
                    local best = candidates[1]
                    displayInfo = string.format(" |cffffff00[R%d]|r |cff00ff00[S:%d]|r |cff888888[ID:%d]|r", best.RANK, best.SLOT, best.ID)
                else displayInfo = " |cffff0000(Not Slotted)|r" end
            else displayInfo = " |cffff0000(Unknown Spell)|r" end

            -- 2. Text & Note
            local crit = (step.criteria == "RANK") and "Max" or step.criteria
            row.text:SetText(string.format("%d. %s (%s)%s", idx, step.name, crit, displayInfo))
            
            if step.note and step.note ~= "" then
                row.note:SetText("(" .. step.note .. ")")
            else
                row.note:SetText("")
            end

            -- 3. Conditions Text
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
            
            -- 4. Row Status & Border
            row:SetBackdropBorderColor(0, 0, 0, 1) -- Reset border default
            
            if anyFail then 
                row:SetBackdropColor(0.3, 0, 0, 0.5) -- Red Fail
            elseif pass and Rot:ResolveStep(step) then 
                row:SetBackdropColor(0, 0.3, 0, 0.5) -- Green Active
                row:SetBackdropBorderColor(0, 1, 0, 1) -- Highlight Active Border
            else 
                row:SetBackdropColor(0.15, 0.15, 0.15, 0.5) -- Idle
            end
        else row:Hide() end
    end
    FauxScrollFrame_Update(UI.scroll, #list, MAX_ROWS, ROW_HEIGHT + ROW_SPACING)
end

function UI:Toggle() if not UI.frame then UI:Init() end; if UI.frame:IsShown() then UI:CloseAll() else UI.frame:Show() end end