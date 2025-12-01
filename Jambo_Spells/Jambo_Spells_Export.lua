local addonName, J = ...

local function serialize(o)
    if type(o) == "number" then return o
    elseif type(o) == "string" then return string.format("%q", o):gsub("\n", "\\n")
    elseif type(o) == "boolean" then return tostring(o)
    elseif type(o) == "table" then
        local s = ""
        local isArray = (#o > 0)
        if isArray then
            s = "["
            for i, v in ipairs(o) do
                if i > 1 then s = s .. "," end
                s = s .. serialize(v)
            end
            return s .. "]"
        else
            s = "{"
            local first = true
            for k, v in pairs(o) do
                if not first then s = s .. "," end
                s = s .. string.format("%q:%s", tostring(k), serialize(v))
                first = false
            end
            return s .. "}"
        end
    else return "null" end
end

function J:ExportData()
    local json = serialize(J.data.spells)
    
    local f = CreateFrame("Frame", "JamboExportFrame", UIParent, "DialogBoxFrame")
    f:SetSize(600, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    
    if not f.scroll then
        f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 16, -30)
        f.scroll:SetPoint("BOTTOMRIGHT", -30, 16)
        
        f.edit = CreateFrame("EditBox", nil, f.scroll)
        f.edit:SetMultiLine(true)
        f.edit:SetFontObject(ChatFontNormal)
        f.edit:SetWidth(530)
        f.edit:SetAutoFocus(true)
        f.scroll:SetScrollChild(f.edit)
        
        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.close:SetPoint("TOPRIGHT", -5, -5)
    end
    
    f.edit:SetText(json)
    f.edit:HighlightText()
    f:Show()
end
-- Timestamp: 2023-12-04 10:05:00