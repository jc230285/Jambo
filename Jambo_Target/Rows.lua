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
    
    local hp = CreateFrame("StatusBar", nil, row)
    hp:SetAllPoints()
    hp:SetStatusBarTexture(MEDIA.bar)
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(1)
    hp.border = CreatePixelBorder(hp, 1)
    row.hp = hp
    
    local bg = hp:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(MEDIA.bar)
    bg:SetVertexColor(0.15, 0.15, 0.15, 1)
    hp.bg = bg

    -- Status Text (Right Side)
    local status = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("RIGHT", -4, 0)
    status:SetFont(MEDIA.font, 9, "OUTLINE")
    status:SetJustifyH("RIGHT")
    row.status = status

    -- Name Text (Left Side, Truncated)
    local name = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", 4, 0)
    name:SetPoint("RIGHT", status, "LEFT", -10, 0) -- Anchor to status so it truncates
    name:SetFont(MEDIA.font, 10, "OUTLINE")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false) -- Ensure truncation
    row.name = name
    
    row.icons = {}
    for i=1, 5 do
        local icon = CreateFrame("Frame", nil, row, "BackdropTemplate")
        icon:SetSize(C.ROW_HEIGHT-4, C.ROW_HEIGHT-4)
        if i==1 then icon:SetPoint("RIGHT", row, "LEFT", -4, 0)
        else icon:SetPoint("RIGHT", row.icons[i-1], "LEFT", -2, 0) end
        
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
        row.hp:SetStatusBarColor(0,0,0,0)
        row.hp.border:Hide()
        row.hp.bg:Hide()
        row:EnableMouse(false)
        row.name:SetText(info.text)
        row.name:SetTextColor(unpack(MEDIA.headerColor))
        row.status:SetText("")
        for _, icon in ipairs(row.icons) do icon:Hide() end
    else
        row:EnableMouse(true)
        row.hp.border:Show()
        row.hp.bg:Show()
        
        row:SetAttribute("unit", info.uid)
        row:RegisterForClicks("AnyUp")
        row:SetScript("OnClick", function(self) TargetUnit(info.uid) end)
        
        local _, class = UnitClass(info.uid)
        local color = CLASS_COLORS[class] or {r=0.5, g=0.5, b=0.5}
        row.hp:SetStatusBarColor(color.r, color.g, color.b)
        row.hp:SetMinMaxValues(0, info.maxhp)
        row.hp:SetValue(info.hp)
        
        -- NAME: [Index] Name (Truncated by layout)
        row.name:SetTextColor(1,1,1)
        row.name:SetText(string.format("|cff00ccff[%d]|r %s", info.priority, info.name))
        
        -- STATUS TEXT
        if info.groupType == "ENEMY" then
            -- Threat formatting
            local threatStr = ""
            if info.threat >= 100 then
                threatStr = "|cffff0000[AGGRO]|r"
            elseif info.threat > 0 then
                threatStr = string.format("|cffffaa00[%.0f%%]|r", info.threat)
            end
            
            -- Show Threat + HP
            row.status:SetText(string.format("%s %s (%d%%)", threatStr, AbbreviateLargeNumbers(info.hp), info.pct))
        else
            -- Show Deficit
            row.status:SetText(string.format("-%s (%d%%)", AbbreviateLargeNumbers(info.deficit), info.pct))
        end
        
        -- Auras
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