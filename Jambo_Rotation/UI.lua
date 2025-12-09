local ADDON, NS = ...

NS.UI = NS.UI or {}
local UI = NS.UI

local Utils = NS.Utils

local ROW_H_ACT = 26
local ROW_H_COND = 22
local WIN_W, WIN_H = 720, 660
local LEFT_W = 230

local ddCounter = 0

local function newDropdown(parent, width, label)
    ddCounter = ddCounter + 1
    local name = "JamboRotDD" .. ddCounter
    local frame = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    frame:SetPoint("TOPLEFT", -15, 0)
    UIDropDownMenu_SetWidth(frame, width or 120)
    if label then
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", frame, "RIGHT", -5, 0)
        lbl:SetText(label)
        frame._label = lbl
    end
    return frame
end

local function setDropdownOptions(dropdown, current, items)
    UIDropDownMenu_SetText(dropdown, current or "")
    UIDropDownMenu_Initialize(dropdown, function()
        for _, info in ipairs(items) do
            local i = UIDropDownMenu_CreateInfo()
            i.text = info.text
            i.func = function()
                UIDropDownMenu_SetText(dropdown, info.text)
                if info.onSelect then info.onSelect(info.value, info.text) end
            end
            UIDropDownMenu_AddButton(i)
        end
    end)
end

local function newEditBox(parent, width)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width or 80, 20)
    eb:SetAutoFocus(false)
    return eb
end

local function newCheck(parent, text)
    local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    cb.Text:SetText(text)
    return cb
end

local function triStateDropdown(parent, label, data, key)
    local dd = newDropdown(parent, 110, label)
    dd.Refresh = function()
        setDropdownOptions(dd, data[key] or "IGNORE", {
            { text = "IGNORE", value = "IGNORE", onSelect = function() data[key] = "IGNORE" end },
            { text = "TRUE", value = "TRUE", onSelect = function() data[key] = "TRUE" end },
            { text = "FALSE", value = "FALSE", onSelect = function() data[key] = "FALSE" end },
        })
    end
    return dd
end

function UI:Init()
    if UI.frame then return end

    local f = CreateFrame("Frame", "JamboRotMain", UIParent, "BackdropTemplate")
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 8, -8)
    f.title:SetText("Jambo Rotation (Redux)")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    UI.frame = f

    UI:CreateLeftPanel()
    UI:CreateRightPanel()
    UI:CreateIconFrame()
    UI:CreatePicker()

    C_Timer.NewTicker(0.25, function()
        if UI.frame and UI.frame:IsShown() then UI:OnTick() end
    end)

    if NS.db and NS.db.steps and #NS.db.steps > 0 then UI:SelectAction(1) end
    f:Hide()
end

function UI:CreateLeftPanel()
    local p = CreateFrame("Frame", nil, UI.frame)
    p:SetPoint("TOPLEFT", 10, -32)
    p:SetPoint("BOTTOMLEFT", 10, 10)
    p:SetWidth(LEFT_W)

    local add = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    add:SetSize(LEFT_W, 22)
    add:SetPoint("TOPLEFT", 0, 0)
    add:SetText("+ Add Action")
    add:SetScript("OnClick", function()
        if not NS.db then return end
        table.insert(NS.db.steps, { name = "New Spell", criteria = "RANK", conditions = {} })
        UI:SelectAction(#NS.db.steps)
    end)

    local sf = CreateFrame("ScrollFrame", "JR_LeftScroll", p, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -26)
    sf:SetPoint("BOTTOMRIGHT", -26, 0)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H_ACT + 2, UI.RefreshList)
    end)
    UI.leftScroll = sf

    UI.rows = {}
    for i = 1, 16 do
        local r = CreateFrame("Button", nil, p, "BackdropTemplate")
        r:SetSize(LEFT_W - 6, ROW_H_ACT + 0)
        r:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, -(i - 1) * (ROW_H_ACT + 2))
        r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        r:SetBackdropColor(0.2, 0.2, 0.2, 0.85)
        r:SetBackdropBorderColor(0, 0, 0, 1)

        r.idx = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.idx:SetPoint("TOPLEFT", 4, -2)
        r.idx:SetWidth(16)
        r.idx:SetJustifyH("LEFT")

        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("TOPLEFT", r.idx, "TOPRIGHT", 2, 0)
        r.name:SetPoint("RIGHT", -40, -2)
        r.name:SetJustifyH("LEFT")

        r.meta = r:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        r.meta:SetPoint("TOPLEFT", r.idx, "BOTTOMLEFT", 0, -2)
        r.meta:SetPoint("RIGHT", -4, 0)
        r.meta:SetJustifyH("LEFT")
        r.meta:SetTextColor(0.7, 0.7, 0.7)

        r.up = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.up:SetSize(16, 14)
        r.up:SetPoint("RIGHT", -18, 0)
        r.up:SetText("^")
        r.up:SetScript("OnClick", function()
            UI:MoveAction(r.realIdx, -1)
        end)

        r.dn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.dn:SetSize(16, 14)
        r.dn:SetPoint("RIGHT", -2, 0)
        r.dn:SetText("v")
        r.dn:SetScript("OnClick", function()
            UI:MoveAction(r.realIdx, 1)
        end)

        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                UI:ToggleAction(r.realIdx)
                return
            end
            UI:SelectAction(r.realIdx)
        end)

        UI.rows[i] = r
    end
end

function UI:RefreshList()
    if not UI.leftScroll or not NS.db then return end
    local list = NS.db.steps
    local offset = FauxScrollFrame_GetOffset(UI.leftScroll) or 0

    for i, row in ipairs(UI.rows) do
        local idx = offset + i
        if idx <= #list then
            local step = list[idx]
            local key = step.name
            if step.criteria and step.criteria ~= "RANK" then key = step.name .. "_" .. step.criteria end
            local data = NS.Book[key] or NS.Book[step.name]

            local rank = data and data.rank or "?"
            local slot = data and data.slot or 0

            row.realIdx = idx
            row.idx:SetText(idx)
            local critTxt = (step.criteria and step.criteria ~= "RANK") and (" (" .. step.criteria .. ")") or ""
            row.name:SetText(step.name .. critTxt)

            local metaParts = {}
            if data then
                if data.slot and data.slot > 0 then table.insert(metaParts, "S:" .. data.slot) end
                if data.rank then table.insert(metaParts, "R:" .. data.rank) end
                if data.id then table.insert(metaParts, "ID:" .. data.id) end
            else
                table.insert(metaParts, "No data")
            end
                if step.note and step.note ~= "" then table.insert(metaParts, "N:" .. step.note) end
                if step.disabled then table.insert(metaParts, "OFF") end
            row.meta:SetText(table.concat(metaParts, "  "))

            local bg = { 0.2, 0.2, 0.2, 0.85 }
            if step.disabled then
                bg = { 0.05, 0.35, 0.75, 0.85 }
            elseif not data then bg = { 0.5, 0, 0.7, 0.7 }
            elseif slot == 0 and data.type ~= "MACRO" then bg = { 1, 0.5, 0, 0.7 }
            else
                local pass = NS.Engine:EvaluateStep(step)
                if pass then bg = { 0, 0.6, 0, 0.7 } else bg = { 0.6, 0, 0, 0.7 } end
            end
            row:SetBackdropColor(unpack(bg))
            if UI.selIdx == idx then row:SetBackdropBorderColor(1, 0.9, 0, 1) else row:SetBackdropBorderColor(0, 0, 0, 1) end
            row:Show()
        else
            row:Hide()
        end
    end

    FauxScrollFrame_Update(UI.leftScroll, #list, #UI.rows, ROW_H_ACT + 2)
end

function UI:MoveAction(index, dir)
    if not NS.db then return end
    local list = NS.db.steps
    local target = index + dir
    if target < 1 or target > #list then return end
    list[index], list[target] = list[target], list[index]
    UI:SelectAction(target)
end

function UI:ToggleAction(index)
    if not NS.db then return end
    local list = NS.db.steps
    local step = list and list[index]
    if not step then return end
    step.disabled = not step.disabled
    UI:RefreshList()
    if UI.right and UI.selIdx == index then UI:RefreshRightPanel() end
end

function UI:MoveCond(index, dir)
    if not UI.selIdx or not NS.db then return end
    local s = NS.db.steps[UI.selIdx]
    if not s or not s.conditions then return end
    local target = index + dir
    if target < 1 or target > #s.conditions then return end
    s.conditions[index], s.conditions[target] = s.conditions[target], s.conditions[index]
    UI:RefreshConds()
    UI:EditCondition(target)
end

function UI:CreateRightPanel()
    local p = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
    p:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", LEFT_W + 18, -32)
    p:SetPoint("BOTTOMRIGHT", -12, 10)
    p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    p:SetBackdropColor(0.12, 0.12, 0.12, 1)
    p:SetBackdropBorderColor(0, 0, 0, 1)
    UI.right = p
    p:Hide()

    p.btnName = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.btnName:SetSize(240, 24)
    p.btnName:SetPoint("TOPLEFT", 10, -10)
    p.btnName:SetText("Select Spell")
    p.btnName:SetScript("OnClick", function()
        if UI.picker:IsShown() then
            UI.picker:Hide()
            return
        end
        UI.picker:SetPoint("TOPLEFT", p.btnName, "BOTTOMLEFT", 0, 0)
        UI:RefreshPicker()
        UI.picker:Show()
    end)

    p.ddCrit = newDropdown(p, 140, "Criteria")
    p.ddCrit:SetPoint("TOPLEFT", p.btnName, "BOTTOMLEFT", 0, -8)

    p.noteLbl = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.noteLbl:SetPoint("TOPLEFT", p.ddCrit, "BOTTOMLEFT", 18, -10)
    p.noteLbl:SetText("Note")
    p.note = newEditBox(p, 260)
    p.note:SetPoint("LEFT", p.noteLbl, "RIGHT", 6, 0)
    p.note:SetHeight(20)
    p.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    p.btnDel = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.btnDel:SetSize(70, 22)
    p.btnDel:SetPoint("TOPRIGHT", -80, -10)
    p.btnDel:SetText("Delete")
    p.btnDel:SetScript("OnClick", function()
        if not UI.selIdx then return end
        table.remove(NS.db.steps, UI.selIdx)
        UI.selIdx = nil
        UI.right:Hide()
        UI:RefreshList()
    end)

    p.btnCopy = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.btnCopy:SetSize(70, 22)
    p.btnCopy:SetPoint("TOPRIGHT", -5, -10)
    p.btnCopy:SetText("Copy")
    p.btnCopy:SetScript("OnClick", function()
        if not UI.selIdx then return end
        local src = NS.db.steps[UI.selIdx]
        local copy = { name = src.name, criteria = src.criteria, conditions = Utils.DeepCopy(src.conditions or {}) }
        table.insert(NS.db.steps, UI.selIdx + 1, copy)
        UI:SelectAction(UI.selIdx + 1)
    end)

    local addCond = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    addCond:SetSize(100, 20)
    addCond:SetPoint("TOPRIGHT", -10, -80)
    addCond:SetText("+ Condition")
    addCond:SetScript("OnClick", function()
        if not UI.selIdx then return end
        local s = NS.db.steps[UI.selIdx]
        table.insert(s.conditions, {
            type = "SPELL",
            spellCondName = "AUTO",
            chkRemain = false,
            remOp = "<=",
            remVal = 0,
            chkCharges = false,
            chargesOp = "<=",
            chargesVal = 0,
            chkMana = false,
            chkRange = false,
            rangeUnit = "target",
            trueFlag = true,
        })
        UI:RefreshConds()
        UI:EditCondition(#s.conditions)
    end)

    local csf = CreateFrame("ScrollFrame", "JR_CondScroll", p, "FauxScrollFrameTemplate")
    csf:SetPoint("TOPLEFT", 0, -120)
    csf:SetPoint("BOTTOMRIGHT", -26, 210)
    csf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H_COND, UI.RefreshConds)
    end)
    UI.condScroll = csf

    p.cRows = {}
    for i = 1, 9 do
        local r = CreateFrame("Button", nil, p, "BackdropTemplate")
        r:SetSize(420, ROW_H_COND)
        r:SetPoint("TOPLEFT", csf, "TOPLEFT", 8, -(i - 1) * ROW_H_COND)
        r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        r:SetBackdropColor(0.18, 0.18, 0.18, 1)
        r:SetBackdropBorderColor(0, 0, 0, 1)

        r.stat = r:CreateTexture(nil, "ARTWORK")
        r.stat:SetSize(6, 6)
        r.stat:SetPoint("LEFT", 4, 0)

        r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.txt:SetPoint("LEFT", 14, 0)
        r.txt:SetWidth(240)
        r.txt:SetJustifyH("LEFT")

        r.val = r:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        r.val:SetPoint("LEFT", 260, 0)
        r.val:SetWidth(140)
        r.val:SetJustifyH("LEFT")
        r.val:SetTextColor(0, 0.9, 0.9)

        r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.del:SetSize(16, 14)
        r.del:SetPoint("RIGHT", -4, 0)
        r.del:SetText("X")
        r.del:SetScript("OnClick", function()
            if not UI.selIdx or not r.cIdx then return end
            table.remove(NS.db.steps[UI.selIdx].conditions, r.cIdx)
            UI.curCondIdx = nil
            UI:RefreshConds()
            if UI.right and UI.right.editor then UI.right.editor:Hide() end
        end)

        r.up = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.up:SetSize(14, 12)
        r.up:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
        r.up:SetText("^")
        r.up:SetScript("OnClick", function()
            UI:MoveCond(r.cIdx, -1)
        end)

        r.dn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.dn:SetSize(14, 12)
        r.dn:SetPoint("RIGHT", r.up, "LEFT", -4, 0)
        r.dn:SetText("v")
        r.dn:SetScript("OnClick", function()
            UI:MoveCond(r.cIdx, 1)
        end)

        r:SetScript("OnClick", function()
            UI:EditCondition(r.cIdx)
        end)

        p.cRows[i] = r
    end

    UI:CreateEditor(p)
