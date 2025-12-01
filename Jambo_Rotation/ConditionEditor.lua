local ADDON, NS = ...
local Rot = NS.Rot
NS.UI = NS.UI or {}
local UI = NS.UI
local checkId = 0

local WIN_WIDTH = 320
local WIN_HEIGHT = 600
local ROW_HEIGHT = 35
local MAX_ROWS = 10

local function ApplyJamboStyle(f)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        edgeFile = "Interface\\Buttons\\WHITE8x8", 
        edgeSize = 1, 
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

function UI:OpenConditionManager(stepIndex)
    if UI.condManager then UI.condManager:Hide() end
    
    local f = CreateFrame("Frame", "JamboRotCondMgr", UIParent, "BackdropTemplate")
    f:SetSize(WIN_WIDTH, WIN_HEIGHT)
    if UI.frame then f:SetPoint("TOPLEFT", UI.frame, "TOPRIGHT", 5, 0) else f:SetPoint("CENTER") end
    f:SetFrameStrata("DIALOG"); ApplyJamboStyle(f)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10); title:SetText("Conditions (Step " .. stepIndex .. ")")

    local step = NS.db.steps[stepIndex]
    local scroll = CreateFrame("ScrollFrame", "JamboRotCondScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -40); scroll:SetPoint("BOTTOMRIGHT", -30, 50)
    if not f.rows then f.rows = {} end
    
    local function RefreshMgr()
        local list = step.conditions or {}
        FauxScrollFrame_Update(scroll, #list, MAX_ROWS, ROW_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(scroll)
        for i=1, MAX_ROWS do
            if not f.rows[i] then
                local r = CreateFrame("Frame", nil, f, "BackdropTemplate")
                r:SetSize(WIN_WIDTH - 40, ROW_HEIGHT - 2)
                r:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i-1)*ROW_HEIGHT)
                r:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1})
                r:SetBackdropColor(0.2, 0.2, 0.2, 0.5); r:SetBackdropBorderColor(0,0,0,1)
                r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                r.txt:SetPoint("LEFT", 5, 0); r.txt:SetWidth(160); r.txt:SetJustifyH("LEFT"); r.txt:SetWordWrap(false)
                local function MkBtn(txt, w, fn) local b = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); b:SetSize(w, 20); b:SetText(txt); b:SetScript("OnClick", fn); return b end
                r.del = MkBtn("X", 20, function() Rot:RemoveCondition(stepIndex, r.idx); RefreshMgr(); UI:RefreshList() end); r.del:SetPoint("RIGHT", -2, 0)
                r.down = MkBtn("v", 20, function() Rot:MoveCondition(stepIndex, r.idx, 1); RefreshMgr(); UI:RefreshList() end); r.down:SetPoint("RIGHT", r.del, "LEFT", -2, 0)
                r.up = MkBtn("^", 20, function() Rot:MoveCondition(stepIndex, r.idx, -1); RefreshMgr(); UI:RefreshList() end); r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
                r.edit = MkBtn("Edit", 35, function() UI:OpenConditionEditor(stepIndex, r.idx) end); r.edit:SetPoint("RIGHT", r.up, "LEFT", -2, 0)
                f.rows[i] = r
            end
            local row = f.rows[i]; local idx = offset + i
            if idx <= #list then
                row:Show(); row.idx = idx; local c = list[idx]
                local valStr = tostring(c.value)
                if c.type == "COMBAT" then valStr = c.value and "In" or "Out"
                elseif c.type == "SPELL_READY" then valStr = c.spell or "?"
                elseif c.type == "AURA" then valStr = c.nameContains or c.spellID or "Any"
                elseif c.type == "UNIT_TYPE" then valStr = c.values or "?"
                elseif c.type == "MOVING" then valStr = c.value and "True" or "False"
                elseif c.type == "IN_GROUP" then valStr = c.groupType or "Any" end
                
                local statusColor = (c.expected == false) and "|cffffaa00(NOT)|r " or "|cffffffff"
                row.txt:SetText(string.format("%s%s: %s", statusColor, c.type, valStr))
            else row:Hide() end
        end
    end
    scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, RefreshMgr) end)
    RefreshMgr()
    
    local btnAdd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnAdd:SetSize(100, 24); btnAdd:SetPoint("BOTTOM", 0, 40); btnAdd:SetText("Add New")
    btnAdd:SetScript("OnClick", function() UI:OpenConditionEditor(stepIndex, nil) end)
    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnClose:SetSize(80, 24); btnClose:SetPoint("BOTTOM", 0, 15); btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function() f:Hide(); if UI.editor then UI.editor:Hide() end end)
    UI.condManager = f; f:Show()
