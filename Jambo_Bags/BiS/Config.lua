local addonName, addon = ...

function JamboBags:OpenWeightEditor()
    local f = JamboBagsConfigFrame or CreateFrame("Frame", "JamboBagsConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(600, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Title:SetPoint("CENTER", f.TitleBg, "CENTER", 0, 0)
    f.Title:SetText("Jambo_Bags BiS Weights")

    -- Dropdown for Spec selection (simplified as buttons for now)
    local specs = addon:GetClassWeights()
    local yOffset = -40
    
    if not specs then return end

    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(550, 1000)
    scrollFrame:SetScrollChild(content)

    for i, spec in ipairs(specs) do
        local specLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        specLabel:SetPoint("TOPLEFT", 10, yOffset)
        specLabel:SetText(spec.name)
        yOffset = yOffset - 25

        for stat, weight in pairs(spec.weights) do
            local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", 20, yOffset)
            label:SetText(stat)
            
            local editBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
            editBox:SetSize(60, 20)
            editBox:SetPoint("LEFT", label, "RIGHT", 10, 0)
            editBox:SetText(tostring(weight))
            editBox:SetAutoFocus(false)
            
            editBox:SetScript("OnEnterPressed", function(self)
                local val = tonumber(self:GetText())
                if val then
                    JamboBagsDB.customWeights[addon.MyClass][i].weights[stat] = val
                    self:ClearFocus()
                    print("Updated " .. stat .. " for " .. spec.name)
                end
            end)
            
            yOffset = yOffset - 25
        end
        yOffset = yOffset - 20
    end
    
    f:Show()
end

SLASH_JAMBOBAGS1 = "/jambo"
SlashCmdList["JAMBOBAGS"] = function(msg)
    JamboBags:OpenWeightEditor()
end