end

function UI:RefreshRightPanel()
    if not UI.selIdx or not NS.db or not NS.db.steps or not UI.right then return end
    local s = NS.db.steps[UI.selIdx]
    if not s then return end

    local function critLabel(val)
        if not val or val == "RANK" then return "Max Rank" end
        return "Best " .. val
    end

    if UI.right.ddCrit then
        setDropdownOptions(UI.right.ddCrit, critLabel(s.criteria), {
            { text = "Max Rank", value = "RANK", onSelect = function() s.criteria = "RANK"; UI:RefreshList() end },
            { text = "Best DPS", value = "DPS", onSelect = function() s.criteria = "DPS"; UI:RefreshList() end },
            { text = "Best HPS", value = "HPS", onSelect = function() s.criteria = "HPS"; UI:RefreshList() end },
            { text = "Best DPM", value = "DPM", onSelect = function() s.criteria = "DPM"; UI:RefreshList() end },
            { text = "Best HPM", value = "HPM", onSelect = function() s.criteria = "HPM"; UI:RefreshList() end },
        })
        UIDropDownMenu_SetText(UI.right.ddCrit, critLabel(s.criteria))
    end

    if UI.right.btnName then
        local label = s.name or "Select Spell"
        if s.disabled then label = label .. " (Off)" end
        UI.right.btnName:SetText(label)
    end

    if UI.right.note then
        UI.right.note._lock = true
        UI.right.note:SetText(s.note or "")
        UI.right.note._lock = nil
        UI.right.note:SetScript("OnTextChanged", function(self)
            if self._lock then return end
            s.note = self:GetText()
            UI:RefreshList()
        end)
    end
end

