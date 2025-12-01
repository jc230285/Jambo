local ADDON, NS = ...
local Rot = NS.Rot
NS.UI = NS.UI or {}
local UI = NS.UI
local checkId = 0

-- Helper: Apply Style
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
    f:SetSize(300, 400); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    ApplyJamboStyle(f)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -15); title:SetText("Conditions (Step " .. stepIndex .. ")")

    local step = NS.db.steps[stepIndex]
    if not f.rows then f.rows = {} end
    
    local function RefreshMgr()
        local list = step.conditions or {}
        for i=1, 8 do
            if not f.rows[i] then
                local r = CreateFrame("Frame", nil, f, "BackdropTemplate")
                r:SetSize(280, 30); r:SetPoint("TOP", 0, -40 - (i-1)*35)
                r:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1})
                r:SetBackdropColor(0.2, 0.2, 0.2, 0.5); r:SetBackdropBorderColor(0,0,0,1)
                r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.txt:SetPoint("LEFT", 5, 0)
                
                local function MkBtn(txt, w, fn)
                    local b = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
                    b:SetSize(w, 20); b:SetText(txt); b:SetScript("OnClick", fn); return b
                end
                r.del = MkBtn("X", 20, function() Rot:RemoveCondition(stepIndex, r.idx); RefreshMgr(); UI:RefreshList() end); r.del:SetPoint("RIGHT", -2, 0)
                r.down = MkBtn("v", 20, function() Rot:MoveCondition(stepIndex, r.idx, 1); RefreshMgr(); UI:RefreshList() end); r.down:SetPoint("RIGHT", r.del, "LEFT", -2, 0)
                r.up = MkBtn("^", 20, function() Rot:MoveCondition(stepIndex, r.idx, -1); RefreshMgr(); UI:RefreshList() end); r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
                r.edit = MkBtn("Edit", 40, function() UI:OpenConditionEditor(stepIndex, r.idx) end); r.edit:SetPoint("RIGHT", r.up, "LEFT", -5, 0)
                f.rows[i] = r
            end
            local row = f.rows[i]
            if i <= #list then
                row:Show(); row.idx = i; local c = list[i]
                local v = (c.value~=999) and tostring(c.value) or ""
                if c.type=="SPELL_READY" then v = c.spell or "?" end
                row.txt:SetText(string.format("%s: %s", c.type, v))
            else row:Hide() end
        end
    end
    RefreshMgr()
    
    local btnAdd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnAdd:SetSize(100, 24); btnAdd:SetPoint("BOTTOM", 0, 40); btnAdd:SetText("Add New")
    btnAdd:SetScript("OnClick", function() UI:OpenConditionEditor(stepIndex, nil) end)
    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnClose:SetSize(80, 24); btnClose:SetPoint("BOTTOM", 0, 15); btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function() f:Hide() end)

    UI.condManager = f; f:Show()
end

