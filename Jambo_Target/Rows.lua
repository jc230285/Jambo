local ADDON, NS = ...
local C = NS.Constants
local MEDIA = C.MEDIA
local CLASS_COLORS = RAID_CLASS_COLORS

NS.Rows = {}

local function CreatePixelBorder(f, thickness)
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -thickness, thickness)
    border:SetPoint("BOTTOMRIGHT", thickness, -thickness)
    border:SetFrameLevel(f:GetFrameLevel() + 1)
    border:SetBackdrop({ edgeFile = MEDIA.bar, edgeSize = thickness })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    return border
end

function NS.Rows:Create(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetWidth(C.FRAME_WIDTH - C.SCROLLBAR_WIDTH - 10)
    row:SetHeight(C.ROW_HEIGHT - 2)
    
    -- RESOURCE BAR (Below HP)
    local pp = CreateFrame("StatusBar", nil, row)
    pp:SetHeight(4) -- Few pixels height
    pp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    pp:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    pp:SetStatusBarTexture(MEDIA.bar)
    pp.border = CreatePixelBorder(pp, 1)
    row.pp = pp

    -- HEALTH BAR (Above Resource)
    local hp = CreateFrame("StatusBar", nil, row)
    hp:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    hp:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    hp:SetPoint("BOTTOM", pp, "TOP", 0, 1) -- 1px gap between HP and PP
    hp:SetStatusBarTexture(MEDIA.bar)
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(1)
    hp.border = CreatePixelBorder(hp, 1)
    row.hp = hp
    
    -- Background
    local bg = hp:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(MEDIA.bar)
    bg:SetVertexColor(0.15, 0.15, 0.15, 1)
    hp.bg = bg
    
    -- Background for Power
    local ppBg = pp:CreateTexture(nil, "BACKGROUND")
    ppBg:SetAllPoints()
    ppBg:SetTexture(MEDIA.bar)
    ppBg:SetVertexColor(0.1, 0.1, 0.1, 1)
    pp.bg = ppBg

    -- Status Text (Right Side)
    local status = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("RIGHT", -4, 0)
    status:SetFont(MEDIA.font, 9, "OUTLINE")
    status:SetJustifyH("RIGHT")
    row.status = status

    -- Name Text (Left Side)
    local name = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", 4, 0)
    name:SetPoint("RIGHT", status, "LEFT", -10, 0) 
    name:SetFont(MEDIA.font, 10, "OUTLINE")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false) 
    row.name = name
    
    -- Debuff Icons (Moved to RIGHT SIDE)
    row.icons = {}
    for i=1, 5 do
        local icon = CreateFrame("Frame", nil, row, "BackdropTemplate")
        icon:SetSize(C.ROW_HEIGHT-4, C.ROW_HEIGHT-4)
        if i==1 then 
            icon:SetPoint("LEFT", row, "RIGHT", 4, 0)
        else 
            icon:SetPoint("LEFT", row.icons[i-1], "RIGHT", 2, 0) 
        end
        
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        icon.tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon.border = CreatePixelBorder(icon, 1)
        row.icons[i] = icon
    end

    return row
end

function NS.Rows:Update(row, info)
    row:Show()
    
    if info.isHeader then
        -- Header Styling
        row.hp:SetStatusBarColor(0, 0, 0, 0) -- Transparent bar
        row.hp.border:Hide()
        row.hp.bg:Show()
        row.hp.bg:SetVertexColor(0.2, 0.25, 0.3, 0.9) -- Blue-ish header bg
        
        row.pp:Hide()
        row.pp.border:Hide()
        
        row:EnableMouse(false)
        row.name:SetText(info.text)
        row.name:SetTextColor(unpack(MEDIA.headerColor))
        row.name:SetJustifyH("CENTER")
        row.name:ClearAllPoints()
        row.name:SetAllPoints(row.hp)
        
        row.status:SetText("")
        for _, icon in ipairs(row.icons) do icon:Hide() end
    else
        -- Unit Row Styling
        row:EnableMouse(true)
        row.hp.border:Show()
        row.hp.bg:Show()
        row.hp.bg:SetVertexColor(0.15, 0.15, 0.15, 1) -- Dark bg for bar
        
        row.pp:Show()
        row.pp.border:Show()
        
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetPoint("RIGHT", row.status, "LEFT", -10, 0) 
        row.name:SetJustifyH("LEFT")

        row:SetAttribute("unit", info.uid)
        row:RegisterForClicks("AnyUp")
        row:SetScript("OnClick", function(self) TargetUnit(info.uid) end)
        
        local _, class = UnitClass(info.uid)
        local color = CLASS_COLORS[class] or {r=0.5, g=0.5, b=0.5}
        
        -- FIX: Explicitly set alpha to 1 to prevent "Grey Bar" issue
        row.hp:SetStatusBarColor(color.r, color.g, color.b, 1)
        
        local maxhp = info.maxhp
        if not maxhp or maxhp <= 0 then maxhp = 1 end
        row.hp:SetMinMaxValues(0, maxhp)
        row.hp:SetValue(info.hp)
        
        -- RESOURCE BAR
        local ppCur = UnitPower(info.uid) or 0
        local ppMax = UnitPowerMax(info.uid) or 1
        local pType, pToken = UnitPowerType(info.uid)
        local pColor = PowerBarColor[pToken] or {r=0.5, g=0.5, b=1}
        
        row.pp:SetMinMaxValues(0, ppMax)
        row.pp:SetValue(ppCur)
        row.pp:SetStatusBarColor(pColor.r, pColor.g, pColor.b, 1)
        
        if info.isPriority then
            row.name:SetTextColor(1, 0.85, 0.3)
            if row.hp.border then row.hp.border:SetBackdropBorderColor(1, 0.55, 0.2, 1) end
        else
            row.name:SetTextColor(1,1,1)
            if row.hp.border then row.hp.border:SetBackdropBorderColor(0, 0, 0, 1) end
        end

        row.name:SetText(string.format("|cff00ccff[%d]|r %s |cffaaaaaa(%s)|r", info.priority, info.name, info.uid))
        
        if info.threat > 0 then
            local threatStr = string.format("|cffffaa00[%.0f%%]|r", info.threat)
            row.status:SetText(string.format("%s -%s (%d%%)", threatStr, AbbreviateLargeNumbers(info.deficit), info.pct))
        else
            row.status:SetText(string.format("-%s (%d%%)", AbbreviateLargeNumbers(info.deficit), info.pct))
        end
        
        local iconIdx = 1
        for d=1, 40 do
            local name, icon, _, dtype = UnitDebuff(info.uid, d)
            if not name then break end
            if iconIdx <= 5 then
                row.icons[iconIdx].tex:SetTexture(icon)
                local dc = DebuffTypeColor[dtype] or {r=0.8, g=0, b=0}
                if row.icons[iconIdx].border then
                    row.icons[iconIdx].border:SetBackdropBorderColor(dc.r, dc.g, dc.b, 1)
                end
                row.icons[iconIdx]:Show()
                iconIdx = iconIdx + 1
            end
        end
        for k=iconIdx, 5 do row.icons[k]:Hide() end
    end
end