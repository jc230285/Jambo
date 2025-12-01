local addonName, J = ...

local ROW_HEIGHT = 24
local MAX_ROWS = 15
local SORT_KEY = "HPS"
local SORT_DESC = true

function J:InitUI()
    if J.frame then return end
    
    local f = CreateFrame("Frame", "JamboSpellsFrame", UIParent, "BackdropTemplate")
    f:SetSize(650, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        edgeFile = "Interface\\Buttons\\WHITE8x8", 
        edgeSize = 1, 
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Header
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -8)
    f.title:SetText("Jambo Spells")
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    
    -- Refresh
    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetSize(80, 22)
    refresh:SetPoint("TOPLEFT", 10, -10)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() J:ScanSpells(); J:ScanBags() end)
    
    -- Export
    local export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    export:SetSize(80, 22)
    export:SetPoint("LEFT", refresh, "RIGHT", 5, 0)
    export:SetText("Export JSON")
    export:SetScript("OnClick", function() J:ExportData() end)

    -- NEW: Square Debug Button
    local debugBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    debugBtn:SetSize(100, 22)
    debugBtn:SetPoint("LEFT", export, "RIGHT", 5, 0)
    debugBtn:SetText("Square Debug")
    debugBtn:SetScript("OnClick", function() 
        if J.ToggleDataDebug then J:ToggleDataDebug() end 
    end)

    -- Headers
    local headers = {
        {name="Name", width=200, key="NAME"},
        {name="HPS", width=60, key="HPS"},
        {name="HPM", width=60, key="HPM"},
        {name="DPS", width=60, key="DPS"},
        {name="DPM", width=60, key="DPM"},
    }
    
    local x = 10
    for _, h in ipairs(headers) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(h.width, 20)
        btn:SetPoint("TOPLEFT", x, -40)
        btn:SetText(h.name)
        btn:SetScript("OnClick", function() 
            if SORT_KEY == h.key then SORT_DESC = not SORT_DESC else SORT_KEY = h.key; SORT_DESC = true end
            J:RefreshUI()
        end)
        x = x + h.width + 2
    end
    
    -- Scroll Frame
    local scroll = CreateFrame("ScrollFrame", "JamboSpellsScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -70)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() J:RefreshUI() end)
    end)
    J.scrollFrame = scroll
    
    -- Rows
    J.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 10, -70 - (i-1)*ROW_HEIGHT)
        row:SetPoint("RIGHT", -30, 0)
        
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 5, 0)
        row.text:SetWidth(200)
        row.text:SetJustifyH("LEFT")
        
        row.stats = {}
        local statX = 205
        for j=1, 4 do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", statX, 0)
            fs:SetWidth(60)
            fs:SetJustifyH("RIGHT")
            table.insert(row.stats, fs)
            statX = statX + 62
        end
        
        row:SetScript("OnEnter", function(self)
            if not self.data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.data.NAME)
            GameTooltip:AddLine(self.data.DESCRIPTION, 1, 1, 1, true)
            GameTooltip:AddDoubleLine("Cast Time:", string.format("%.1fs", self.data.CAST_TIME))
            GameTooltip:AddDoubleLine("Mana:", self.data.COST)
            GameTooltip:AddDoubleLine("Range:", self.data.RANGE.."yd")
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Total Heal:", self.data.HEAL_TOTAL)
            GameTooltip:AddDoubleLine("Total Dmg:", self.data.DMG_TOTAL)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        J.rows[i] = row
    end
    
    J.frame = f
    f:Hide()
end

function J:Toggle()
    if not J.frame then J:InitUI() end
    if J.frame:IsShown() then J.frame:Hide() else J.frame:Show() end
end

function J:RefreshUI()
    if not J.frame or not J.frame:IsShown() then return end
    
    local data = {}
    local maxRanks = {}
    for _, s in ipairs(J.data.spells) do
        if not maxRanks[s.NAME] or s.RANK > maxRanks[s.NAME].RANK then
            maxRanks[s.NAME] = s
        end
    end
    
    for _, s in ipairs(J.data.spells) do
        if maxRanks[s.NAME] and s.RANK == maxRanks[s.NAME].RANK then
            table.insert(data, s)
        end
    end
    
    table.sort(data, function(a,b)
        local v1, v2 = a[SORT_KEY] or 0, b[SORT_KEY] or 0
        if SORT_DESC then return v1 > v2 else return v1 < v2 end
    end)
    
    local offset = FauxScrollFrame_GetOffset(J.scrollFrame) or 0
    
    for i = 1, MAX_ROWS do
        local row = J.rows[i]
        local idx = offset + i
        if idx <= #data then
            local info = data[idx]
            row.data = info
            row:Show()
            row.text:SetText(string.format("%s (R%d)", info.NAME, info.RANK))
            row.stats[1]:SetText(string.format("%.1f", info.HPS))
            row.stats[2]:SetText(string.format("%.1f", info.HPM))
            row.stats[3]:SetText(string.format("%.1f", info.DPS))
            row.stats[4]:SetText(string.format("%.1f", info.DPM))
        else
            row:Hide()
        end
    end
    
    FauxScrollFrame_Update(J.scrollFrame, #data, MAX_ROWS, ROW_HEIGHT)
end