function UI:OpenConditionEditor(stepIndex, condIndex)
    if UI.editor then UI.editor:Hide() end
    local f = CreateFrame("Frame", "JamboRotEditor", UIParent, "BackdropTemplate")
    f:SetSize(320, 480); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    ApplyJamboStyle(f)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); title:SetPoint("TOP", 0, -10); title:SetText(condIndex and "Edit Condition" or "Add Condition")
    local step = NS.db.steps[stepIndex]
    local config
    if condIndex and step.conditions[condIndex] then
        config = {}; for k,v in pairs(step.conditions[condIndex]) do config[k] = v end
    else
        config = { type = "COMBAT", expected = true, spell = "Auto", checkSlot = true, checkMana = true, checkRange = true, checkCD = true, checkCDTime = false, op = "<", cdValue = "0.5", unit = "target" }
    end

    local ddType = CreateFrame("Frame", "$parentTypeDD", f, "UIDropDownMenuTemplate"); ddType:SetPoint("TOPLEFT", 10, -40); UIDropDownMenu_SetWidth(ddType, 150)
    local function InitTypeMenu(self, level)
        local types = {"COMBAT", "SPELL_READY"}
        for _, t in ipairs(types) do
            local info = UIDropDownMenu_CreateInfo(); info.text = t; info.func = function() config.type = t; UIDropDownMenu_SetText(ddType, t); UI:RefreshEditor(f, config) end; UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(ddType, InitTypeMenu); UIDropDownMenu_SetText(ddType, config.type)

    local container = CreateFrame("Frame", nil, f); container:SetPoint("TOPLEFT", 20, -80); container:SetPoint("BOTTOMRIGHT", -20, 50); f.container = container
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
    local c = f.container
    for _, child in ipairs({c:GetChildren()}) do child:Hide() end
    local y = 0
    local function AddCheck(label, key)
        checkId = checkId + 1; local cbName = "JamboRotCheck"..checkId
        local cb = CreateFrame("CheckButton", cbName, c, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, y); cb:SetSize(24, 24)
        if _G[cbName.."Text"] then _G[cbName.."Text"]:SetText(label) end
        cb:SetChecked(config[key]); cb:SetScript("OnClick", function() config[key] = cb:GetChecked() end)
        cb:Show(); y = y - 30; return cb
    end
    AddCheck("Condition Must Be TRUE", "expected")
    if config.type == "COMBAT" then
        checkId = checkId + 1; local cbName = "JamboRotCheck"..checkId
        local cbVal = CreateFrame("CheckButton", cbName, c, "UICheckButtonTemplate")
        cbVal:SetPoint("TOPLEFT", 0, y); _G[cbName.."Text"]:SetText("Player In Combat")
        cbVal:SetChecked(config.value ~= false); cbVal:SetScript("OnClick", function() config.value = cbVal:GetChecked() end)
        cbVal:Show()
    elseif config.type == "SPELL_READY" then
        local lblS = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lblS:SetPoint("TOPLEFT", 0, y); lblS:SetText("Spell Name:"); y = y - 20
        local eb = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); eb:SetSize(200, 20); eb:SetPoint("TOPLEFT", 0, y); eb:SetAutoFocus(false); eb:SetText(config.spell or "Auto"); eb:SetScript("OnTextChanged", function(self) config.spell = self:GetText() end); eb:Show(); y = y - 30
        AddCheck("Is Castable", "checkRange"); AddCheck("Enough Mana", "checkMana"); AddCheck("Has Slot ID", "checkSlot"); AddCheck("Is Off Cooldown", "checkCD")
        local cbTime = AddCheck("Check Cooldown Time", "checkCDTime")
        local ddOp = CreateFrame("Frame", "$parentOpDD", c, "UIDropDownMenuTemplate"); ddOp:SetPoint("LEFT", cbTime, "RIGHT", 150, 0); UIDropDownMenu_SetWidth(ddOp, 40); UIDropDownMenu_SetText(ddOp, config.op)
        local function InitOp(self, level)
            local info = UIDropDownMenu_CreateInfo(); info.text = "<"; info.func = function() config.op = "<"; UIDropDownMenu_SetText(ddOp, "<") end; UIDropDownMenu_AddButton(info)
            info = UIDropDownMenu_CreateInfo(); info.text = ">"; info.func = function() config.op = ">"; UIDropDownMenu_SetText(ddOp, ">") end; UIDropDownMenu_AddButton(info)
        end
        UIDropDownMenu_Initialize(ddOp, InitOp); ddOp:Show()
        local ebVal = CreateFrame("EditBox", nil, c, "InputBoxTemplate"); ebVal:SetSize(40, 20); ebVal:SetPoint("LEFT", ddOp, "RIGHT", 0, 2); ebVal:SetAutoFocus(false); ebVal:SetText(config.cdValue); ebVal:SetScript("OnTextChanged", function(self) config.cdValue = self:GetText() end); ebVal:Show()
    end
end