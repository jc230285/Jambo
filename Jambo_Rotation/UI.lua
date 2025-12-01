local ADDON, NS = ...

NS.UI = NS.UI or {}
local UI = NS.UI

-- proxy that late-binds to NS.Rot to avoid issues when this file loads before Core.lua
local Rot = setmetatable({}, {
    __index = function(_, key)
        local r = NS and NS.Rot
        if not r then return nil end
        local v = r[key]
        if type(v) == 'function' then
            return function(...)
                -- If invoked as a method with colon syntax (self, ...), the first arg will be the proxy; strip it.
                local args = {...}
                if args[1] == Rot then table.remove(args, 1) end
                return v(r, unpack(args))
            end
        end
        return v
    end,
})

local frame
local spellDropdown
local rankDropdown
local rotationRows = {}

-- Helper: find action bar slot for a given step (returns slot number or nil)
local function findSlotForStep(step)
    if not step then return nil end
    for s = 1, 120 do
        local atype, id = GetActionInfo(s)
        if atype == "macro" and step.spellId and id == step.spellId then
            return s
        end
        if atype == "spell" then
            if type(id) == "number" and step.spellId and id == step.spellId then
                return s
            elseif type(id) == "string" and step.spell and id == step.spell then
                return s
            end
        end
        -- If this is a macro and the step has a persisted macroName, compare macro names
        if atype == "macro" and id and (step.isMacro or step.macroName) then
            local mname = GetMacroInfo(id)
            if mname then
                local function norm(s) if not s then return "" end return s:lower():gsub("[^%w]","") end
                if step.macroName and norm(step.macroName) == norm(mname) then return s end
                if step.spell and norm(step.spell) == norm(mname) then return s end
            end
        end
    end
    return nil
end

-- Helper: find action slot for a spell ID or macro ID
local function findSlotForSpellId(spellID)
    if not spellID or type(GetActionInfo) ~= "function" then return nil end
    for s = 1, 120 do
        local atype, id = GetActionInfo(s)
        if atype == "spell" and id and id == spellID then
            return s
        end
    end
    return nil
end
local function findSlotForMacroId(macroID)
    if not macroID or type(GetActionInfo) ~= "function" then return nil end
    for s = 1, 120 do
        local atype, id = GetActionInfo(s)
        if atype == "macro" and id and id == macroID then
            return s
        end
    end
    return nil
end