function UI:RefreshPicker(skipBuild)
    if not UI.pickerScroll then return end
    if not NS.Book or not next(NS.Book) then
        if not skipBuild and NS.Data and NS.Data.BuildBook then NS.Data:BuildBook() end
        if not NS.Book or not next(NS.Book) then return end
    end

    UI.pickerList = {}
    local seen = {}
    for _, d in pairs(NS.Book) do
        if d and (d.type == "SPELL" or d.type == "MACRO") and type(d.name) == "string" and not d.name:find("_") then
            local key = (d.type or "") .. ":" .. d.name
            if not seen[key] then
                seen[key] = true
                table.insert(UI.pickerList, d)
            end
        end
    end
    table.sort(UI.pickerList, function(a, b) return a.name < b.name end)

    local off = FauxScrollFrame_GetOffset(UI.pickerScroll) or 0
    for i, row in ipairs(UI.pRows) do
        local idx = off + i
        if idx <= #UI.pickerList then
            local d = UI.pickerList[idx]
            row.dataName = d.name
            local color = "|cffffffff"
            if d.type == "ITEM" then color = "|cff00ff00" elseif d.type == "MACRO" then color = "|cffffa500" end
            row.txt:SetText(color .. "|T" .. (d.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":14|t " .. d.name .. "|r")
            row.meta:SetText(d.type == "MACRO" and "Macro" or ("Slot " .. (d.slot or 0)))
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(UI.pickerScroll, #UI.pickerList, 16, 22)
end

function UI:RefreshConds()
    if not UI.selIdx then return end
    local s = NS.db.steps[UI.selIdx]
    local list = s.conditions or {}
    local offset = FauxScrollFrame_GetOffset(UI.condScroll) or 0

    for i, r in ipairs(UI.right.cRows) do
        local idx = offset + i
        if idx <= #list then
            local c = list[idx]
            r:Show()
            r.cIdx = idx

            local txt = c.type or "?"
            if c.type == "RESOURCE" then
                local mode = c.mode == "percent" and "%" or (c.mode == "deficit" and "Def" or "Val")
                txt = string.format("%s %s %s %s", c.unit or "player", c.resType or "HEALTH", c.op or "<", c.val or "?") .. " (" .. mode .. ")"
            elseif c.type == "AURA" then
                txt = string.format("Aura %s on %s", c.auraName or "?", c.unit or "target")
            elseif c.type == "SPELL" then
                local spellName = c.spellCondName or "AUTO"
                local checks = {}
                if c.chkMana then table.insert(checks, "Mana") end
                if c.chkRange then table.insert(checks, "Rng:" .. (c.rangeUnit or "tgt")) end
                if c.chkRemain then table.insert(checks, "CD" .. (c.remOp or "") .. (c.remVal or "")) end
                if c.chkCharges then table.insert(checks, "Chg" .. (c.chargesOp or "") .. (c.chargesVal or "")) end
                local checkStr = #checks > 0 and (" [" .. table.concat(checks, ",") .. "]") or ""
                txt = string.format("SPELL:%s%s", spellName, checkStr)
            elseif c.type == "PLAYER" then
                txt = "PLAYER:"
                local checks = {}
                if c.inCombat then table.insert(checks, "InCombat") end
                if c.outCombat then table.insert(checks, "OutCombat") end
                if c.mounted then table.insert(checks, "Mounted") end
                if c.notMounted then table.insert(checks, "NotMounted") end
                if c.moving then table.insert(checks, "Moving") end
                if c.notMoving then table.insert(checks, "NotMoving") end
                if c.groupType and c.groupType ~= "any" then table.insert(checks, c.groupType) end
                if c.checkForm then table.insert(checks, c.formType or "Form") end
                if #checks > 0 then
                    txt = txt .. " " .. table.concat(checks, ", ")
                else
                    txt = txt .. " No conditions"
                end
            elseif c.type == "UNIT" or c.type == "UNIT_TARGET" or c.type == "TARGET" then
                local unit = c.targetUnit or c.unit or "target"
                local checks = {}
                if c.friendly then table.insert(checks, "Friendly") end
                if c.hostile then table.insert(checks, "Hostile") end
                if c.notDead then table.insert(checks, "Alive") end
                if c.isDead then table.insert(checks, "Dead") end
                if c.attackable then table.insert(checks, "Attackable") end
                if c.casting then table.insert(checks, "Casting") end
                if c.checkRange then table.insert(checks, "Rng" .. (c.rangeVal or "")) end
                local checkStr = #checks > 0 and (" [" .. table.concat(checks, ",") .. "]") or ""
                txt = string.format("UNIT:%s%s", unit, checkStr)
            end

            r.txt:SetText(txt)
            r.val:SetText(c.lastVal or "")
            r.stat:SetColorTexture(c.lastPass and 0 or 1, c.lastPass and 1 or 0, 0, 1)

            if UI.curCondIdx == idx then r:SetBackdropColor(0.25, 0.25, 0.25, 1) else r:SetBackdropColor(0.18, 0.18, 0.18, 1) end
        else
            r:Hide()
        end
    end

    FauxScrollFrame_Update(UI.condScroll, #list, #UI.right.cRows, ROW_H_COND)
end

function UI:CreateEditor(parent)
    local ceContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ceContainer:SetPoint("TOPLEFT", 10, -320)
    ceContainer:SetPoint("BOTTOMRIGHT", -10, 8)
    ceContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    ceContainer:SetBackdropColor(0.08, 0.08, 0.08, 1)
    ceContainer:SetBackdropBorderColor(0, 0, 0, 1)

    local scroll = CreateFrame("ScrollFrame", "JR_EditorScroll", ceContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local ce = CreateFrame("Frame", nil, scroll, "BackdropTemplate")
    ce:SetSize(1, 1)
    scroll:SetScrollChild(ce)

    parent.editor = ce
    ceContainer:Hide()
    parent.editorContainer = ceContainer

    ce.title = ce:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ce.title:SetPoint("TOPLEFT", 10, -8)
    ce.title:SetText("Condition Editor")

    ce.debugTxt = ce:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.debugTxt:SetPoint("TOPRIGHT", -10, -10)
    ce.debugTxt:SetText("Last: --")

    ce.ddType = newDropdown(ce, 160, "Condition Type")
    ce.ddType:SetPoint("TOPLEFT", 10, -32)

    ce.trueChk = newCheck(ce, "True")
    ce.trueChk:SetPoint("LEFT", ce.ddType, "RIGHT", 100, 0)

    -- Resource group
    ce.grpRes = CreateFrame("Frame", nil, ce)
    ce.grpRes:SetAllPoints()
    
    -- Unit dropdown
    ce.grpRes.unit = newDropdown(ce.grpRes, 100, "Unit")
    ce.grpRes.unit:SetPoint("TOPLEFT", 10, -60)
    
    -- Resource type dropdown  
    ce.grpRes.resType = newDropdown(ce.grpRes, 100, "Resource")
    ce.grpRes.resType:SetPoint("TOPLEFT", 130, -60)
    
    -- Format dropdown (Raw/Percent/Deficit)
    ce.grpRes.mode = newDropdown(ce.grpRes, 80, "Format")
    ce.grpRes.mode:SetPoint("TOPLEFT", 10, -120)
    
    -- Operator dropdown
    ce.grpRes.op = newDropdown(ce.grpRes, 60, "Op")
    ce.grpRes.op:SetPoint("TOPLEFT", 110, -120)
    
    -- Value input with label
    local valLbl = ce.grpRes:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valLbl:SetPoint("TOPLEFT", 190, -105)
    valLbl:SetText("Value:")
    ce.grpRes.val = newEditBox(ce.grpRes, 80)
    ce.grpRes.val:SetPoint("TOPLEFT", 190, -122)
    ce.grpRes.val:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ce.grpRes.val:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    
    -- Include incoming heals checkbox
    ce.grpRes.inc = newCheck(ce.grpRes, "Include Incoming Heals")
    ce.grpRes.inc:SetPoint("TOPLEFT", 10, -160)
    
    -- Debug display for current resource values
    ce.grpRes.debugLbl = ce.grpRes:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.grpRes.debugLbl:SetPoint("TOPLEFT", 10, -190)
    ce.grpRes.debugLbl:SetText("Debug: Current/Max/Calculated = --/--/--")
    
    -- Second debug line for condition values
    ce.grpRes.debugLbl2 = ce.grpRes:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.grpRes.debugLbl2:SetPoint("TOPLEFT", 10, -210)
    ce.grpRes.debugLbl2:SetText("Config: unit/resType/mode/op/val = --/--/--/--/--")
    ce.grpRes.debugLbl = ce.grpRes:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.grpRes.debugLbl:SetPoint("TOPLEFT", 10, -170)
    ce.grpRes.debugLbl:SetText("Debug: Current/Max/Calculated = --/--/--")

    -- Aura group
    ce.grpAura = CreateFrame("Frame", nil, ce)
    ce.grpAura:SetAllPoints()
    
    -- Unit dropdown
    ce.grpAura.unit = newDropdown(ce.grpAura, 120, "Unit")
    ce.grpAura.unit:SetPoint("TOPLEFT", 10, -50)
    
    -- Aura name input
    local nameLbl = ce.grpAura:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", 10, -85)
    nameLbl:SetText("Aura Name or ID")
    ce.grpAura.name = newEditBox(ce.grpAura, 220)
    ce.grpAura.name:SetPoint("TOPLEFT", 10, -105)
    
    -- Checkboxes row 1
    ce.grpAura.mine = newCheck(ce.grpAura, "Cast by me")
    ce.grpAura.mine:SetPoint("TOPLEFT", 10, -135)
    ce.grpAura.debuff = newCheck(ce.grpAura, "Is Debuff")
    ce.grpAura.debuff:SetPoint("TOPLEFT", 120, -135)
    ce.grpAura.stealable = newCheck(ce.grpAura, "Is Stealable")
    ce.grpAura.stealable:SetPoint("TOPLEFT", 220, -135)
    
    -- Status type checking (move to new row)
    ce.grpAura.statusChk = newCheck(ce.grpAura, "Status Type")
    ce.grpAura.statusChk:SetPoint("TOPLEFT", 10, -160)
    
    -- Multi-select status checkboxes (arranged in 2 columns for better spacing)
    ce.grpAura.statusTypes = {}
    local statusList = {"Slowed", "Stunned", "Feared", "Charmed", "Rooted", "Silenced", "Bleeding", "Poisoned", "Incapacitated"}
    for i, status in ipairs(statusList) do
        local chk = newCheck(ce.grpAura, status)
        local row = math.floor((i-1) / 2)  -- 2 per row
        local col = (i-1) % 2
        chk:SetPoint("TOPLEFT", 30 + col * 150, -180 - row * 35)  -- Much wider: 150px horizontal, 35px vertical
        chk:SetScale(0.75)  -- Slightly larger for readability
        ce.grpAura.statusTypes[status] = chk
    end
    
    -- Stack checking row (adjusted for new layout)
    ce.grpAura.stackChk = newCheck(ce.grpAura, "Stack Count")
    ce.grpAura.stackChk:SetPoint("TOPLEFT", 10, -300)
    ce.grpAura.stackOp = newDropdown(ce.grpAura, 60, "")
    ce.grpAura.stackOp:SetPoint("TOPLEFT", 115, -310)
    ce.grpAura.stackVal = newEditBox(ce.grpAura, 50)
    ce.grpAura.stackVal:SetPoint("TOPLEFT", 185, -312)
    
    -- Time checking row (adjusted for new layout)
    ce.grpAura.timeChk = newCheck(ce.grpAura, "Remaining Time")
    ce.grpAura.timeChk:SetPoint("TOPLEFT", 10, -340)
    ce.grpAura.timeOp = newDropdown(ce.grpAura, 60, "")
    ce.grpAura.timeOp:SetPoint("TOPLEFT", 135, -350)
    ce.grpAura.timeVal = newEditBox(ce.grpAura, 50)
    ce.grpAura.timeVal:SetPoint("TOPLEFT", 205, -352)
    
    -- Debug display for aura detection (moved up to be more visible)
    ce.grpAura.debugLbl = ce.grpAura:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.grpAura.debugLbl:SetPoint("TOPLEFT", 10, -270)
    ce.grpAura.debugLbl:SetText("Debug: Aura search results")
    ce.grpAura.debugLbl:SetJustifyH("LEFT")
    ce.grpAura.debugLbl:SetWidth(450)

    -- Spell group
    ce.grpSpell = CreateFrame("Frame", nil, ce)
    ce.grpSpell:SetAllPoints()
    local splLbl = ce.grpSpell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    splLbl:SetPoint("TOPLEFT", 10, -70)
    splLbl:SetText("Select Spell")
    ce.grpSpell.ddSpell = newDropdown(ce.grpSpell, 220)
    ce.grpSpell.ddSpell:SetPoint("TOPLEFT", splLbl, "BOTTOMLEFT", -15, -2)

    -- Cooldown/Charges checks
    ce.grpSpell.remChk = newCheck(ce.grpSpell, "RemTime")
    ce.grpSpell.remChk:SetPoint("TOPLEFT", ce.grpSpell.ddSpell, "BOTTOMLEFT", 15, -10)
    ce.grpSpell.remOp = newDropdown(ce.grpSpell, 70, "Op")
    ce.grpSpell.remOp:ClearAllPoints()
    ce.grpSpell.remOp:SetPoint("LEFT", ce.grpSpell.remChk, "RIGHT", 10, 0)
    ce.grpSpell.remVal = newEditBox(ce.grpSpell, 60)
    ce.grpSpell.remVal:ClearAllPoints()
    ce.grpSpell.remVal:SetPoint("LEFT", ce.grpSpell.remOp, "RIGHT", 8, 0)

    ce.grpSpell.chgChk = newCheck(ce.grpSpell, "Charges")
    ce.grpSpell.chgChk:SetPoint("TOPLEFT", ce.grpSpell.remChk, "BOTTOMLEFT", 0, -8)
    ce.grpSpell.chgOp = newDropdown(ce.grpSpell, 70, "Op")
    ce.grpSpell.chgOp:ClearAllPoints()
    ce.grpSpell.chgOp:SetPoint("LEFT", ce.grpSpell.chgChk, "RIGHT", 10, 0)
    ce.grpSpell.chgVal = newEditBox(ce.grpSpell, 60)
    ce.grpSpell.chgVal:ClearAllPoints()
    ce.grpSpell.chgVal:SetPoint("LEFT", ce.grpSpell.chgOp, "RIGHT", 8, 0)

    -- Resource checks
    ce.grpSpell.manaChk = newCheck(ce.grpSpell, "Check Mana")
    ce.grpSpell.manaChk:SetPoint("TOPLEFT", ce.grpSpell.chgChk, "BOTTOMLEFT", 0, -12)

    -- Range check with unit selector
    ce.grpSpell.rangeChk = newCheck(ce.grpSpell, "Check Range")
    ce.grpSpell.rangeChk:SetPoint("TOPLEFT", ce.grpSpell.manaChk, "BOTTOMLEFT", 0, -8)
    ce.grpSpell.rangeUnit = newDropdown(ce.grpSpell, 140, "Range Unit")
    ce.grpSpell.rangeUnit:ClearAllPoints()
    ce.grpSpell.rangeUnit:SetPoint("LEFT", ce.grpSpell.rangeChk, "RIGHT", 18, 0)

    -- Info/debug line - now shows more detailed info including actual spell range
    ce.grpSpell.info = ce.grpSpell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.grpSpell.info:SetPoint("TOPLEFT", ce.grpSpell.rangeChk, "BOTTOMLEFT", 0, -8)
    ce.grpSpell.info:SetWidth(450)
    ce.grpSpell.info:SetJustifyH("LEFT")
    ce.grpSpell.info:SetText("--")

    -- Player/Unit group
    ce.grpUnit = CreateFrame("Frame", nil, ce)
    ce.grpUnit:SetAllPoints()
    
    -- Combat checkboxes (on same line for compactness)
    ce.grpUnit.inCombat = newCheck(ce.grpUnit, "In Combat")
    ce.grpUnit.inCombat:SetPoint("TOPLEFT", 10, -60)
    ce.grpUnit.outCombat = newCheck(ce.grpUnit, "Out of Combat")
    ce.grpUnit.outCombat:SetPoint("TOPLEFT", 120, -60)
    
    -- Mounted checkboxes
    ce.grpUnit.mounted = newCheck(ce.grpUnit, "Mounted")
    ce.grpUnit.mounted:SetPoint("TOPLEFT", 10, -85)
    ce.grpUnit.notMounted = newCheck(ce.grpUnit, "Not Mounted")
    ce.grpUnit.notMounted:SetPoint("TOPLEFT", 120, -85)
    
    -- Moving checkboxes
    ce.grpUnit.moving = newCheck(ce.grpUnit, "Moving")
    ce.grpUnit.moving:SetPoint("TOPLEFT", 10, -110)
    ce.grpUnit.notMoving = newCheck(ce.grpUnit, "Not Moving")
    ce.grpUnit.notMoving:SetPoint("TOPLEFT", 120, -110)
    
    -- Group type dropdown (with more spacing)
    ce.grpUnit.groupType = newDropdown(ce.grpUnit, 100, "Group Type")
    ce.grpUnit.groupType:SetPoint("TOPLEFT", 10, -145)
    
    -- Form checkbox and dropdown
    ce.grpUnit.checkForm = newCheck(ce.grpUnit, "Check Form")
    ce.grpUnit.checkForm:SetPoint("TOPLEFT", 10, -200)
    ce.grpUnit.formType = newDropdown(ce.grpUnit, 120, "Form")
    ce.grpUnit.formType:SetPoint("TOPLEFT", 120, -210)
    
    -- Role checkbox and dropdown
    ce.grpUnit.checkRole = newCheck(ce.grpUnit, "Check Role")
    ce.grpUnit.checkRole:SetPoint("TOPLEFT", 10, -240)
    ce.grpUnit.roleType = newDropdown(ce.grpUnit, 120, "Role")
    ce.grpUnit.roleType:SetPoint("TOPLEFT", 120, -250)

    -- Unit Target Conditions group (separate from Player conditions)
    ce.grpUnitTarget = CreateFrame("Frame", nil, ce)
    ce.grpUnitTarget:SetAllPoints()
    
    -- Unit selector
    ce.grpUnitTarget.unitSelect = newDropdown(ce.grpUnitTarget, 120, "Unit")
    ce.grpUnitTarget.unitSelect:SetPoint("TOPLEFT", 10, -60)
    
    -- Raid marker checkbox and dropdown
    ce.grpUnitTarget.raidMarkChk = newCheck(ce.grpUnitTarget, "Raid Mark")
    ce.grpUnitTarget.raidMarkChk:SetPoint("TOPLEFT", 140, -60)
    ce.grpUnitTarget.raidMarkType = newDropdown(ce.grpUnitTarget, 100, "Mark")
    ce.grpUnitTarget.raidMarkType:SetPoint("TOPLEFT", 240, -70)
    
    -- Death state checkboxes (mutually exclusive)
    ce.grpUnitTarget.isDead = newCheck(ce.grpUnitTarget, "Is Dead")
    ce.grpUnitTarget.isDead:SetPoint("TOPLEFT", 10, -100)
    ce.grpUnitTarget.notDead = newCheck(ce.grpUnitTarget, "Not Dead")
    ce.grpUnitTarget.notDead:SetPoint("TOPLEFT", 120, -100)
    
    -- Hostility checkboxes (mutually exclusive)
    ce.grpUnitTarget.friendly = newCheck(ce.grpUnitTarget, "Friendly")
    ce.grpUnitTarget.friendly:SetPoint("TOPLEFT", 10, -130)
    ce.grpUnitTarget.hostile = newCheck(ce.grpUnitTarget, "Hostile")
    ce.grpUnitTarget.hostile:SetPoint("TOPLEFT", 120, -130)
    
    -- Player/NPC checkboxes (mutually exclusive)
    ce.grpUnitTarget.isPlayer = newCheck(ce.grpUnitTarget, "Is Player")
    ce.grpUnitTarget.isPlayer:SetPoint("TOPLEFT", 10, -160)
    ce.grpUnitTarget.nonPlayer = newCheck(ce.grpUnitTarget, "Non-Player")
    ce.grpUnitTarget.nonPlayer:SetPoint("TOPLEFT", 120, -160)
    
    -- Attackable and Casting checkboxes
    ce.grpUnitTarget.attackable = newCheck(ce.grpUnitTarget, "Attackable")
    ce.grpUnitTarget.attackable:SetPoint("TOPLEFT", 10, -190)
    ce.grpUnitTarget.casting = newCheck(ce.grpUnitTarget, "Casting")
    ce.grpUnitTarget.casting:SetPoint("TOPLEFT", 120, -190)
    
    -- Range check
    ce.grpUnitTarget.rangeChk = newCheck(ce.grpUnitTarget, "Range Check")
    ce.grpUnitTarget.rangeChk:SetPoint("TOPLEFT", 10, -220)
    ce.grpUnitTarget.rangeVal = newDropdown(ce.grpUnitTarget, 80, "Range")
    ce.grpUnitTarget.rangeVal:SetPoint("TOPLEFT", 120, -230)
    
    -- Class check
    ce.grpUnitTarget.classChk = newCheck(ce.grpUnitTarget, "Check Class")
    ce.grpUnitTarget.classChk:SetPoint("TOPLEFT", 10, -250)
    ce.grpUnitTarget.classType = newDropdown(ce.grpUnitTarget, 120, "Class")
    ce.grpUnitTarget.classType:SetPoint("TOPLEFT", 120, -260)
    
    -- Unit type multiselect
    ce.grpUnitTarget.unitTypeChk = newCheck(ce.grpUnitTarget, "Unit Type")
    ce.grpUnitTarget.unitTypeChk:SetPoint("TOPLEFT", 10, -290)
    ce.grpUnitTarget.unitTypeList = newDropdown(ce.grpUnitTarget, 120, "Type")
    ce.grpUnitTarget.unitTypeList:SetPoint("TOPLEFT", 120, -300)
    
    -- Debug label
    ce.grpUnitTarget.debugLbl = ce.grpUnitTarget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ce.grpUnitTarget.debugLbl:SetPoint("TOPLEFT", 10, -330)
    ce.grpUnitTarget.debugLbl:SetText("Debug: No unit selected")
    ce.grpUnitTarget.debugLbl:SetJustifyH("LEFT")
    ce.grpUnitTarget.debugLbl:SetWidth(400)

    ce.btnDelete = CreateFrame("Frame", nil, ce)
end

function UI:EditCondition(idx)
    if not UI.selIdx then return end
    local s = NS.db.steps[UI.selIdx]
    if not s or not s.conditions[idx] then return end
    UI.curCondIdx = idx
    local c = s.conditions[idx]
    local ce = UI.right.editor
    UI.right.editorContainer:Show()
    ce:Show()
    ce.title:SetText("Condition #" .. idx)
    UI:UpdateCondDebug()

    local function toggleGroup(which)
        ce.grpRes:Hide(); ce.grpAura:Hide(); ce.grpSpell:Hide(); ce.grpUnit:Hide(); ce.grpUnitTarget:Hide()
        if which then which:Show() end
    end

    setDropdownOptions(ce.ddType, c.type or "RESOURCE", {
        { text = "RESOURCE", value = "RESOURCE", onSelect = function() c.type = "RESOURCE"; UI:EditCondition(idx) end },
        { text = "AURA", value = "AURA", onSelect = function() c.type = "AURA"; UI:EditCondition(idx) end },
        { text = "SPELL", value = "SPELL", onSelect = function() c.type = "SPELL"; UI:EditCondition(idx) end },
        { text = "PLAYER", value = "PLAYER", onSelect = function() c.type = "PLAYER"; UI:EditCondition(idx) end },
        { text = "UNIT", value = "UNIT", onSelect = function() c.type = "UNIT"; UI:EditCondition(idx) end },
    })

    ce.trueChk:SetChecked(c.trueFlag ~= false)
    ce.trueChk:SetScript("OnClick", function()
        c.trueFlag = ce.trueChk:GetChecked()
    end)

    local function opOptions()
        return {
            { text = "<=", value = "<=" },
            { text = "<", value = "<" },
            { text = ">=", value = ">=" },
            { text = ">", value = ">" },
            { text = "==", value = "==" },
        }
    end

    local function refreshSpellToggles()
        if not ce.grpSpell then return end
        local remOn = ce.grpSpell.remChk:GetChecked()
        ce.grpSpell.remOp:SetShown(remOn)
        ce.grpSpell.remVal:SetShown(remOn)

        local chgOn = ce.grpSpell.chgChk:GetChecked()
        ce.grpSpell.chgOp:SetShown(chgOn)
        ce.grpSpell.chgVal:SetShown(chgOn)
    end

    if c.type == "SPELL" then
        toggleGroup(ce.grpSpell)

        c.remOp = c.remOp or "<="
        c.remVal = c.remVal or 0
        c.chargesOp = c.chargesOp or "<="
        c.chargesVal = c.chargesVal or 0
        c.rangeUnit = c.rangeUnit or "target"
        c.chkRemain = c.chkRemain or false
        c.chkCharges = c.chkCharges or false
        c.chkMana = c.chkMana or false
        c.chkRange = c.chkRange or false

        -- Spell dropdown (unique spell names only)
        local items = { { text = "AUTO (action spell)", value = "AUTO", onSelect = function(val) c.spellCondName = val end } }
        local seen = {}
        for _, d in pairs(NS.Book or {}) do
            if d and d.type == "SPELL" and d.name and not d.name:find("_") and not seen[d.name] then
                seen[d.name] = true
                table.insert(items, { text = d.name, value = d.name, onSelect = function(val) c.spellCondName = val end })
            end
        end
        table.sort(items, function(a, b) return a.text < b.text end)
        setDropdownOptions(ce.grpSpell.ddSpell, c.spellCondName or "AUTO", items)

        ce.grpSpell.remChk:SetChecked(c.chkRemain)
        ce.grpSpell.remChk:SetScript("OnClick", function()
            c.chkRemain = ce.grpSpell.remChk:GetChecked()
            refreshSpellToggles()
        end)
        local remItems = {}
        for _, opt in ipairs(opOptions()) do
            table.insert(remItems, { text = opt.text, value = opt.value, onSelect = function(val) c.remOp = val end })
        end
        setDropdownOptions(ce.grpSpell.remOp, c.remOp or "<=", remItems)
        ce.grpSpell.remVal:SetText(tostring(c.remVal or 0))
        ce.grpSpell.remVal:SetScript("OnTextChanged", function(self)
            c.remVal = tonumber(self:GetText()) or 0
        end)

        ce.grpSpell.chgChk:SetChecked(c.chkCharges)
        ce.grpSpell.chgChk:SetScript("OnClick", function()
            c.chkCharges = ce.grpSpell.chgChk:GetChecked()
            refreshSpellToggles()
        end)
        local chgItems = {}
        for _, opt in ipairs(opOptions()) do
            table.insert(chgItems, { text = opt.text, value = opt.value, onSelect = function(val) c.chargesOp = val end })
        end
        setDropdownOptions(ce.grpSpell.chgOp, c.chargesOp or "<=", chgItems)
        ce.grpSpell.chgVal:SetText(tostring(c.chargesVal or 0))
        ce.grpSpell.chgVal:SetScript("OnTextChanged", function(self)
            c.chargesVal = tonumber(self:GetText()) or 0
        end)

        ce.grpSpell.manaChk:SetChecked(c.chkMana)
        ce.grpSpell.manaChk:SetScript("OnClick", function() c.chkMana = ce.grpSpell.manaChk:GetChecked() end)

        ce.grpSpell.rangeChk:SetChecked(c.chkRange)
        ce.grpSpell.rangeChk:SetScript("OnClick", function() c.chkRange = ce.grpSpell.rangeChk:GetChecked() end)
        setDropdownOptions(ce.grpSpell.rangeUnit, c.rangeUnit or "target", {
            { text = "target", value = "target", onSelect = function(val) c.rangeUnit = val end },
            { text = "focus", value = "focus", onSelect = function(val) c.rangeUnit = val end },
            { text = "player", value = "player", onSelect = function(val) c.rangeUnit = val end },
            { text = "mouseover", value = "mouseover", onSelect = function(val) c.rangeUnit = val end },
        })

        -- Info/debug line
        local spellName = (not c.spellCondName or c.spellCondName == "AUTO") and (s and s.name) or c.spellCondName
        local infoTxt = spellName or "--"
        if spellName and NS.Book and NS.Book[spellName] then
            local d = NS.Book[spellName]
            local start, duration = 0, 0
            if d.slot and d.slot > 0 then
                start, duration = GetActionCooldown(d.slot)
            else
                start, duration = GetSpellCooldown(d.id or d.name)
            end
            local cd = 0
            if duration and duration > 1.5 then cd = (start + duration) - GetTime() end
            if cd < 0 then cd = 0 end
            local chg = d.id and (select(1, GetSpellCharges(d.id)) or 0) or "-"
            
            -- Get spell range if available (from spell book data, not GetSpellRange which doesn't exist in Classic)
            local rangeInfo = ""
            if d.range and d.range > 0 then
                rangeInfo = string.format("  Range:%d", d.range)
            end
            
            infoTxt = string.format("%s  CD:%.1f  Chg:%s%s", spellName, cd, chg, rangeInfo)
        end
        ce.grpSpell.info:SetText(infoTxt)

        refreshSpellToggles()
        
    elseif c.type == "AURA" then
        toggleGroup(ce.grpAura)
        
        -- Initialize defaults
        c.unit = c.unit or "target"
        c.auraName = c.auraName or ""
        c.isDebuff = c.isDebuff ~= false  -- default to true (debuff)
        c.checkStack = c.checkStack or false
        c.stackOp = c.stackOp or ">="
        c.stackVal = c.stackVal or 1
        c.checkTime = c.checkTime or false
        c.timeOp = c.timeOp or "<="
        c.timeVal = c.timeVal or 0
        c.isStealable = c.isStealable or false
        c.checkStatus = c.checkStatus or false
        c.statusTypes = c.statusTypes or {}  -- Changed to array for multi-select
        c.ownOnly = c.ownOnly or false
        
        -- Unit dropdown
        setDropdownOptions(ce.grpAura.unit, c.unit, {
            { text = "player", value = "player", onSelect = function(val) c.unit = val; UI:UpdateAuraDebug(c) end },
            { text = "target", value = "target", onSelect = function(val) c.unit = val; UI:UpdateAuraDebug(c) end },
            { text = "focus", value = "focus", onSelect = function(val) c.unit = val; UI:UpdateAuraDebug(c) end },
            { text = "pet", value = "pet", onSelect = function(val) c.unit = val; UI:UpdateAuraDebug(c) end },
        })
        
        -- Aura name
        ce.grpAura.name:SetText(c.auraName or "")
        ce.grpAura.name:SetScript("OnTextChanged", function(self)
            c.auraName = self:GetText()
            UI:UpdateAuraDebug(c)
        end)
        
        -- Debuff checkbox
        ce.grpAura.debuff:SetChecked(c.isDebuff)
        ce.grpAura.debuff:SetScript("OnClick", function()
            c.isDebuff = ce.grpAura.debuff:GetChecked()
            UI:UpdateAuraDebug(c)
        end)
        
        -- Cast by me checkbox
        ce.grpAura.mine:SetChecked(c.ownOnly)
        ce.grpAura.mine:SetScript("OnClick", function()
            c.ownOnly = ce.grpAura.mine:GetChecked()
            UI:UpdateAuraDebug(c)
        end)
        
        -- Stack checking
        ce.grpAura.stackChk:SetChecked(c.checkStack)
        ce.grpAura.stackChk:SetScript("OnClick", function()
            c.checkStack = ce.grpAura.stackChk:GetChecked()
            -- Show/hide stack controls
            ce.grpAura.stackOp:SetShown(c.checkStack)
            ce.grpAura.stackVal:SetShown(c.checkStack)
        end)
        
        setDropdownOptions(ce.grpAura.stackOp, c.stackOp, {
            { text = "<", value = "<", onSelect = function(val) c.stackOp = val end },
            { text = ">", value = ">", onSelect = function(val) c.stackOp = val end },
            { text = "<=", value = "<=", onSelect = function(val) c.stackOp = val end },
            { text = ">=", value = ">=", onSelect = function(val) c.stackOp = val end },
            { text = "==", value = "==", onSelect = function(val) c.stackOp = val end },
        })
        
        ce.grpAura.stackVal:SetText(tostring(c.stackVal or 1))
        ce.grpAura.stackVal:SetScript("OnTextChanged", function(self)
            c.stackVal = tonumber(self:GetText()) or 1
        end)
        
        -- Show/hide stack controls based on checkbox
        ce.grpAura.stackOp:SetShown(c.checkStack)
        ce.grpAura.stackVal:SetShown(c.checkStack)
        
        -- Time checking
        ce.grpAura.timeChk:SetChecked(c.checkTime)
        ce.grpAura.timeChk:SetScript("OnClick", function()
            c.checkTime = ce.grpAura.timeChk:GetChecked()
            -- Show/hide time controls
            ce.grpAura.timeOp:SetShown(c.checkTime)
            ce.grpAura.timeVal:SetShown(c.checkTime)
        end)
        
        setDropdownOptions(ce.grpAura.timeOp, c.timeOp, {
            { text = "<", value = "<", onSelect = function(val) c.timeOp = val end },
            { text = ">", value = ">", onSelect = function(val) c.timeOp = val end },
            { text = "<=", value = "<=", onSelect = function(val) c.timeOp = val end },
            { text = ">=", value = ">=", onSelect = function(val) c.timeOp = val end },
        })
        
        ce.grpAura.timeVal:SetText(tostring(c.timeVal or 0))
        ce.grpAura.timeVal:SetScript("OnTextChanged", function(self)
            c.timeVal = tonumber(self:GetText()) or 0
        end)
        
        -- Show/hide time controls based on checkbox
        ce.grpAura.timeOp:SetShown(c.checkTime)
        ce.grpAura.timeVal:SetShown(c.checkTime)
        
        -- Stealable checkbox
        ce.grpAura.stealable:SetChecked(c.isStealable)
        ce.grpAura.stealable:SetScript("OnClick", function()
            c.isStealable = ce.grpAura.stealable:GetChecked()
        end)
        
        -- Status type checkbox and multi-select
        ce.grpAura.statusChk:SetChecked(c.checkStatus)
        ce.grpAura.statusChk:SetScript("OnClick", function()
            c.checkStatus = ce.grpAura.statusChk:GetChecked()
            -- Show/hide all status checkboxes
            for status, chk in pairs(ce.grpAura.statusTypes) do
                chk:SetShown(c.checkStatus)
            end
        end)
        
        -- Configure individual status checkboxes
        for status, chk in pairs(ce.grpAura.statusTypes) do
            local isSelected = false
            for _, selectedStatus in ipairs(c.statusTypes) do
                if selectedStatus == status then
                    isSelected = true
                    break
                end
            end
            chk:SetChecked(isSelected)
            chk:SetScript("OnClick", function()
                if chk:GetChecked() then
                    -- Add to list if not already there
                    local found = false
                    for _, s in ipairs(c.statusTypes) do
                        if s == status then found = true; break end
                    end
                    if not found then table.insert(c.statusTypes, status) end
                else
                    -- Remove from list
                    for i = #c.statusTypes, 1, -1 do
                        if c.statusTypes[i] == status then
                            table.remove(c.statusTypes, i)
                            break
                        end
                    end
                end
            end)
            chk:SetShown(c.checkStatus)
        end
        
        -- Update debug display
        UI:UpdateAuraDebug(c)
        
    elseif c.type == "RESOURCE" then
        toggleGroup(ce.grpRes)
        
        -- Initialize defaults
        c.unit = c.unit or "player"
        c.resType = c.resType or "HEALTH"
        c.mode = c.mode or "percent"
        c.op = c.op or "<"
        c.val = c.val or 100
        c.incHeal = c.incHeal or false
        
        -- Unit dropdown
        setDropdownOptions(ce.grpRes.unit, c.unit, {
            { text = "player", value = "player", onSelect = function(val) c.unit = val; UI:UpdateResourceDebug(c) end },
            { text = "target", value = "target", onSelect = function(val) c.unit = val; UI:UpdateResourceDebug(c) end },
            { text = "focus", value = "focus", onSelect = function(val) c.unit = val; UI:UpdateResourceDebug(c) end },
            { text = "pet", value = "pet", onSelect = function(val) c.unit = val; UI:UpdateResourceDebug(c) end },
        })
        
        -- Resource type dropdown
        setDropdownOptions(ce.grpRes.resType, c.resType, {
            { text = "HEALTH", value = "HEALTH", onSelect = function(val) 
                c.resType = val 
                -- Show/hide incoming heals based on resource type
                if val == "HEALTH" then
                    ce.grpRes.inc:Show()
                else
                    ce.grpRes.inc:Hide()
                    c.incHeal = false
                    ce.grpRes.inc:SetChecked(false)
                end
                UI:UpdateResourceDebug(c)
            end },
            { text = "MANA", value = "MANA", onSelect = function(val) 
                c.resType = val 
                ce.grpRes.inc:Hide()
                c.incHeal = false
                ce.grpRes.inc:SetChecked(false)
                UI:UpdateResourceDebug(c)
            end },
            { text = "RAGE", value = "RAGE", onSelect = function(val) 
                c.resType = val 
                ce.grpRes.inc:Hide()
                c.incHeal = false
                ce.grpRes.inc:SetChecked(false)
                UI:UpdateResourceDebug(c)
            end },
            { text = "ENERGY", value = "ENERGY", onSelect = function(val) 
                c.resType = val 
                ce.grpRes.inc:Hide()
                c.incHeal = false
                ce.grpRes.inc:SetChecked(false)
                UI:UpdateResourceDebug(c)
            end },
            { text = "COMBO", value = "COMBO", onSelect = function(val) 
                c.resType = val 
                ce.grpRes.inc:Hide()
                c.incHeal = false
                ce.grpRes.inc:SetChecked(false)
                UI:UpdateResourceDebug(c)
            end },
        })
        
        -- Mode dropdown (Raw/Percent/Deficit)
        setDropdownOptions(ce.grpRes.mode, c.mode, {
            { text = "Raw", value = "raw", onSelect = function(val) c.mode = val; UI:UpdateResourceDebug(c) end },
            { text = "Percent", value = "percent", onSelect = function(val) c.mode = val; UI:UpdateResourceDebug(c) end },
            { text = "Deficit", value = "deficit", onSelect = function(val) c.mode = val; UI:UpdateResourceDebug(c) end },
        })
        
        -- Operator dropdown
        setDropdownOptions(ce.grpRes.op, c.op, {
            { text = "<", value = "<", onSelect = function(val) c.op = val; UI:UpdateResourceDebug(c) end },
            { text = ">", value = ">", onSelect = function(val) c.op = val; UI:UpdateResourceDebug(c) end },
            { text = "<=", value = "<=", onSelect = function(val) c.op = val; UI:UpdateResourceDebug(c) end },
            { text = ">=", value = ">=", onSelect = function(val) c.op = val; UI:UpdateResourceDebug(c) end },
            { text = "==", value = "==", onSelect = function(val) c.op = val; UI:UpdateResourceDebug(c) end },
        })
        
        -- Value input
        ce.grpRes.val:SetText(tostring(c.val or 100))
        ce.grpRes.val:SetScript("OnTextChanged", function(self)
            c.val = tonumber(self:GetText()) or 0
            UI:UpdateResourceDebug(c)
        end)
        
        -- Incoming heals checkbox (show only for health)
        if c.resType == "HEALTH" then
            ce.grpRes.inc:Show()
        else
            ce.grpRes.inc:Hide()
        end
        ce.grpRes.inc:SetChecked(c.incHeal)
        ce.grpRes.inc:SetScript("OnClick", function()
            c.incHeal = ce.grpRes.inc:GetChecked()
            UI:UpdateResourceDebug(c)  -- Update debug when checkbox changes
        end)
        
        -- Update debug display
        UI:UpdateResourceDebug(c)
        UI:UpdateResourceDebug(c)
        
    elseif c.type == "PLAYER" then
        toggleGroup(ce.grpUnit)
        
        -- Initialize defaults
        c.inCombat = c.inCombat or false
        c.outCombat = c.outCombat or false
        c.mounted = c.mounted or false
        c.notMounted = c.notMounted or false
        c.moving = c.moving or false
        c.notMoving = c.notMoving or false
        c.groupType = c.groupType or "any"
        c.checkForm = c.checkForm or false
        c.formType = c.formType or "Bear Form"
        
        -- Combat checkboxes (mutually exclusive)
        ce.grpUnit.inCombat:SetChecked(c.inCombat)
        ce.grpUnit.inCombat:SetScript("OnClick", function()
            c.inCombat = ce.grpUnit.inCombat:GetChecked()
            if c.inCombat then
                c.outCombat = false
                ce.grpUnit.outCombat:SetChecked(false)
            end
        end)
        
        ce.grpUnit.outCombat:SetChecked(c.outCombat)
        ce.grpUnit.outCombat:SetScript("OnClick", function()
            c.outCombat = ce.grpUnit.outCombat:GetChecked()
            if c.outCombat then
                c.inCombat = false
                ce.grpUnit.inCombat:SetChecked(false)
            end
        end)
        
        -- Mount checkboxes (mutually exclusive)
        ce.grpUnit.mounted:SetChecked(c.mounted)
        ce.grpUnit.mounted:SetScript("OnClick", function()
            c.mounted = ce.grpUnit.mounted:GetChecked()
            if c.mounted then
                c.notMounted = false
                ce.grpUnit.notMounted:SetChecked(false)
            end
        end)
        
        ce.grpUnit.notMounted:SetChecked(c.notMounted)
        ce.grpUnit.notMounted:SetScript("OnClick", function()
            c.notMounted = ce.grpUnit.notMounted:GetChecked()
            if c.notMounted then
                c.mounted = false
                ce.grpUnit.mounted:SetChecked(false)
            end
        end)
        
        -- Moving checkboxes (mutually exclusive)
        ce.grpUnit.moving:SetChecked(c.moving)
        ce.grpUnit.moving:SetScript("OnClick", function()
            c.moving = ce.grpUnit.moving:GetChecked()
            if c.moving then
                c.notMoving = false
                ce.grpUnit.notMoving:SetChecked(false)
            end
        end)
        
        ce.grpUnit.notMoving:SetChecked(c.notMoving)
        ce.grpUnit.notMoving:SetScript("OnClick", function()
            c.notMoving = ce.grpUnit.notMoving:GetChecked()
            if c.notMoving then
                c.moving = false
                ce.grpUnit.moving:SetChecked(false)
            end
        end)
        
        -- Group type dropdown
        setDropdownOptions(ce.grpUnit.groupType, c.groupType, {
            { text = "Any", value = "any", onSelect = function(val) c.groupType = val end },
            { text = "Solo", value = "solo", onSelect = function(val) c.groupType = val end },
            { text = "Party", value = "party", onSelect = function(val) c.groupType = val end },
            { text = "Raid", value = "raid", onSelect = function(val) c.groupType = val end },
        })
        
        -- Form checking
        ce.grpUnit.checkForm:SetChecked(c.checkForm)
        ce.grpUnit.checkForm:SetScript("OnClick", function()
            c.checkForm = ce.grpUnit.checkForm:GetChecked()
            ce.grpUnit.formType:SetShown(c.checkForm)
        end)
        
        -- Form type dropdown (for druids mainly)
        setDropdownOptions(ce.grpUnit.formType, c.formType, {
            { text = "Bear Form", value = "Bear Form", onSelect = function(val) c.formType = val end },
            { text = "Cat Form", value = "Cat Form", onSelect = function(val) c.formType = val end },
            { text = "Aquatic Form", value = "Aquatic Form", onSelect = function(val) c.formType = val end },
            { text = "Travel Form", value = "Travel Form", onSelect = function(val) c.formType = val end },
            { text = "Moonkin Form", value = "Moonkin Form", onSelect = function(val) c.formType = val end },
            { text = "Human Form", value = "Human Form", onSelect = function(val) c.formType = val end },
        })
        
        -- Show/hide form dropdown based on checkbox
        ce.grpUnit.formType:SetShown(c.checkForm)
        
        -- Role checkbox and dropdown
        ce.grpUnit.checkRole:SetChecked(c.checkRole)
        ce.grpUnit.checkRole:SetScript("OnClick", function()
            c.checkRole = ce.grpUnit.checkRole:GetChecked()
            ce.grpUnit.roleType:SetShown(c.checkRole)
        end)
        
        setDropdownOptions(ce.grpUnit.roleType, c.roleType, {
            { text = "Tank", value = "Tank", onSelect = function(val) c.roleType = val end },
            { text = "DPS", value = "DPS", onSelect = function(val) c.roleType = val end },
            { text = "Healer", value = "Healer", onSelect = function(val) c.roleType = val end },
        })
        
        -- Show/hide role dropdown based on checkbox
        ce.grpUnit.roleType:SetShown(c.checkRole)
        
    elseif c.type == "UNIT" then
        toggleGroup(ce.grpUnitTarget)
        
        -- Initialize defaults
        c.targetUnit = c.targetUnit or "target"
        c.checkRaidMark = c.checkRaidMark or false
        c.raidMark = c.raidMark or "Star"
        c.isDead = c.isDead or false
        c.notDead = c.notDead or false
        c.friendly = c.friendly or false
        c.hostile = c.hostile or false
        c.isPlayer = c.isPlayer or false
        c.nonPlayer = c.nonPlayer or false
        c.attackable = c.attackable or false
        c.casting = c.casting or false
        c.checkRange = c.checkRange or false
        c.rangeVal = c.rangeVal or 30
        c.checkClass = c.checkClass or false
        c.classType = c.classType or "Warrior"
        c.checkUnitType = c.checkUnitType or false
        c.unitTypes = c.unitTypes or {}
        
        -- Unit selector
        setDropdownOptions(ce.grpUnitTarget.unitSelect, c.targetUnit, {
            { text = "target", value = "target", onSelect = function(val) c.targetUnit = val; UI:UpdateUnitTargetDebug(c) end },
            { text = "focus", value = "focus", onSelect = function(val) c.targetUnit = val; UI:UpdateUnitTargetDebug(c) end },
            { text = "mouseover", value = "mouseover", onSelect = function(val) c.targetUnit = val; UI:UpdateUnitTargetDebug(c) end },
            { text = "player", value = "player", onSelect = function(val) c.targetUnit = val; UI:UpdateUnitTargetDebug(c) end },
            { text = "pet", value = "pet", onSelect = function(val) c.targetUnit = val; UI:UpdateUnitTargetDebug(c) end },
        })
        
        -- Raid marker checkbox and dropdown
        ce.grpUnitTarget.raidMarkChk:SetChecked(c.checkRaidMark)
        ce.grpUnitTarget.raidMarkChk:SetScript("OnClick", function()
            c.checkRaidMark = ce.grpUnitTarget.raidMarkChk:GetChecked()
            ce.grpUnitTarget.raidMarkType:SetShown(c.checkRaidMark)
        end)
        
        setDropdownOptions(ce.grpUnitTarget.raidMarkType, c.raidMark, {
            { text = "Star", value = "Star", onSelect = function(val) c.raidMark = val end },
            { text = "Circle", value = "Circle", onSelect = function(val) c.raidMark = val end },
            { text = "Diamond", value = "Diamond", onSelect = function(val) c.raidMark = val end },
            { text = "Triangle", value = "Triangle", onSelect = function(val) c.raidMark = val end },
            { text = "Moon", value = "Moon", onSelect = function(val) c.raidMark = val end },
            { text = "Square", value = "Square", onSelect = function(val) c.raidMark = val end },
            { text = "Cross", value = "Cross", onSelect = function(val) c.raidMark = val end },
            { text = "Skull", value = "Skull", onSelect = function(val) c.raidMark = val end },
        })
        ce.grpUnitTarget.raidMarkType:SetShown(c.checkRaidMark)
        
        -- Death state (mutually exclusive)
        ce.grpUnitTarget.isDead:SetChecked(c.isDead)
        ce.grpUnitTarget.isDead:SetScript("OnClick", function()
            c.isDead = ce.grpUnitTarget.isDead:GetChecked()
            if c.isDead then
                c.notDead = false
                ce.grpUnitTarget.notDead:SetChecked(false)
            end
        end)
        
        ce.grpUnitTarget.notDead:SetChecked(c.notDead)
        ce.grpUnitTarget.notDead:SetScript("OnClick", function()
            c.notDead = ce.grpUnitTarget.notDead:GetChecked()
            if c.notDead then
                c.isDead = false
                ce.grpUnitTarget.isDead:SetChecked(false)
            end
        end)
        
        -- Hostility (mutually exclusive)
        ce.grpUnitTarget.friendly:SetChecked(c.friendly)
        ce.grpUnitTarget.friendly:SetScript("OnClick", function()
            c.friendly = ce.grpUnitTarget.friendly:GetChecked()
            if c.friendly then
                c.hostile = false
                ce.grpUnitTarget.hostile:SetChecked(false)
            end
        end)
        
        ce.grpUnitTarget.hostile:SetChecked(c.hostile)
        ce.grpUnitTarget.hostile:SetScript("OnClick", function()
            c.hostile = ce.grpUnitTarget.hostile:GetChecked()
            if c.hostile then
                c.friendly = false
                ce.grpUnitTarget.friendly:SetChecked(false)
            end
        end)
        
        -- Player/NPC (mutually exclusive)
        ce.grpUnitTarget.isPlayer:SetChecked(c.isPlayer)
        ce.grpUnitTarget.isPlayer:SetScript("OnClick", function()
            c.isPlayer = ce.grpUnitTarget.isPlayer:GetChecked()
            if c.isPlayer then
                c.nonPlayer = false
                ce.grpUnitTarget.nonPlayer:SetChecked(false)
            end
        end)
        
        ce.grpUnitTarget.nonPlayer:SetChecked(c.nonPlayer)
        ce.grpUnitTarget.nonPlayer:SetScript("OnClick", function()
            c.nonPlayer = ce.grpUnitTarget.nonPlayer:GetChecked()
            if c.nonPlayer then
                c.isPlayer = false
                ce.grpUnitTarget.isPlayer:SetChecked(false)
            end
        end)
        
        -- Other checkboxes
        ce.grpUnitTarget.attackable:SetChecked(c.attackable)
        ce.grpUnitTarget.attackable:SetScript("OnClick", function()
            c.attackable = ce.grpUnitTarget.attackable:GetChecked()
        end)
        
        ce.grpUnitTarget.casting:SetChecked(c.casting)
        ce.grpUnitTarget.casting:SetScript("OnClick", function()
            c.casting = ce.grpUnitTarget.casting:GetChecked()
        end)
        
        -- Range check
        ce.grpUnitTarget.rangeChk:SetChecked(c.checkRange)
        ce.grpUnitTarget.rangeChk:SetScript("OnClick", function()
            c.checkRange = ce.grpUnitTarget.rangeChk:GetChecked()
            ce.grpUnitTarget.rangeVal:SetShown(c.checkRange)
        end)
        
        setDropdownOptions(ce.grpUnitTarget.rangeVal, tostring(c.rangeVal), {
            { text = "5", value = "5", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "8", value = "8", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "10", value = "10", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "15", value = "15", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "20", value = "20", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "25", value = "25", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "30", value = "30", onSelect = function(val) c.rangeVal = tonumber(val) end },
            { text = "40", value = "40", onSelect = function(val) c.rangeVal = tonumber(val) end },
        })
        ce.grpUnitTarget.rangeVal:SetShown(c.checkRange)
        
        -- Class check
        ce.grpUnitTarget.classChk:SetChecked(c.checkClass)
        ce.grpUnitTarget.classChk:SetScript("OnClick", function()
            c.checkClass = ce.grpUnitTarget.classChk:GetChecked()
            ce.grpUnitTarget.classType:SetShown(c.checkClass)
        end)
        
        setDropdownOptions(ce.grpUnitTarget.classType, c.classType, {
            { text = "Warrior", value = "Warrior", onSelect = function(val) c.classType = val end },
            { text = "Paladin", value = "Paladin", onSelect = function(val) c.classType = val end },
            { text = "Hunter", value = "Hunter", onSelect = function(val) c.classType = val end },
            { text = "Rogue", value = "Rogue", onSelect = function(val) c.classType = val end },
            { text = "Priest", value = "Priest", onSelect = function(val) c.classType = val end },
            { text = "Shaman", value = "Shaman", onSelect = function(val) c.classType = val end },
            { text = "Mage", value = "Mage", onSelect = function(val) c.classType = val end },
            { text = "Warlock", value = "Warlock", onSelect = function(val) c.classType = val end },
            { text = "Druid", value = "Druid", onSelect = function(val) c.classType = val end },
        })
        ce.grpUnitTarget.classType:SetShown(c.checkClass)
        
        -- Unit type check
        ce.grpUnitTarget.unitTypeChk:SetChecked(c.checkUnitType)
        ce.grpUnitTarget.unitTypeChk:SetScript("OnClick", function()
            c.checkUnitType = ce.grpUnitTarget.unitTypeChk:GetChecked()
            ce.grpUnitTarget.unitTypeList:SetShown(c.checkUnitType)
        end)
        
        -- For now, simple dropdown (could be enhanced to multiselect later)
        local selectedType = c.unitTypes and c.unitTypes[1] or "Humanoid"
        setDropdownOptions(ce.grpUnitTarget.unitTypeList, selectedType, {
            { text = "Humanoid", value = "Humanoid", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Beast", value = "Beast", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Dragon", value = "Dragon", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Demon", value = "Demon", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Elemental", value = "Elemental", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Giant", value = "Giant", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Undead", value = "Undead", onSelect = function(val) c.unitTypes = {val} end },
            { text = "Mechanical", value = "Mechanical", onSelect = function(val) c.unitTypes = {val} end },
        })
        ce.grpUnitTarget.unitTypeList:SetShown(c.checkUnitType)
        
        -- Initialize debug display
        UI:UpdateUnitTargetDebug(c)
        
    else
        toggleGroup(nil)
    end
end

function UI:UpdateCondDebug()
    local ce = UI.right and UI.right.editor
    if not ce or not ce.debugTxt then return end
    if not UI.selIdx or not UI.curCondIdx or not NS.db or not NS.db.steps[UI.selIdx] then
        ce.debugTxt:SetText("Last: --")
        return
    end

    local c = NS.db.steps[UI.selIdx].conditions[UI.curCondIdx]
    if not c then
        ce.debugTxt:SetText("Last: --")
        return
    end

    if c.lastPass == nil then
        ce.debugTxt:SetText("Last: pending")
        return
    end

    local status = c.lastPass and "PASS" or "FAIL"
    local val = c.lastVal or ""
    ce.debugTxt:SetText(string.format("Last: %s %s", status, val))
end

function UI:UpdateResourceDebug(c)
    local ce = UI.right and UI.right.editor
    if not ce or not ce.grpRes or not ce.grpRes.debugLbl or c.type ~= "RESOURCE" then return end
    
    local unit = c.unit or "player"
    if not UnitExists(unit) then 
        ce.grpRes.debugLbl:SetText("Debug: Unit does not exist")
        return
    end
    
    local current, max = 0, 0
    local resName = c.resType or "HEALTH"
    
    if resName == "HEALTH" then
        current = UnitHealth(unit)
        max = UnitHealthMax(unit)
        if c.incHeal then 
            local incoming = UnitGetIncomingHeals and UnitGetIncomingHeals(unit) or 0
            current = current + incoming
        end
    elseif resName == "MANA" then
        current = UnitPower(unit, 0)
        max = UnitPowerMax(unit, 0)
    elseif resName == "RAGE" then
        current = UnitPower(unit, 1)
        max = UnitPowerMax(unit, 1)
    elseif resName == "ENERGY" then
        current = UnitPower(unit, 3)
        max = UnitPowerMax(unit, 3)
    elseif resName == "COMBO" then
        current = GetComboPoints("player", "target")
        max = 5
    end
    
    local calculated = current
    local mode = c.mode or "percent"
    if mode == "percent" and max > 0 then
        calculated = (current / max) * 100
    elseif mode == "deficit" then
        calculated = max - current
    end
    
    local debugText = string.format("Debug: %s %s/%s (calc:%.1f %s)", resName, current, max, calculated, mode)
    if c.incHeal and resName == "HEALTH" then
        debugText = debugText .. " +Inc"
    end
    
    -- Add comparison logic to debug
    local op = c.op or "<"
    local val = c.val or 100
    local result = false
    if op == "<" then result = calculated < val
    elseif op == ">" then result = calculated > val  
    elseif op == "<=" then result = calculated <= val
    elseif op == ">=" then result = calculated >= val
    elseif op == "==" then result = math.abs(calculated - val) < 0.1
    end
    
    debugText = debugText .. string.format(" | Test: %.1f %s %s = %s", calculated, op, val, result and "PASS" or "FAIL")
    
    ce.grpRes.debugLbl:SetText(debugText)
    
    -- Show condition config
    local configText = string.format("Config: %s/%s/%s/%s/%s (trueFlag:%s)", c.unit or "?", c.resType or "?", c.mode or "?", c.op or "?", c.val or "?", tostring(c.trueFlag))
    if ce.grpRes.debugLbl2 then
        ce.grpRes.debugLbl2:SetText(configText)
    end
end

function UI:UpdateAuraDebug(c)
    local ce = UI.right and UI.right.editor
    if not ce or not ce.grpAura or not ce.grpAura.debugLbl or c.type ~= "AURA" then return end
    
    local unit = c.unit or "target"
    if not UnitExists(unit) then 
        ce.grpAura.debugLbl:SetText("Debug: Unit does not exist")
        return
    end
    
    local filter = c.isDebuff and "HARMFUL" or "HELPFUL"
    if c.ownOnly then filter = filter .. "|PLAYER" end
    
    local auraName = c.auraName or ""
    local found = false
    local foundName = ""
    local foundStacks = 0
    local foundTime = 0
    
    -- If we're doing status checking with empty name, check both HARMFUL and HELPFUL
    local filtersToCheck = {filter}
    if auraName == "" and c.checkStatus and c.statusTypes and #c.statusTypes > 0 then
        filtersToCheck = {"HARMFUL", "HELPFUL"}
        if c.ownOnly then 
            filtersToCheck = {"HARMFUL|PLAYER", "HELPFUL|PLAYER"}
        end
    end
    
    -- Scan for auras
    for _, checkFilter in ipairs(filtersToCheck) do
        for i = 1, 40 do
            local name, _, count, _, _, exp, _, isStealable, _, spellId = UnitAura(unit, i, checkFilter)
        if not name then break end
        
        local match = false
        
        -- Check name matching
        if auraName ~= "" then
            if string.find(string.lower(name), string.lower(auraName), 1, true) then
                match = true
            end
        else
            match = true  -- Empty name matches all initially
        end
        
        -- Check status types if enabled
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
                    statusMatch = string.find(string.lower(name), "fear", 1, true) ~= nil
                elseif statusType == "Charmed" then 
                    statusMatch = string.find(string.lower(name), "charm", 1, true) ~= nil
                elseif statusType == "Rooted" then 
                    statusMatch = string.find(string.lower(name), "root", 1, true) ~= nil or string.find(string.lower(name), "entangle", 1, true) ~= nil
                elseif statusType == "Silenced" then 
                    statusMatch = string.find(string.lower(name), "silence", 1, true) ~= nil
                elseif statusType == "Bleeding" then 
                    statusMatch = string.find(string.lower(name), "bleed", 1, true) ~= nil or string.find(string.lower(name), "rend", 1, true) ~= nil
                elseif statusType == "Poisoned" then 
                    statusMatch = string.find(string.lower(name), "poison", 1, true) ~= nil
                end
                if statusMatch then
                    hasStatus = true
                    break
                end
            end
            
            -- Apply status filtering
            if auraName == "" then
                match = hasStatus  -- Empty name: only match if status matches
            else
                if not hasStatus then match = false end  -- Named aura: must have status too
            end
        end
        
        if match then
            found = true
            foundName = name
            foundStacks = count or 0
            -- Fix stack count: if stacks are 9, treat as 1
            if foundStacks == 9 then foundStacks = 1 end
            foundTime = exp and exp > 0 and (exp - GetTime()) or 0
            break
        end
    end
    
    if found then break end -- Stop checking other filters if we found something
end
    
    local debugText = ""
    if auraName ~= "" then
        debugText = string.format("Debug: '%s' on %s (%s)", auraName, unit, filter)
    else
        local statusNames = {}
        if c.checkStatus and c.statusTypes then
            for _, status in ipairs(c.statusTypes) do
                table.insert(statusNames, status)
            end
        end
        local statusText = #statusNames > 0 and table.concat(statusNames, ",") or "any"
        debugText = string.format("Debug: Status[%s] on %s (%s)", statusText, unit, filter)
    end
    
    if found then
        debugText = debugText .. string.format(" -> FOUND: %s (stacks:%d, time:%.1f)", foundName, foundStacks, foundTime)
    else
        debugText = debugText .. " -> NOT FOUND"
    end
    
    ce.grpAura.debugLbl:SetText(debugText)
end

function UI:UpdateUnitTargetDebug(c)
    local ce = UI.right and UI.right.editor
    if not ce or not ce.grpUnitTarget or not ce.grpUnitTarget.debugLbl or c.type ~= "UNIT" then return end
    
    local unit = c.targetUnit or "target"
    if not UnitExists(unit) then 
        ce.grpUnitTarget.debugLbl:SetText("Debug: Unit does not exist")
        return
    end
    
    local info = {}
    
    -- Basic unit info
    table.insert(info, "Unit: " .. unit)
    
    local name = UnitName(unit)
    if name then table.insert(info, "Name: " .. name) end
    
    -- Raid marker
    local markIndex = GetRaidTargetIndex(unit)
    if markIndex then
        local marks = {"Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull"}
        table.insert(info, "Mark: " .. (marks[markIndex] or markIndex))
    else
        table.insert(info, "Mark: none")
    end
    
    -- Death state
    local isDead = UnitIsDeadOrGhost(unit)
    table.insert(info, "Dead: " .. (isDead and "yes" or "no"))
    
    -- Hostility
    local canAttack = UnitCanAttack("player", unit)
    table.insert(info, "Hostile: " .. (canAttack and "yes" or "no"))
    
    -- Player check
    local isPlayer = UnitIsPlayer(unit)
    table.insert(info, "Player: " .. (isPlayer and "yes" or "no"))
    
    -- Class
    if isPlayer then
        local _, unitClass = UnitClass(unit)
        if unitClass then table.insert(info, "Class: " .. unitClass) end
    else
        local creatureType = UnitCreatureType(unit)
        if creatureType then table.insert(info, "Type: " .. creatureType) end
    end
    
    -- Casting
    local spell = UnitCastingInfo(unit) or UnitChannelInfo(unit)
    table.insert(info, "Casting: " .. (spell and "yes" or "no"))
    
    -- Attackable
    table.insert(info, "Attackable: " .. (canAttack and "yes" or "no"))
    
    local debugText = "Debug: " .. table.concat(info, ", ")
    ce.grpUnitTarget.debugLbl:SetText(debugText)
end

function UI:SelectAction(idx)
    UI.selIdx = idx
    UI.curCondIdx = nil
    if UI.right then
        if idx and NS.db.steps[idx] then
            UI.right:Show()
            local s = NS.db.steps[idx]
            if not s.criteria then s.criteria = "RANK" end
            if UI.right.btnName then UI.right.btnName:SetText(s.name or "Select Spell") end
            UI:RefreshConds()
            if s.conditions and #s.conditions > 0 then UI:EditCondition(1) end
            if UI.RefreshRightPanel then UI:RefreshRightPanel() end
        else
            UI.right:Hide()
        end
    end
    UI:RefreshList()
end

function UI:OnTick()
    if UI.rows and NS.db then
        local list = NS.db.steps
        local off = FauxScrollFrame_GetOffset(UI.leftScroll) or 0
        for i, row in ipairs(UI.rows) do
            local idx = off + i
            if idx <= #list and row:IsShown() then
                local s = list[idx]
                local key = s.name
                if s.criteria and s.criteria ~= "RANK" then key = s.name .. "_" .. s.criteria end
                local data = NS.Book[key] or NS.Book[s.name]
                local slot = data and data.slot or 0
                local bg = { 0.2, 0.2, 0.2, 0.85 }
                if s.disabled then
                    bg = { 0.05, 0.35, 0.75, 0.85 }
                elseif not data then bg = { 0.5, 0, 0.7, 0.7 }
                elseif slot == 0 and data.type ~= "MACRO" then bg = { 1, 0.5, 0, 0.7 }
                else
                    local pass = NS.Engine:EvaluateStep(s)
                    if pass then bg = { 0, 0.6, 0, 0.7 } else bg = { 0.6, 0, 0, 0.7 } end
                end
                row:SetBackdropColor(unpack(bg))
            end
        end
    end

    if UI.selIdx and NS.db then
        local s = NS.db.steps[UI.selIdx]
        if s and not s.disabled then NS.Engine:EvaluateStep(s) end
        UI:RefreshConds()
        UI:UpdateCondDebug()
    end
end

function UI:CreatePicker()
    local f = CreateFrame("Frame", "JamboRotPicker", UIParent, "BackdropTemplate")
    f:SetSize(320, 360)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.05, 1)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    local sf = CreateFrame("ScrollFrame", "JR_PickScroll", f, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -26, 6)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 22, UI.RefreshPicker)
    end)
    UI.pickerScroll = sf

    UI.pRows = {}
    for i = 1, 16 do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(290, 22)
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 22)
        b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.txt:SetPoint("LEFT", 4, 0)
        b.meta = b:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        b.meta:SetPoint("RIGHT", -4, 0)
        b.meta:SetTextColor(0.6, 0.6, 0.6)
        b:SetScript("OnClick", function()
            if UI.selIdx and b.dataName then
                NS.db.steps[UI.selIdx].name = b.dataName
                UI.right.btnName:SetText(b.dataName)
                UI:RefreshList()
                f:Hide()
            end
        end)
        UI.pRows[i] = b
    end

    UI.picker = f
end

function UI:RefreshPicker(skipBuild)
    if not UI.pickerScroll then return end

    if (not NS.Book or not next(NS.Book)) then
        if not skipBuild and NS.Data and NS.Data.BuildBook then NS.Data:BuildBook() end
        if not NS.Book or not next(NS.Book) then return end
    end

    UI.pickerList = {}
    local seen = {}
    for _, d in pairs(NS.Book) do
        if d and (d.type == "SPELL" or d.type == "MACRO") and type(d.name) == "string" and not d.name:find("_") then
            local key = (d.type or "") .. ":" .. d.name
            if not seen[key] then
                seen[key] = true
                table.insert(UI.pickerList, d)
            end
        end
    end
    table.sort(UI.pickerList, function(a, b) return a.name < b.name end)

    local off = FauxScrollFrame_GetOffset(UI.pickerScroll) or 0
    for i, row in ipairs(UI.pRows) do
        local idx = off + i
        if idx <= #UI.pickerList then
            local d = UI.pickerList[idx]
            row.dataName = d.name
            local color = "|cffffffff"
            if d.type == "ITEM" then color = "|cff00ff00" elseif d.type == "MACRO" then color = "|cffffa500" end
            row.txt:SetText(color .. "|T" .. (d.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":14|t " .. d.name .. "|r")
            row.meta:SetText(d.type == "MACRO" and "Macro" or ("Slot " .. (d.slot or 0)))
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(UI.pickerScroll, #UI.pickerList, 16, 22)
end

function UI:CreateIconFrame()
    if UI.iconFrame then UI.iconFrame:Show(); return end
    local i = CreateFrame("Button", "JamboRotIcon", UIParent, "BackdropTemplate")
    i:SetSize(52, 52)
    if NS.db and NS.db.iconPos then
        local p = NS.db.iconPos
        i:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else
        i:SetPoint("CENTER", 0, 120)
    end
    i:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    i:SetBackdropBorderColor(0, 0, 0, 1)
    i.tex = i:CreateTexture(nil, "ARTWORK")
    i.tex:SetAllPoints()
    i.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    i.tex:SetTexture("Interface\\Icons\\Trade_Engineering")

    i:SetMovable(true)
    i:EnableMouse(true)
    i:RegisterForDrag("LeftButton")
    i:SetScript("OnDragStart", i.StartMoving)
    i:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, r, x, y = self:GetPoint()
        if NS.db then NS.db.iconPos = { point = p, relativePoint = r, x = x, y = y } end
    end)

    i:RegisterForClicks("AnyUp")
    i:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            -- Open Jambo Gear UI on right-click
            if _G.JamboGear and _G.JamboGear.ToggleGUI then
                _G.JamboGear:ToggleGUI()
            end
        else
            -- Left-click: toggle rotation UI
            if not UI.frame then UI:Init() end
            if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
        end
    end)

    i.lbl = i:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    i.lbl:SetPoint("BOTTOM", 0, -12)
    i.lbl:SetText("Priority")

    UI.iconFrame = i
    i:Show()
end

function UI:UpdateIcon(texture)
    if not UI.iconFrame then return end
    if texture then
        UI.iconFrame.tex:SetTexture(texture)
        UI.iconFrame:SetAlpha(1)
    else
        UI.iconFrame.tex:SetTexture("Interface\\Icons\\Trade_Engineering")
        UI.iconFrame:SetAlpha(0.8)
    end
end