end

function UI:OpenConditionEditor(stepIndex, condIndex)
    if UI.editor then UI.editor:Hide() end
    local f = CreateFrame("Frame", "JamboRotEditor", UIParent, "BackdropTemplate")
    f:SetSize(WIN_WIDTH, WIN_HEIGHT)
    if UI.condManager and UI.condManager:IsShown() then f:SetPoint("TOPLEFT", UI.condManager, "TOPRIGHT", 5, 0)
    elseif UI.frame then f:SetPoint("TOPLEFT", UI.frame, "TOPRIGHT", 5, 0)
    else f:SetPoint("CENTER") end
    f:SetFrameStrata("DIALOG")
    ApplyJamboStyle(f)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); title:SetPoint("TOP", 0, -10); title:SetText(condIndex and "Edit Condition" or "Add Condition")
    local step = NS.db.steps[stepIndex]
    local config
    if condIndex and step.conditions[condIndex] then
        config = {}; for k,v in pairs(step.conditions[condIndex]) do config[k] = v end
    else
        config = { type = "COMBAT", expected = true, value=true, unit="target" } -- Base defaults
    end

    local ddType = CreateFrame("Frame", "$parentTypeDD", f, "UIDropDownMenuTemplate"); ddType:SetPoint("TOPLEFT", 10, -40); UIDropDownMenu_SetWidth(ddType, 150)
    local function InitTypeMenu(self, level)
        local types = {"COMBAT", "SPELL_READY", "AURA", "RESOURCE", "UNIT_TYPE", "MOVING", "IN_GROUP"}
        for _, t in ipairs(types) do
            local info = UIDropDownMenu_CreateInfo(); info.text = t; info.func = function() config.type = t; UIDropDownMenu_SetText(ddType, t); UI:RefreshEditor(f, config) end; UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(ddType, InitTypeMenu); UIDropDownMenu_SetText(ddType, config.type)

    local scroll = CreateFrame("ScrollFrame", "JamboRotEditScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -80); scroll:SetPoint("BOTTOMRIGHT", -30, 50)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(WIN_WIDTH - 50, 600); scroll:SetScrollChild(content); f.content = content

    local btnSave = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); btnSave:SetSize(80, 24); btnSave:SetPoint("BOTTOMRIGHT", -20, 20); btnSave:SetText("Save")
    btnSave:SetScript("OnClick", function()
        if condIndex then Rot:UpdateCondition(stepIndex, condIndex, config) else Rot:AddCondition(stepIndex, config) end
        f:Hide(); if UI.condManager and UI.condManager:IsShown() then UI:OpenConditionManager(stepIndex) end; UI:RefreshList()
    end)
    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); btnClose:SetSize(80, 24); btnClose:SetPoint("RIGHT", btnSave, "LEFT", -10, 0); btnClose:SetText("Cancel")
    btnClose:SetScript("OnClick", function() f:Hide() end)

    UI.editor = f; UI:RefreshEditor(f, config); f:Show()
end