------------------------------------------------------------
-- Create main window
------------------------------------------------------------
function UI:Create()
    if frame then return end

    frame = CreateFrame("Frame", "JamboRotFrame", UIParent, "BackdropTemplate")
    frame:SetSize(400, 500)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile= "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize= 32,
        tile=true, tileSize=32,
    })

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Jambo Rot – Rotation Builder")

    -- Top-pass label: show the first passing step's Spell name, Spell ID, and action Slot ID
    local topLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    topLabel:SetPoint("TOPLEFT", 20, -30)
    topLabel:SetWidth(360)
    topLabel:SetJustifyH("LEFT")
    topLabel:SetText("Top PASS: 0")
    UI.topPassLabel = topLabel

    --------------------------------------------------------
    -- SPELL DROPDOWN
    --------------------------------------------------------
    spellDropdown = CreateFrame("Frame", "JamboRotSpellDropdown", frame, "UIDropDownMenuTemplate")
    spellDropdown:SetPoint("TOPLEFT", 20, -50)
    spellDropdown:SetClampedToScreen(true)
    spellDropdown:HookScript("OnShow", function(self)
        if UIDropDownMenu_SetAnchor then
            UIDropDownMenu_SetAnchor(self, 0, 0, "TOPLEFT", self, "BOTTOMLEFT")
        end
    end)

    UIDropDownMenu_SetWidth(spellDropdown, 200)
    -- A shorter max height improves UX for long lists
    if UIDropDownMenu_SetMaxHeight then UIDropDownMenu_SetMaxHeight(spellDropdown, 240) end
    UIDropDownMenu_SetText(spellDropdown, "Select Spell")

    -- We'll initialise the spelled dropdown dynamically using RefreshSpellList so it can be refreshed on demand.
    local function initSpellMenu()
        local SpellList = {}
        if Rot and type(Rot.GetAllSpells) == 'function' then
            SpellList = Rot:GetAllSpells() or {}
        end
        local spellNames = {}
        for name, ranks in pairs(SpellList) do
            -- compute if any rank is known
            local anyKnown = false
            for _, r in ipairs(ranks) do if r.known then anyKnown = true; break end end
            table.insert(spellNames, { name = name, known = anyKnown, rankCount = #ranks, isMacro = false, macroId = nil })
        end
        -- Add macros from the player's macro list too
        if type(GetNumMacros) == "function" then
            local nmacro = GetNumMacros() or 0
            for i = 1, nmacro do
                local mname, icon, body = GetMacroInfo(i)
                if mname then
                    table.insert(spellNames, { name = mname, known = true, rankCount = 0, isMacro = true, macroId = i })
                end
            end
        end
        table.sort(spellNames, function(a, b)
            if a.name == b.name then return a.rankCount > b.rankCount end
            return a.name < b.name
        end)
        UIDropDownMenu_Initialize(spellDropdown, function(self, level)
            for _, sp in ipairs(spellNames) do
                local info = UIDropDownMenu_CreateInfo()
                local color = sp.isMacro and "|cFF0077FF" or (sp.known and "|cFF00FF00" or "|cFF808080")
                local nameText = sp.name
                if sp.isMacro then
                    -- find macro slot id if present
                    local slotId = nil
                    if type(GetNumMacros) == "function" then
                        for s = 1, 120 do
                            local atype, id = GetActionInfo(s)
                            if atype == "macro" and id == sp.macroId then
                                slotId = s
                                break
                            end
                        end
                    end
                    local slotText = slotId and (" [" .. tostring(slotId) .. "]") or ""
                    info.text = color .. nameText .. " (macro)" .. slotText .. " [id:"..tostring(sp.macroId).."]|r"
                else
                    -- Try to detect a spell id and assigned action slot for the spell name
                    local slotId = nil
                    local detectedId = nil
                    if type(Rot.GetAllSpells) == 'function' then
                        local _spells_table = Rot:GetAllSpells() or {}
                        local ranks = _spells_table[sp.name]
                        if ranks then
                            for _, rr in ipairs(ranks) do
                                if rr.id then
                                    detectedId = rr.id
                                    -- If this rank is on an action slot, show that
                                    local s = findSlotForSpellId(rr.id)
                                    if s then slotId = s; break end
                                end
                            end
                        end
                    end
                    local idText = detectedId and (" [id:" .. tostring(detectedId) .. "]") or ""
                    local slotText = slotId and (" [slot:" .. tostring(slotId) .. "]") or ""
                    info.text = color .. sp.name .. idText .. slotText .. "|r"
                end
                info.arg1 = sp.name
                info.func = function(_, arg1)
                    UIDropDownMenu_SetText(spellDropdown, arg1)
                    -- store if this selection is a macro for later 'Add' handling
                    spellDropdown.selectedMacroId = sp.isMacro and sp.macroId or nil
                    spellDropdown.selectedIsMacro = sp.isMacro or false
                    UI:RefreshRanks(arg1)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    -- Expose helper so UI:Init can refresh this list on addon load and user request
    UI.RefreshSpellList = initSpellMenu
    initSpellMenu()

    -- Build a scrollable list for spells (FauxScrollFrame) so long lists are easy to browse
    local spellListFrame = CreateFrame("Frame", "JamboRotSpellListFrame", frame)
    spellListFrame:SetPoint("TOPLEFT", spellDropdown, "BOTTOMLEFT", -10, -8)
    spellListFrame:SetSize(360, 200)
    local listScroll = CreateFrame("ScrollFrame", "JamboRotSpellListScroll", spellListFrame, "FauxScrollFrameTemplate")
    listScroll:SetAllPoints(spellListFrame)
    local visibleRows = 10
    local rowHeight = 18
    local spellRows = {}
    for i = 1, visibleRows do
        local row = CreateFrame("Button", nil, spellListFrame)
        row:SetPoint("TOPLEFT", spellListFrame, "TOPLEFT", 4, -((i-1) * rowHeight) - 2)
        row:SetSize(340, rowHeight)
        row:SetNormalFontObject("GameFontNormal")
        row:SetHighlightFontObject("GameFontHighlight")
        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        txt:SetPoint("LEFT", 6, 0)
        txt:SetJustifyH("LEFT")
        row.text = txt
        row:SetScript("OnClick", function(self)
            local idx = self.idx
            if not idx then return end
            local item = (UI.spellListData or {})[idx]
            if not item then return end
            -- set dropdown text and selection info
            UIDropDownMenu_SetText(spellDropdown, item.name)
            spellDropdown.selectedMacroId = item.isMacro and item.macroId or nil
            spellDropdown.selectedIsMacro = item.isMacro or false
            -- refresh rank dropdown
            UI:RefreshRanks(item.name)
            -- hide scroll list after selection
            if UI.spellListFrame and UI.spellListFrame:IsShown() then UI.spellListFrame:Hide() end
        end)
        spellRows[i] = row
    end
    UI.spellListScroll = listScroll
    UI.spellListRows = spellRows
    UI.spellListFrame = spellListFrame
    UI.spellListVisible = visibleRows

    -- A helper to refresh the scroll frame/UI list
    function UI:RefreshSpellListScroll()
        local list = {}
        -- gather spells and macros into a single list for browsing
        local SpellList = (type(Rot.GetAllSpells) == 'function' and (Rot:GetAllSpells() or {})) or {}
        for name, ranks in pairs(SpellList) do
            table.insert(list, { name = name, isMacro = false, macroId = nil, known = false, rankCount = #ranks })
        end
        if type(GetNumMacros) == "function" then
            local nmacro = GetNumMacros() or 0
            for i = 1, nmacro do
                local mname = select(1, GetMacroInfo(i))
                if mname then table.insert(list, { name = mname, isMacro = true, macroId = i, known = true, rankCount = 0 }) end
            end
        end
        table.sort(list, function(a, b) if a.name == b.name then return a.rankCount > b.rankCount end return a.name < b.name end)
        UI.spellListData = list
        -- Update visible rows
        local total = #list
        FauxScrollFrame_Update(UI.spellListScroll, total, UI.spellListVisible, rowHeight)
        local offset = FauxScrollFrame_GetOffset(UI.spellListScroll) or 0
        for i = 1, UI.spellListVisible do
            local row = UI.spellListRows[i]
            local idx = i + offset
            if list[idx] then
                local item = list[idx]
                row.idx = idx
                local display = item.name
                local idText = ""
                local slotText = ""
                if item.isMacro then
                    display = display .. " (macro)"
                    idText = " [id:" .. tostring(item.macroId) .. "]"
                    local s = findSlotForMacroId(item.macroId)
                    if s then slotText = " [slot:" .. tostring(s) .. "]" end
                    display = "|cFF0077FF" .. display .. idText .. slotText .. "|r"
                else
                    -- find a detected spell id and show slot if present
                    if type(Rot.GetAllSpells) == 'function' then
                        local _sp = Rot:GetAllSpells()[item.name]
                        if _sp and #_sp > 0 then
                            local detectedId = nil
                            for _, rr in ipairs(_sp) do if rr.id then detectedId = rr.id; break end end
                            if detectedId then
                                idText = " [id:" .. tostring(detectedId) .. "]"
                                local s = findSlotForSpellId(detectedId)
                                if s then slotText = " [slot:" .. tostring(s) .. "]" end
                            end
                        end
                    end
                    display = display .. idText .. slotText
                end
                row.text:SetText(display)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    -- Hook into the existing RefreshSpellList call to also refresh the scroll view
    local origRefresh = UI.RefreshSpellList
    UI.RefreshSpellList = function()
        if origRefresh then pcall(origRefresh) end
        pcall(function() UI:RefreshSpellListScroll() end)
    end
    -- initialize list now
    UI:RefreshSpellListScroll()
    -- Ensure the scroll list is above other UI elements and initially hidden
    spellListFrame:SetFrameStrata("DIALOG")
    spellListFrame:SetFrameLevel((frame:GetFrameLevel() or 0) + 10)
    spellListFrame:SetClampedToScreen(true)
    spellListFrame:Hide()

    -- When clicking the built-in dropdown, toggle our custom scroll list instead of the built-in menu
    -- The dropdown template creates a button; attempt to find it and override OnClick
    local ddBtn = spellDropdown.Button or spellDropdown.Button or spellDropdown:GetChildren() and spellDropdown:GetChildren()
    -- Find the child named 'Button' (common for UIDropDownMenuTemplate)
    if type(spellDropdown.GetName) == 'function' then
        local ddName = spellDropdown:GetName()
        local ddBtnFrame = _G[ddName .. "Button"]
        if ddBtnFrame then ddBtn = ddBtnFrame end
    end
    if ddBtn and type(ddBtn.SetScript) == 'function' then
        ddBtn:SetScript("OnClick", function(self)
            if CloseDropDownMenus then CloseDropDownMenus() end
            if UI.spellListFrame:IsShown() then UI.spellListFrame:Hide() else UI:RefreshSpellListScroll(); UI.spellListFrame:Show() end
        end)
    end
    spellDropdown:HookScript("OnMouseDown", function(self)
        if CloseDropDownMenus then CloseDropDownMenus() end
        if UI.spellListFrame:IsShown() then UI.spellListFrame:Hide() else UI:RefreshSpellListScroll(); UI.spellListFrame:Show() end
    end)
    spellDropdown:HookScript("OnHide", function() if UI.spellListFrame:IsShown() then UI.spellListFrame:Hide() end end)

    --------------------------------------------------------
    -- RANK DROPDOWN
    --------------------------------------------------------
    rankDropdown = CreateFrame("Frame", "JamboRotRankDropdown", frame, "UIDropDownMenuTemplate")
    rankDropdown:SetPoint("LEFT", spellDropdown, "RIGHT", 20, 0)
    rankDropdown:SetClampedToScreen(true)
    rankDropdown:HookScript("OnShow", function(self)
        if UIDropDownMenu_SetAnchor then
            UIDropDownMenu_SetAnchor(self, 0, 0, "TOPLEFT", self, "BOTTOMLEFT")
        end
    end)
    UIDropDownMenu_SetWidth(rankDropdown, 220)
    if UIDropDownMenu_SetMaxHeight then UIDropDownMenu_SetMaxHeight(rankDropdown, 240) end
    UIDropDownMenu_SetText(rankDropdown, "Rank")

    --------------------------------------------------------
    -- ADD BUTTON
    --------------------------------------------------------
    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 24)
    addBtn:SetPoint("LEFT", rankDropdown, "RIGHT", 10, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local spellName = UIDropDownMenu_GetText(spellDropdown)
        local rankText  = UIDropDownMenu_GetText(rankDropdown)
        local selectedRankIndex = rankDropdown.selectedRankIndex
        if not (spellName and rankText and spellName ~= "" and rankText ~= "") then return end
        -- Resolve rank entry (handles "auto" selectors and ensures we get an id/rankIndex)
        local rEntry = nil
        if type(Rot.ResolveRank) == 'function' then
            rEntry = Rot:ResolveRank(spellName, rankText)
        end
        local resolvedRankIndex = nil
        local resolvedSpellId = nil
        if rEntry then
            resolvedRankIndex = rEntry.rankIndex
            resolvedSpellId = rEntry.id
        elseif spellDropdown.selectedIsMacro and spellDropdown.selectedMacroId then
            -- selected macro: store macro id as spell id for the step
            resolvedSpellId = spellDropdown.selectedMacroId
            resolvedRankIndex = nil
        else
            -- if we didn't resolve, try to auto-resolve using the best rank if possible
            local _spells_table = type(Rot.GetAllSpells) == 'function' and (Rot:GetAllSpells() or {}) or {}
            local ranks = _spells_table[spellName]
            if ranks and #ranks > 0 then
                -- Choose the highest rank as fallback
                local fallback = ranks[#ranks]
                if fallback and fallback.id then
                    resolvedSpellId = fallback.id
                    resolvedRankIndex = fallback.rankIndex
                end
            else
                resolvedRankIndex = selectedRankIndex
            end
        end
        Rot:AddStep(spellName, rankText, resolvedRankIndex, resolvedSpellId)
        -- if adding a macro, persist the macro name and flag
        local last = #NS.db.rotation
        if last and last > 0 then
            local step = NS.db.rotation[last]
            step.isMacro = spellDropdown.selectedIsMacro or false
            if step.isMacro then step.macroName = spellName end
            JamboRotDB = NS.db
        end
        UI:RefreshList()
    end)
    
        -- Rescan spells button
        local rescanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        rescanBtn:SetSize(80, 24)
        rescanBtn:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
        rescanBtn:SetText("Rescan")
        rescanBtn:SetScript("OnClick", function()
            if UI.RefreshSpellList then
                pcall(UI.RefreshSpellList)
            end
            -- also refresh the ranks for the current selection
            local sname = UIDropDownMenu_GetText(spellDropdown)
            if sname and sname ~= "Select Spell" then UI:RefreshRanks(sname) end
            -- Rescan step IDs & slots to ensure UI shows latest ids and slots
            if Rot and Rot.RescanSpellIds then
                pcall(Rot.RescanSpellIds, Rot)
            end
            if Rot and Rot.RescanStepSlots then
                pcall(Rot.RescanStepSlots, Rot)
            end
            UI:RefreshList()
        end)
        -- Default toggle for auto rescan at login
        Rot.autoRescanOnLogin = Rot.autoRescanOnLogin or false

        -- Debug dump mapping button
        local debugBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        debugBtn:SetSize(60, 20)
        debugBtn:SetPoint("LEFT", rescanBtn, "RIGHT", 6, 0)
        debugBtn:SetText("Dump")
        debugBtn:SetScript("OnClick", function()
            if Rot and Rot.DumpStepMapping then pcall(Rot.DumpStepMapping, Rot) end
        end)
        -- Debug toggle: show scanning logs or not
        local dbgToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        dbgToggle:SetSize(80, 20)
        dbgToggle:SetPoint("LEFT", debugBtn, "RIGHT", 6, 0)
        dbgToggle:SetText("Debug Off")
        dbgToggle:SetScript("OnClick", function(self)
            if NS and NS.Rot then
                NS.Rot.debug = not NS.Rot.debug
                self:SetText(NS.Rot.debug and "Debug On" or "Debug Off")
                print("Rot Debug set to: " .. tostring(NS.Rot.debug))
            else
                -- toggle local UI debug state while Rot isn't available
                local s = not (Rot.debug or false)
                Rot.debug = s
                self:SetText(Rot.debug and "Debug On" or "Debug Off")
                print("Rot Debug set to: " .. tostring(Rot.debug))
            end
        end)
        -- Suggest matches for unmatched steps
        local suggBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        suggBtn:SetSize(80, 20)
        suggBtn:SetPoint("LEFT", dbgToggle, "RIGHT", 6, 0)
        suggBtn:SetText("Suggest")
        suggBtn:SetScript("OnClick", function()
            if Rot and Rot.ReportUnmatchedSteps then pcall(Rot.ReportUnmatchedSteps, Rot) end
        end)

        -- Tiny debug panel anchored to top-right for quick actions
        local debugPanel = CreateFrame("Frame", "JamboRotDebugPanel", frame)
        debugPanel:SetSize(140, 24)
        debugPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)

        local dbgMiniDump = CreateFrame("Button", nil, debugPanel, "UIPanelButtonTemplate")
        dbgMiniDump:SetSize(40, 18)
        dbgMiniDump:SetPoint("LEFT", debugPanel, "LEFT", 0, 0)
        dbgMiniDump:SetText("Dump")
        dbgMiniDump:SetScript("OnClick", function() if Rot and Rot.DumpStepMapping then pcall(Rot.DumpStepMapping, Rot) end end)

        local dbgMiniToggle = CreateFrame("Button", nil, debugPanel, "UIPanelButtonTemplate")
        dbgMiniToggle:SetSize(64, 18)
        dbgMiniToggle:SetPoint("LEFT", dbgMiniDump, "RIGHT", 6, 0)
        dbgMiniToggle:SetText("Debug Off")
        dbgMiniToggle:SetScript("OnClick", function(self)
            if NS and NS.Rot then
                NS.Rot.debug = not NS.Rot.debug
                self:SetText(NS.Rot.debug and "Debug On" or "Debug Off")
            else
                local s = not (Rot.debug or false)
                Rot.debug = s
                self:SetText(Rot.debug and "Debug On" or "Debug Off")
            end
        end)

        local dbgMiniRescan = CreateFrame("Button", nil, debugPanel, "UIPanelButtonTemplate")
        dbgMiniRescan:SetSize(24, 18)
        dbgMiniRescan:SetPoint("LEFT", dbgMiniToggle, "RIGHT", 6, 0)
        dbgMiniRescan:SetText("R")
        dbgMiniRescan:SetScript("OnClick", function() if Rot and Rot.RescanSpellIds then pcall(Rot.RescanSpellIds, Rot) end; if Rot and Rot.RescanStepSlots then pcall(Rot.RescanStepSlots, Rot) end; UI:RefreshList() end)

    --------------------------------------------------------
    -- ROTATION LIST PANEL
    --------------------------------------------------------
    UI:CreateRotationList()
    -- Hook ADDON_LOADED to refresh the spell list if Jambo_Spells loads after Jambo_Rot
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(_, _, arg1)
        if (arg1 == "Jambo_Spells" or arg1 == "Jambo Spells") and UI.RefreshSpellList then
            pcall(UI.RefreshSpellList)
        end
    end)
end

------------------------------------------------------------
-- Build rank dropdown when spell changes
------------------------------------------------------------
function UI:RefreshRanks(spellName)
    local _spells_table = type(Rot.GetAllSpells) == 'function' and (Rot:GetAllSpells() or {}) or {}
    local ranks = _spells_table[spellName]
    -- Determine a detectedId and slotId for this spell (or macro)
    local detectedId = nil
    local slotId = nil
    if ranks and #ranks > 0 then
        for _, rr in ipairs(ranks) do if rr.id then detectedId = rr.id; break end end
        if detectedId then slotId = findSlotForSpellId(detectedId) end
    else
        -- maybe this is a macro; try to find it in macros list
        if type(GetNumMacros) == 'function' then
            local n = GetNumMacros() or 0
            for i = 1, n do
                local mname = select(1, GetMacroInfo(i))
                if mname and mname == spellName then
                    detectedId = i
                    slotId = findSlotForMacroId(i)
                    break
                end
            end
        end
    end

    UIDropDownMenu_Initialize(rankDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        -- Auto ranks
        local autos = {
            "Auto - Best DPS",
            "Auto - Best DPM",
            "Auto - Best HPS",
            "Auto - Best HPM",
        }

        for _, txt in ipairs(autos) do
            local info = UIDropDownMenu_CreateInfo()
            local idText = ""
            local slotText = ""
            local rEntry = nil
            if type(Rot.ResolveRank) == 'function' then
                rEntry = Rot:ResolveRank(spellName, txt)
                if rEntry and rEntry.id then
                    idText = " [id:"..tostring(rEntry.id).."]"
                    local s = findSlotForSpellId(rEntry.id)
                    if s then slotText = " [slot:"..tostring(s).."]" end
                end
            end
            -- Fallback to detectedId/slotId when ResolveRank doesn't yield a rank (eg. macros)
            if (not idText or idText == "") and detectedId then
                idText = " [id:"..tostring(detectedId).."]"
                if slotId then slotText = " [slot:"..tostring(slotId).."]" end
            end
            info.text = txt .. idText .. slotText
            info.arg1 = { autoType = txt, pickedId = rEntry and rEntry.id or nil, pickedRank = rEntry and rEntry.rankIndex or nil }
            info.func = function(_, arg1)
                if type(arg1) == 'table' then
                    UIDropDownMenu_SetText(rankDropdown, arg1.autoType .. (arg1.pickedId and (" [id:" .. tostring(arg1.pickedId) .. "]") or "") .. (arg1.pickedRank and (" [rank:" .. tostring(arg1.pickedRank) .. "]") or ""))
                    rankDropdown.selectedRankIndex = arg1.pickedRank
                    rankDropdown.selectedAutoId = arg1.pickedId
                else
                    UIDropDownMenu_SetText(rankDropdown, arg1)
                end
            end
            UIDropDownMenu_AddButton(info)
        end

        -- Separator line
        info.text = "----- Ranks -----"
        info.func = function() end
        info.notClickable = true
        info.isTitle = true
        UIDropDownMenu_AddButton(info)

        -- All ranks, even unlearned; use rankIndex and rankText from the spell DB and show rank id
        if ranks and #ranks > 0 then
            for _, r in ipairs(ranks) do
            local rankText = r.rankText ~= "" and r.rankText or ("Rank "..(r.rankIndex or "?"))
            local info = UIDropDownMenu_CreateInfo()
            local idText = r.id and (" ["..tostring(r.id).."]") or ""
            local slotText = nil
            if r.id then local s = findSlotForSpellId(r.id) if s then slotText = " [slot:"..tostring(s).."]" end end
            info.text = rankText .. (idText or "") .. (slotText or "")
            -- prefer to pass a numeric rankIndex for selection if present; fallback to rankText for autos
            info.arg1 = r.rankIndex or rankText
            info.func = function(_, arg1)
                -- If we were passed a numeric rankIndex, set the display text to the corresponding rankText
                if type(arg1) == "number" then
                    UIDropDownMenu_SetText(rankDropdown, rankText .. (idText or "") .. (slotText or ""))
                    rankDropdown.selectedRankIndex = arg1
                else
                    UIDropDownMenu_SetText(rankDropdown, arg1)
                    rankDropdown.selectedRankIndex = nil
                end
            end
            UIDropDownMenu_AddButton(info)
            end
        else
            -- If there are no ranks (macro or unknown spell), show a single generic 'Macro' entry if we detected an id
            if detectedId then
                local info = UIDropDownMenu_CreateInfo()
                local display = "Macro"
                local idText = detectedId and (" [id:"..tostring(detectedId).."]") or ""
                local slotText = slotId and (" [slot:"..tostring(slotId).."]") or ""
                info.text = display .. idText .. slotText
                info.arg1 = 0
                info.func = function(_, arg1)
                    UIDropDownMenu_SetText(rankDropdown, display .. idText .. slotText)
                    rankDropdown.selectedRankIndex = nil
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)

    UIDropDownMenu_SetText(rankDropdown, "Rank" .. (detectedId and (" [id:"..tostring(detectedId).."]") or "") .. (slotId and (" [slot:"..tostring(slotId).."]") or ""))
end

------------------------------------------------------------
-- Rotation list (scrolling)
------------------------------------------------------------
function UI:CreateRotationList()
    local scroll = CreateFrame("ScrollFrame", "JamboRotScroll", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -100)
    scroll:SetPoint("BOTTOMRIGHT", -40, 20)

    local rows = {}
    for i=1, 12 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(340, 25)
        row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i-1)*25)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", 5, 0)
        row.text = text

        -- Up
        row.up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.up:SetSize(20, 20)
        row.up:SetPoint("RIGHT", -60, 0)
        row.up:SetText("U")
        row.up:SetScript("OnClick", function()
            Rot:MoveUp(i + scroll.offset)
            UI:RefreshList()
        end)

        -- Down
        row.down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.down:SetSize(20, 20)
        row.down:SetPoint("RIGHT", -30, 0)
        row.down:SetText("D")
        row.down:SetScript("OnClick", function()
            Rot:MoveDown(i + scroll.offset)
            UI:RefreshList()
        end)

        -- Delete
        row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.del:SetSize(20, 20)
        row.del:SetPoint("RIGHT", 0, 0)
        row.del:SetText("X")
        row.del:SetScript("OnClick", function()
            Rot:RemoveStep(i + scroll.offset)
            UI:RefreshList()
        end)

        rows[i] = row
    end

    UI.rows = rows

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 25, function()
            UI:RefreshList()
        end)
    end)

    UI.scroll = scroll
