local addonName, J = ...

local ROW_HEIGHT = 24
local MAX_ROWS = 15
local SORT_KEY = "HPS"
local SORT_DESC = true

function J:InitUI()
    if J.frame then return end
    
    local f = CreateFrame("Frame", "JamboSpellsFrame", UIParent, "BackdropTemplate")
    f:SetSize(950, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        print("JamboSpellsFrame moved to: " .. point .. " anchored to " .. (relativeTo and relativeTo:GetName() or "UIParent") .. " at " .. relativePoint .. " with offset " .. xOfs .. ", " .. yOfs)
    end)
    
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        edgeFile = "Interface\\Buttons\\WHITE8x8", 
        edgeSize = 1, 
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -8)
    f.title:SetText("Jambo Spells V3")
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    
    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetSize(80, 22)
    refresh:SetPoint("TOPLEFT", 10, -10)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() if J.FullScan then J:FullScan() end end)
    
    local export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    export:SetSize(80, 22)
    export:SetPoint("LEFT", refresh, "RIGHT", 5, 0)
    export:SetText("Export JSON")
    export:SetScript("OnClick", function() if J.ExportData then J:ExportData() end end)

    local headers = {
        {name="Name / Details", width=450, key="NAME"},
        {name="Heal", width=50, key="HEAL_TOTAL"},
        {name="Dmg", width=50, key="DMG_TOTAL"},
        {name="HPS", width=50, key="HPS"},
        {name="HPM", width=50, key="HPM"},
        {name="DPS", width=50, key="DPS"},
        {name="DPM", width=50, key="DPM"},
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
    
    local scroll = CreateFrame("ScrollFrame", "JamboSpellsScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -70)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() J:RefreshUI() end)
    end)
    J.scrollFrame = scroll
    
    J.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 10, -70 - (i-1)*ROW_HEIGHT)
        row:SetPoint("RIGHT", -30, 0)
        
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 5, 0)
        row.text:SetWidth(450)
        row.text:SetJustifyH("LEFT")
        
        row.stats = {}
        local statX = 460
        for j=1, 6 do 
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", statX, 0)
            fs:SetWidth(50)
            fs:SetJustifyH("RIGHT")
            table.insert(row.stats, fs)
            statX = statX + 52
        end
        
        row:SetScript("OnEnter", function(self)
            if not self.data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.data.NAME)
            if self.data.DESC then GameTooltip:AddLine(self.data.DESC, 1, 1, 1, true) end
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
    
    local data = J.data.spells or {}
    
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
            
            local color = "|cffffffff"
            if info.KNOWN == false then color = "|cff808080"
            elseif info.TYPE == "ITEM" then color = "|cff00ff00" 
            elseif info.TYPE == "MACRO" then color = "|cff00aaff" end
            
            -- FORMAT: {NAME} (R{RANK} L{Level}) [{ID}] [{slotid}] [{range}] [{mana}]
            local cRank = "|cffffff00" -- Yellow
            local cID = "|cff666666"   -- Grey
            local cSlot = "|cff00ff00" -- Green
            local cRange = "|cffffaa00"-- Orange
            local cMana = "|cff00ffff" -- Cyan
            
            local slotStr = (info.SLOT > 0) and (cSlot .. "["..info.SLOT.."]|r ") or ""
            local rangeStr = (info.RANGE and info.RANGE > 0) and (cRange .. "["..info.RANGE.."y]|r ") or ""
            local costStr = (info.COST and info.COST > 0) and (cMana .. "["..info.COST.."]|r ") or ""
            local rankStr = cRank .. "(R"..info.RANK.." L"..info.LEVEL..")|r"
            local idStr = cID .. "["..info.ID.."]|r"
            
            local txt = string.format("%s%s|r %s %s%s%s%s", 
                color, info.NAME, rankStr, idStr, slotStr, rangeStr, costStr)
            
            row.text:SetText(txt)
            
            row.stats[1]:SetText(math.floor(info.HEAL_TOTAL))
            row.stats[2]:SetText(math.floor(info.DMG_TOTAL))
            row.stats[3]:SetText(string.format("%.1f", info.HPS))
            row.stats[4]:SetText(string.format("%.1f", info.HPM))
            row.stats[5]:SetText(string.format("%.1f", info.DPS))
            row.stats[6]:SetText(string.format("%.1f", info.DPM))
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(J.scrollFrame, #data, MAX_ROWS, ROW_HEIGHT)
end
-- Timestamp: 2023-12-04 10:05:00