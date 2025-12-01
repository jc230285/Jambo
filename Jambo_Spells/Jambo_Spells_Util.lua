local addonName, J = ...

function J:CreateMinimapButton()
    if J.MinimapButton then return end
    
    local btn = CreateFrame("Button", "JamboSpellsMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetPoint("CENTER", -12, -80) -- Default pos
    
    btn:SetNormalTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    btn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- Round Border
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    
    -- Drag Logic
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local mx, my = Minimap:GetCenter()
            x, y = x/scale, y/scale
            local angle = math.atan2(y - my, x - mx)
            local r = 80
            self:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
        end)
    end)
    
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    -- Click
    btn:SetScript("OnClick", function()
        if J.Toggle then J:Toggle() end
    end)
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Jambo Spells")
        GameTooltip:AddLine("Click to toggle UI", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    J.MinimapButton = btn
end

function J:ExportData()
    local function serialize(o)
        if type(o) == "number" then return o
        elseif type(o) == "string" then return string.format("%q", o)
        elseif type(o) == "boolean" then return tostring(o)
        elseif type(o) == "table" then
            local s = "{"
            local i = 1
            for k, v in pairs(o) do
                if i > 1 then s = s .. "," end
                s = s .. string.format("%q:%s", k, serialize(v))
                i = i + 1
            end
            return s .. "}"
        else return "null" end
    end
    
    local lines = {}
    for _, s in ipairs(J.data.spells) do
        table.insert(lines, serialize(s))
    end
    
    local json = "[" .. table.concat(lines, ",") .. "]"
    
    local f = CreateFrame("Frame", "JamboExportFrame", UIParent, "DialogBoxFrame")
    f:SetSize(500, 400)
    f:SetPoint("CENTER")
    
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 20)
    
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(450)
    edit:SetText(json)
    edit:HighlightText()
    
    scroll:SetScrollChild(edit)
end