end

------------------------------------------------------------
-- Refresh the rotation display
------------------------------------------------------------
function UI:RefreshList()
    local rot = type(Rot.GetRotation) == 'function' and (Rot:GetRotation() or {}) or {}
    local scroll = UI.scroll
    local rows = UI.rows
    local total = #rot

    FauxScrollFrame_Update(scroll, total, 12, 25)
    local offset = scroll.offset or 0

    for i=1,12 do
        local idx = i + offset
        local row = rows[i]
        if rot[idx] then
            local step = rot[idx]
            -- Evaluate conditions using Rot helper so we can color them PASS/FAIL (default PASS if no conditions)
            local stepAllPass = nil
            local condResults = nil
            if Rot and Rot.EvaluateConditions then
                local ok, allPass, results = pcall(Rot.EvaluateConditions, Rot, step)
                if ok then
                    stepAllPass = allPass
                    condResults = results
                end
            end
            -- default: if no conditions, consider PASS
            if not step.conditions or #step.conditions == 0 then
                stepAllPass = true
            end
            -- Color the row name based on condition pass status
            if stepAllPass == true then
                row.text:SetTextColor(0, 1, 0)
            elseif stepAllPass == false then
                row.text:SetTextColor(1, 0.2, 0.2)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            row:Show()
            local rankLabel = step.rank or (step.rankIndex and ("Rank "..tostring(step.rankIndex)) or "")
            -- Ensure we display a resolved spell id when possible even if not persisted
            local resolvedSpellId = step.spellId
            if not resolvedSpellId and step.rankIndex and Rot and Rot.ResolveRank then
                local resolved = Rot:ResolveRank(step.spell, step.rankIndex or step.rank)
                if resolved and resolved.id then resolvedSpellId = resolved.id end
            end
            local spellIdLabel = resolvedSpellId and (" [id:"..tostring(resolvedSpellId).."]") or ""
            local slotId = step.slotId or findSlotForStep(step)
            local slotLabel = slotId and (" [slot:"..tostring(slotId).."]") or ""
            row.text:SetText(idx..".  "..step.spell..spellIdLabel..slotLabel.." ("..rankLabel..")")
            -- Tooltip to show slot info or spell id
            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(step.spell)
                    if resolvedSpellId then GameTooltip:AddLine("Spell Id: " .. tostring(resolvedSpellId)) end
                    if step.isMacro and step.macroName then GameTooltip:AddLine("Macro: " .. tostring(step.macroName)) end
                if slotId then GameTooltip:AddLine("Slot Id: " .. tostring(slotId)) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            -- CONDITIONS SECTION per-row: show conditions below each row if present
            local condFrame = row.condFrame
            if not condFrame then
                condFrame = CreateFrame("Frame", nil, row)
                condFrame:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
                condFrame:SetSize(300, 1)
                row.condFrame = condFrame
            end

            for _, child in ipairs({ condFrame:GetChildren() }) do
                child:Hide()
            end

            local conditions = step.conditions or {}
            local y = 0
            for condIndex, cond in ipairs(conditions) do
                local line = CreateFrame("Frame", nil, condFrame)
                line:SetPoint("TOPLEFT", 10, -y)
                line:SetSize(260, 18)

                local txt = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", 0, 0)
                local pass = false
                if condResults and condResults[condIndex] then pass = condResults[condIndex].pass end
                local col = pass and "|cff00ff00" or "|cffff3333"
                txt:SetText(string.format("%s- %s = %s|r", col, cond.type, tostring(cond.value)))

                -- Delete condition
                local delBtn = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
                delBtn:SetPoint("RIGHT", 0, 0)
                delBtn:SetSize(18, 18)
                delBtn:SetText("X")
                delBtn:SetScript("OnClick", function()
                    Rot:RemoveCondition(idx, condIndex)
                    UI:RefreshList()
                end)

                line:Show()
                y = y + 18
            end

            -- Add condition button (moved to header) – removed from condFrame

            condFrame:SetHeight(y)
            condFrame:Show()
            -- Create a small '+' add condition button on the header if not present
            if not row.addConditionButton then
                local addCb = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                addCb:SetSize(18, 18)
                addCb:SetPoint("RIGHT", row.up, "LEFT", -6, 0)
                addCb:SetText("+")
                addCb:SetScript("OnClick", function()
                    UI:OpenConditionEditor(idx)
                end)
                addCb:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(addCb, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine("Add Condition")
                    GameTooltip:Show()
                end)
                addCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.addConditionButton = addCb
            else
                row.addConditionButton:Show()
            end
        else
            row:Hide()
            if row.addConditionButton then row.addConditionButton:Hide() end
        end
    end
    -- Update top PASS label, compute first passing step
    local function findFirstPass()
        -- match DataSquare behavior: iterate action slots in order and return the first passing slot
        if type(GetActionInfo) ~= "function" then
            -- fallback to finding first rot step that passes
            local rot = type(Rot.GetRotation) == 'function' and (Rot:GetRotation() or {}) or {}
            for idx, step in ipairs(rot) do
                local ok, allPass, condResults = pcall(Rot.EvaluateConditions, Rot, step)
                if ok and (allPass == true or (not step.conditions or #step.conditions == 0)) then
                    local resolvedSpellId = step.spellId
                    -- If we still don't have a spellId, try to resolve it again
                    if not resolvedSpellId and step.spell and Rot and Rot.ResolveRank and Rot.GetAllSpells then
                        local ranks = Rot:GetAllSpells()[step.spell]
                        if ranks and #ranks > 0 then
                            local r = nil
                            if step.rankIndex then
                                for _, rr in ipairs(ranks) do if rr.rankIndex == step.rankIndex then r = rr; break end end
                            end
                            if not r then r = ranks[#ranks] end
                            if r and r.id then resolvedSpellId = r.id end
                        end
                    end
                    if not resolvedSpellId and step.rankIndex and Rot and Rot.ResolveRank then
                        local resolved = Rot:ResolveRank(step.spell, step.rankIndex or step.rank)
                        if resolved and resolved.id then resolvedSpellId = resolved.id end
                    end
                    local slotId = findSlotForStep(step)
                    return idx, step.spell, resolvedSpellId, slotId
                end
            end
            return nil
        end
        for slot = 1, 120 do
            local atype, id = GetActionInfo(slot)
            if atype == "spell" and id and id > 0 then
                local sname = GetSpellInfo(id)
                if sname then
                    local step = nil
                    if Rot and type(Rot.FindStepForSpell) == 'function' then
                        step = Rot:FindStepForSpell(sname)
                    else
                        -- fallback: iterate rotation and try to match by normalized name
                        local rot = type(Rot.GetRotation) == 'function' and (Rot:GetRotation() or {}) or {}
                        local function norm(s) if not s then return "" end return s:lower():gsub("[^%w]","") end
                        for ri, sStep in ipairs(rot) do
                            if sStep and sStep.spell and norm(sStep.spell) == norm(sname) then
                                step = sStep
                                break
                            end
                        end
                    end
                    if step then
                        local ok, allPass, condResults = pcall(Rot.EvaluateConditions, Rot, step)
                        if ok and (allPass == true or (not step.conditions or #step.conditions == 0)) then
                            local resolvedSpellId = step.spellId
                            if not resolvedSpellId and step.rankIndex and Rot and Rot.ResolveRank then
                                local resolved = Rot:ResolveRank(step.spell, step.rankIndex or step.rank)
                                if resolved and resolved.id then resolvedSpellId = resolved.id end
                            end
                            -- find index of step in rotation
                            local sidx = nil
                            if Rot and type(Rot.FindStepIndexForSpell) == 'function' then
                                local i, st = Rot:FindStepIndexForSpell(step.spell)
                                sidx = i
                            else
                                local rot = type(Rot.GetRotation) == 'function' and (Rot:GetRotation() or {}) or {}
                                for ri, sStep in ipairs(rot) do if sStep == step then sidx = ri; break end end
                            end
                            return sidx, step.spell, resolvedSpellId, slot
                        end
                    end
                end
            elseif atype == "macro" and id and id > 0 then
                local mname = GetMacroInfo(id)
                if mname then
                    local step = nil
                    if Rot and type(Rot.FindStepForSpell) == 'function' then
                        step = Rot:FindStepForSpell(mname)
                    else
                        local rot = type(Rot.GetRotation) == 'function' and (Rot:GetRotation() or {}) or {}
                        local function norm(s) if not s then return "" end return s:lower():gsub("[^%w]","") end
                        for ri, sStep in ipairs(rot) do
                            if sStep and (sStep.spell and norm(sStep.spell) == norm(mname) or (sStep.macroName and norm(sStep.macroName) == norm(mname))) then
                                step = sStep
                                break
                            end
                        end
                    end
                    if step then
                        local ok, allPass, condResults = pcall(Rot.EvaluateConditions, Rot, step)
                        if ok and (allPass == true or (not step.conditions or #step.conditions == 0)) then
                            local resolvedSpellId = step.spellId
                            if not resolvedSpellId and step.rankIndex and Rot and Rot.ResolveRank then
                                local resolved = Rot:ResolveRank(step.spell, step.rankIndex or step.rank)
                                if resolved and resolved.id then resolvedSpellId = resolved.id end
                            end
                            local sidx = nil
                            if Rot and type(Rot.FindStepIndexForSpell) == 'function' then
                                local i, st = Rot:FindStepIndexForSpell(step.spell)
                                sidx = i
                            else
                                local rot = type(Rot.GetRotation) == 'function' and (Rot:GetRotation() or {}) or {}
                                for ri, sStep in ipairs(rot) do if sStep == step then sidx = ri; break end end
                            end
                            return sidx, step.spell, resolvedSpellId, slot
                        end
                    end
                end
            end
        end
        return nil
    end
    local idx, name, sid, slot = findFirstPass()
    if idx then
        local idText = sid and (" [id:"..tostring(sid).."]") or ""
        local slotText = slot and (" [slot:"..tostring(slot).."]") or ""
        -- Prefer to show the slot id (if any), otherwise rotation index
        if slot then
            UI.topPassLabel:SetText("Top PASS: "..tostring(slot).." - "..tostring(name)..idText)
        else
            UI.topPassLabel:SetText("Top PASS: "..tostring(idx)..". "..tostring(name)..idText)
        end
    else
        UI.topPassLabel:SetText("Top PASS: 0")
    end
end

------------------------------------------------------------
-- Public toggle
------------------------------------------------------------
function UI:Toggle()
    if not frame then UI:Create() end
    if frame:IsShown() then
        frame:Hide()
    else
        -- Force rescan/refresh when showing to ensure ranks/spells are up-to-date
        if UI.RefreshSpellList then pcall(UI.RefreshSpellList) end
        -- Also ensure step IDs/slots are rescanned
        if Rot and Rot.RescanSpellIds then pcall(Rot.RescanSpellIds, Rot) end
        if Rot and Rot.RescanStepSlots then pcall(Rot.RescanStepSlots, Rot) end
        UI:RefreshList()
        frame:Show()
    end
end

function UI:Init()
    UI:Create()
    -- Ensure we rescan stored ids and slots so the UI is populated with up-to-date IDs
    if Rot and Rot.RescanSpellIds then pcall(Rot.RescanSpellIds, Rot) end
    if Rot and Rot.RescanStepSlots then pcall(Rot.RescanStepSlots, Rot) end
    UI:RefreshList()
end

-- SLASH: rescan spells for the rotation dropdown
SLASH_JAMBOROT1 = "/rotescan"
SlashCmdList["JAMBOROT"] = function()
    if UI.RefreshSpellList then
        pcall(UI.RefreshSpellList)
        print("Jambo_Rot: Spell list rescanned.")
    else
        print("Jambo_Rot: Refresh not available.")
    end
end
------------------------------------------------------------
-- Condition Editor Popup
------------------------------------------------------------
function UI:OpenConditionEditor(stepIndex)
    if UI.condFrame then UI.condFrame:Hide() end

    local f = CreateFrame("Frame", "JamboRotConditionPopup", UIParent, "BackdropTemplate")
    UI.condFrame = f
    f:SetSize(260, 150)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=1, tileSize=32, edgeSize=32,
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Add Condition")

    --------------------------------------------------------
    -- Condition Type Dropdown
    --------------------------------------------------------
    local typeDD = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
    typeDD:SetPoint("TOPLEFT", 20, -40)
    UIDropDownMenu_SetWidth(typeDD, 160)
    if UIDropDownMenu_SetMaxHeight then UIDropDownMenu_SetMaxHeight(typeDD, 220) end
    UIDropDownMenu_SetText(typeDD, "Condition Type")

    UIDropDownMenu_Initialize(typeDD, function(self)
        for _, c in ipairs(Rot.ConditionTypes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = c.label
            info.arg1 = c.id
            info.arg2 = c.label
            info.func = function(_, arg1, arg2)
                UIDropDownMenu_SetText(typeDD, arg2)
                typeDD.selected = arg1
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    --------------------------------------------------------
    -- Condition Value Dropdown
    --------------------------------------------------------
    local valueDD = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
    valueDD:SetPoint("TOPLEFT", typeDD, "BOTTOMLEFT", 0, -20)
    UIDropDownMenu_SetWidth(valueDD, 160)
    if UIDropDownMenu_SetMaxHeight then UIDropDownMenu_SetMaxHeight(valueDD, 220) end
    UIDropDownMenu_SetText(valueDD, "Value")

    UIDropDownMenu_Initialize(valueDD, function(self)
        if not typeDD.selected then return end
        local values = Rot.ConditionValues[typeDD.selected] or {}
        for _, v in ipairs(values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = v.label
            info.arg1 = v.value
            info.arg2 = v.label
            info.func = function(_, arg1, arg2)
                UIDropDownMenu_SetText(valueDD, arg2)
                valueDD.selected = arg1
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    --------------------------------------------------------
    -- Add Button
    --------------------------------------------------------
    local add = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    add:SetPoint("BOTTOM", 0, 20)
    add:SetSize(100, 24)
    add:SetText("Add")

    add:SetScript("OnClick", function()
        if typeDD.selected and valueDD.selected ~= nil then
            Rot:AddCondition(stepIndex, typeDD.selected, valueDD.selected)
            f:Hide()
            UI:RefreshList()
        end
    end)
end
