local ADDON, NS = ...

-- NS.UI may not be initialized when this file is loaded; resolve lazily
local function GetUI()
    return NS and NS.UI
end

local function CreateMinimapButton()
    if _G["JamboRotMinimapButton"] then return end

    local btn = CreateFrame("Button", "JamboRotMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("HIGH")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\Ability_Repair")

    local angle = 160
    local radius = 80

    local function UpdatePos()
        local x = math.cos(math.rad(angle)) * radius
        local y = math.sin(math.rad(angle)) * radius
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:SetScript("OnClick", function()
        local ui = GetUI()
        if ui and ui.Toggle then ui:Toggle() end
    end)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx,my = Minimap:GetCenter()
            local cx,cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            cx,cy = cx/s, cy/s
            angle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePos()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdatePos()
    end)

    UpdatePos()
end

CreateMinimapButton()

SLASH_JAMBOROT1 = "/jamrot"
SlashCmdList["JAMBOROT"] = function()
    local ui = GetUI()
    if ui and ui.Toggle then ui:Toggle() end
end