function UI:RefreshEditor(f, config)
    local c = f.content
    for _, child in ipairs({c:GetChildren()}) do child:Hide() end
    local y = 0
    local function AddCheck(label, key, onClickExtra)
        checkId = checkId + 1; local cbName = "JamboRotCheck"..checkId
        local cb = CreateFrame("CheckButton", cbName, c, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, y); cb:SetSize(24, 24)
        if _G[cbName.."Text"] then _G[cbName.."Text"]:SetText(label) end
        cb:SetChecked(config[key]); cb:SetScript("OnClick", function() config[key] = cb:GetChecked(); if onClickExtra then onClickExtra() end end)
        cb:Show(); y = y - 30; return cb
    end
    AddCheck("Condition Must Be TRUE", "expected")

    -- Helper for Unit Dropdown
    local function AddUnitDD()
        local lblU = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblU:SetPoint("TOPLEFT", 0, y); lblU:SetText("Unit:"); y = y - 20
        local ddUnit = CreateFrame("Frame", "$parentUnitDD", c, "UIDropDownMenuTemplate"); ddUnit:SetPoint("TOPLEFT", -15, y); UIDropDownMenu_SetWidth(ddUnit, 120)
        UIDropDownMenu_SetText(ddUnit, config.unit or "player")
        UIDropDownMenu_Initialize(ddUnit, function()
            for _, u in ipairs({"player","target","pet","focus","mouseover"}) do
                local info = UIDropDownMenu_CreateInfo(); info.text = u; info.func = function() config.unit = u; UIDropDownMenu_SetText(ddUnit, u) end; UIDropDownMenu_AddButton(info)
            end
        end)
        ddUnit:Show(); y = y - 30
    end

    if config.type == "COMBAT" then
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lbl:SetPoint("TOPLEFT", 0, y); lbl:SetText("Status:"); y = y - 20
        local ddStat = CreateFrame("Frame", "$parentCombDD", c, "UIDropDownMenuTemplate"); ddStat:SetPoint("TOPLEFT", -10, y); UIDropDownMenu_SetWidth(ddStat, 140)
        local function InitStat(self, level)
            local info = UIDropDownMenu_CreateInfo()
            info.text = "In Combat"; info.func = function() config.value = true; UIDropDownMenu_SetText(ddStat, "In Combat") end; UIDropDownMenu_AddButton(info)
            info = UIDropDownMenu_CreateInfo(); info.text = "Out of Combat"; info.func = function() config.value = false; UIDropDownMenu_SetText(ddStat, "Out of Combat") end; UIDropDownMenu_AddButton(info)
        end
        UIDropDownMenu_Initialize(ddStat, InitStat); UIDropDownMenu_SetText(ddStat, (config.value == true) and "In Combat" or "Out of Combat"); ddStat:Show()
        
    elseif config.type == "UNIT_TYPE" then
        AddUnitDD()
        local lblV = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblV:SetPoint("TOPLEFT", 0, y); lblV:SetText("Types (comma separated):"); y = y - 20
        local ebVal = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); ebVal:SetSize(200, 20); ebVal:SetPoint("TOPLEFT", 5, y); ebVal:SetAutoFocus(false); ebVal:SetText(config.values or "")
        ebVal:SetScript("OnTextChanged", function(self) config.values = self:GetText() end); ebVal:Show(); y = y - 30
        local lblH = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); lblH:SetPoint("TOPLEFT", 5, y); lblH:SetText("e.g. 'enemy, demon, tank'"); lblH:Show()
        
    elseif config.type == "MOVING" then
        AddUnitDD()
        AddCheck("Is Moving (Uncheck for Stationary)", "value")
        
    elseif config.type == "IN_GROUP" then
        local lblG = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblG:SetPoint("TOPLEFT", 0, y); lblG:SetText("Group Type:"); y = y - 20
        local ddGrp = CreateFrame("Frame", "$parentGrpDD", c, "UIDropDownMenuTemplate"); ddGrp:SetPoint("TOPLEFT", -15, y); UIDropDownMenu_SetWidth(ddGrp, 120)
        local types = {"ANY", "PARTY", "RAID", "SOLO"}
        UIDropDownMenu_SetText(ddGrp, config.groupType or "ANY")
        UIDropDownMenu_Initialize(ddGrp, function()
            for _, t in ipairs(types) do
                local info = UIDropDownMenu_CreateInfo(); info.text = t; info.func = function() config.groupType = t; UIDropDownMenu_SetText(ddGrp, t) end; UIDropDownMenu_AddButton(info)
            end
        end)
        ddGrp:Show()

    elseif config.type == "RESOURCE" then
        AddUnitDD()
        local lblR = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblR:SetPoint("TOPLEFT", 0, y); lblR:SetText("Resource:"); y = y - 20
        local ddRes = CreateFrame("Frame", "$parentResDD", c, "UIDropDownMenuTemplate"); ddRes:SetPoint("TOPLEFT", -15, y); UIDropDownMenu_SetWidth(ddRes, 120)
        local rMap = { hp = "Health", mana = "Mana", rage = "Rage", energy = "Energy", combo = "Combo Points" }
        UIDropDownMenu_SetText(ddRes, rMap[config.resource] or config.resource or "Health")
        UIDropDownMenu_Initialize(ddRes, function()
            for k, v in pairs(rMap) do
                local info = UIDropDownMenu_CreateInfo(); info.text = v; info.func = function() config.resource = k; UIDropDownMenu_SetText(ddRes, v); UI:RefreshEditor(f, config) end; UIDropDownMenu_AddButton(info)
            end
        end)
        ddRes:Show(); y = y - 30
        
        local ddOp = CreateFrame("Frame", "$parentOpDD", c, "UIDropDownMenuTemplate"); ddOp:SetPoint("TOPLEFT", 20, y); UIDropDownMenu_SetWidth(ddOp, 40); UIDropDownMenu_SetText(ddOp, config.operator or "<")
        UIDropDownMenu_Initialize(ddOp, function()
            for _, op in ipairs({"<", ">", "<=", ">=", "=", "!="}) do
                local info = UIDropDownMenu_CreateInfo(); info.text = op; info.func = function() config.operator = op; UIDropDownMenu_SetText(ddOp, op) end; UIDropDownMenu_AddButton(info)
            end
        end)
        ddOp:Show()
        local ebVal = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); ebVal:SetSize(60, 20); ebVal:SetPoint("LEFT", ddOp, "RIGHT", 0, 2); ebVal:SetAutoFocus(false); ebVal:SetNumeric(true)
        ebVal:SetText(config.value or 0); ebVal:SetScript("OnTextChanged", function(self) config.value = tonumber(self:GetText()) end); ebVal:Show()
        y = y - 30
        AddCheck("As Percent (%)", "percent")
        if config.resource == "hp" then AddCheck("Include Incoming Heals", "includeIncoming") end
        
    elseif config.type == "SPELL_READY" then
        local lblS = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblS:SetPoint("TOPLEFT", 0, y); lblS:SetText("Spell Name:"); y = y - 20
        local eb = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); eb:SetSize(200, 20); eb:SetPoint("TOPLEFT", 0, y); eb:SetAutoFocus(false); eb:SetText(config.spell or "Auto"); eb:SetScript("OnTextChanged", function(self) config.spell = self:GetText() end); eb:Show(); y = y - 30
        AddCheck("Is Castable", "checkRange"); AddCheck("Enough Mana", "checkMana"); AddCheck("Has Slot ID", "checkSlot"); AddCheck("Is Off Cooldown", "checkCD")
        local cbTime = AddCheck("Check Cooldown Time", "checkCDTime")
        local ddOp = CreateFrame("Frame", "$parentOpDD", c, "UIDropDownMenuTemplate"); ddOp:SetPoint("LEFT", cbTime, "RIGHT", 150, 0); UIDropDownMenu_SetWidth(ddOp, 40); UIDropDownMenu_SetText(ddOp, config.op)
        UIDropDownMenu_Initialize(ddOp, function()
            for _, op in ipairs({"<", ">"}) do local info = UIDropDownMenu_CreateInfo(); info.text = op; info.func = function() config.op = op; UIDropDownMenu_SetText(ddOp, op) end; UIDropDownMenu_AddButton(info) end
        end)
        ddOp:Show()
        local ebVal = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); ebVal:SetSize(40, 20); ebVal:SetPoint("LEFT", ddOp, "RIGHT", 0, 2); ebVal:SetAutoFocus(false); ebVal:SetText(config.cdValue); ebVal:SetScript("OnTextChanged", function(self) config.cdValue = self:GetText() end); ebVal:Show()
    
    elseif config.type == "AURA" then
        AddUnitDD()
        local lblN = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblN:SetPoint("TOPLEFT", 0, y); lblN:SetText("Aura Name:"); y = y - 20
        local ebName = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); ebName:SetSize(200, 20); ebName:SetPoint("TOPLEFT", 5, y); ebName:SetAutoFocus(false); ebName:SetText(config.nameContains or ""); ebName:SetScript("OnTextChanged", function(self) config.nameContains = self:GetText() end); ebName:Show(); y = y - 30
        AddCheck("Is Debuff", "isDebuff"); AddCheck("Is Missing", "missing"); AddCheck("Source is Player", "sourceIsPlayer")
    end
end