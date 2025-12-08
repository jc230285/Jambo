local ADDON, NS = ...
local C = NS.Constants
local MEDIA = C.MEDIA

NS.UI = NS.UI or {}
local UI = NS.UI

local frame, scroll
local rows = {}

local function SkinFrame(f)
    f:SetBackdrop(nil) 
end

local function SkinConfigPanel(f)
    f:SetBackdrop({
        bgFile = MEDIA.bar, 
        edgeFile = MEDIA.bar, 
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0, 0, 0, 0.85) 
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) 
end

local function SkinSlider(slider)
    if not slider then return end
    local name = slider:GetName()
    if _G[name.."Left"] then _G[name.."Left"]:SetAlpha(0) end
    if _G[name.."Right"] then _G[name.."Right"]:SetAlpha(0) end
    if _G[name.."Middle"] then _G[name.."Middle"]:SetAlpha(0) end
    if slider.NineSlice then slider.NineSlice:SetAlpha(0) end
    
    local bg = slider:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(MEDIA.bar)
    bg:SetVertexColor(0.1, 0.1, 0.1, 1)
    
    local thumb = slider:GetThumbTexture()
    if thumb then 
        thumb:SetTexture(MEDIA.bar)
        thumb:SetSize(8, 16)
        thumb:SetVertexColor(0.2, 0.6, 1, 1) 
    end
end

local function CreateConfigLine(parent, labelText, height)
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(parent:GetWidth(), height or 30)
    
    local label = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 10, 0)
    label:SetWidth(110) 
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    line.label = label
    
    return line
end

-- NEW: Called by Groups.lua on Roster Update
function UI:UpdateSliderLimit(newMax)
    if not frame or not frame.config or not frame.config.deficitHPSlider then return end
    local slider = frame.config.deficitHPSlider
    
    -- Store new max
    slider.dataMax = newMax
    slider:SetMinMaxValues(0, newMax)
    
    -- Preserve the current Deficit Value visually
    local saved = NS.db.options.targetDeficitHP or 0
    
    -- Inverted logic: Left(0) is MaxHP, Right(Max) is 0.
    -- SliderVal = Max - Saved
    local visualVal = newMax - saved
    
    -- Clamp
    if visualVal < 0 then visualVal = 0 end
    if visualVal > newMax then visualVal = newMax end
    
    slider:SetValue(visualVal)
    
    -- Update Labels
    if _G[slider:GetName().."Low"] then _G[slider:GetName().."Low"]:SetText(tostring(newMax)) end
    if _G[slider:GetName().."High"] then _G[slider:GetName().."High"]:SetText("0") end
    if slider.text then slider.text:SetText(saved) end
end

function UI:RedrawRows()
    if not frame or not scroll then return end
    local data = NS.Groups.rowsData or {}
    local offset = FauxScrollFrame_GetOffset(scroll) or 0
    for i = 1, C.MAX_ROWS do
        if not rows[i] then 
            rows[i] = NS.Rows:Create(frame.content) 
            if i == 1 then rows[i]:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, 0)
            else rows[i]:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2) end
        end
        local idx = offset + i
        if idx <= #data then NS.Rows:Update(rows[i], data[idx])
        else rows[i]:Hide() end
    end
    FauxScrollFrame_Update(scroll, #data, C.MAX_ROWS, C.ROW_HEIGHT)
end

function UI:UpdateLayout()
    if not frame then return end
    local show = NS.db.options.showConfig
    
    frame:EnableMouse(show) 
    
    if show then
        frame.config:Show()
        scroll:SetPoint("TOPLEFT", 10, -320) 
        -- Trigger a refresh of the limit just in case
        if NS.Groups.RecalculateLimits then NS.Groups:RecalculateLimits() end
    else
        frame.config:Hide()
        scroll:SetPoint("TOPLEFT", 10, -10)
    end
end

function UI:Init()
    if frame then return end
    
    frame = CreateFrame("Frame", "JamboTargetFrame", UIParent, "BackdropTemplate")
    frame:SetSize(C.FRAME_WIDTH, 600)
    SkinFrame(frame)
    
    local savedPos = NS.db.options.targetFrameOffset
    frame:SetPoint("CENTER", UIParent, "CENTER", savedPos.x, savedPos.y)
    
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing()
        local cx,cy = self:GetCenter()
        local px,py = UIParent:GetCenter()
        if cx then 
            NS.db.options.targetFrameOffset={x=cx-px,y=cy-py}
        end
    end)
    NS.UI.frame = frame
    
    local toggleBtn = CreateFrame("Button", nil, frame)
    toggleBtn:SetSize(16, 16)
    toggleBtn:SetPoint("TOPRIGHT", -8, -8)
    toggleBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    toggleBtn:SetScript("OnClick", function()
        NS.db.options.showConfig = not NS.db.options.showConfig
        UI:UpdateLayout()
    end)

    local config = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    config:SetWidth(C.FRAME_WIDTH - 10) 
    config:SetHeight(280) 
    config:SetPoint("TOP", 0, -30)
    SkinConfigPanel(config)
    frame.config = config

    -- 1. SHOW ALL
    local line1 = CreateConfigLine(config, "Show All Groups:")
    line1:SetPoint("TOPLEFT", 0, -15)
    local cbShow = CreateFrame("CheckButton", nil, line1, "UICheckButtonTemplate")
    cbShow:SetPoint("LEFT", line1.label, "RIGHT", 10, 0)
    cbShow:SetChecked(NS.db.options.showAllGroups)
    cbShow:SetScript("OnClick", function(self)
        NS.db.options.showAllGroups = self:GetChecked()
        NS.Groups:UpdateList()
    end)

    -- 2. ENEMY SORT
    local line2 = CreateConfigLine(config, "Enemy Sort:")
    line2:SetPoint("TOPLEFT", 0, -55)
    local sortDD = CreateFrame("Frame", "JamboSortDD", line2, "UIDropDownMenuTemplate")
    sortDD:SetPoint("LEFT", line2.label, "RIGHT", -20, 0)
    UIDropDownMenu_SetWidth(sortDD, 120)
    local sortOptions = {
        {text="HP (Low -> High)", val=C.SORT_HP_ASC},
        {text="HP (High -> Low)", val=C.SORT_HP_DESC},
        {text="Threat (Low -> High)", val=C.SORT_THREAT_ASC},
        {text="Threat (High -> Low)", val=C.SORT_THREAT_DESC},
    }
    UIDropDownMenu_Initialize(sortDD, function(self)
        for _, o in ipairs(sortOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text
            info.checked = (NS.db.options.enemySortMode == o.val)
            info.func = function() 
                NS.db.options.enemySortMode = o.val
                UIDropDownMenu_SetText(sortDD, o.text)
                NS.Groups:UpdateList() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    local curSort = NS.db.options.enemySortMode or C.SORT_HP_ASC
    for _, o in ipairs(sortOptions) do if o.val == curSort then UIDropDownMenu_SetText(sortDD, o.text) break end end

    -- 3. HEAL SPELL
    local line3 = CreateConfigLine(config, "Heal Spell:")
    line3:SetPoint("TOPLEFT", 0, -95)
    local healDD = CreateFrame("Frame", "JamboHealDD", line3, "UIDropDownMenuTemplate")
    healDD:SetPoint("LEFT", line3.label, "RIGHT", -20, 0)
    UIDropDownMenu_SetWidth(healDD, 120)
    UIDropDownMenu_Initialize(healDD, function(self)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "None"
        info.checked = (NS.db.options.targetHealSpellId == nil)
        info.func = function()
            NS.db.options.targetHealSpellId = nil
            UIDropDownMenu_SetText(healDD, "None")
            NS.Groups:UpdateList()
        end
        UIDropDownMenu_AddButton(info)

        for _, s in ipairs(NS.Spells:BuildList("Heal")) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format("%s (%dyd)", s.name, s.range or 40)
            info.checked = (NS.db.options.targetHealSpellId == s.id)
            info.func = function() 
                NS.db.options.targetHealSpellId = s.id
                UIDropDownMenu_SetText(healDD, s.name)
                NS.Groups:UpdateList() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    local hID = NS.db.options.targetHealSpellId; 
    UIDropDownMenu_SetText(healDD, (hID and GetSpellInfo(hID)) or "None")

    -- 4. HARM SPELL
    local line4 = CreateConfigLine(config, "Harm Spell:")
    line4:SetPoint("TOPLEFT", 0, -135)
    local harmDD = CreateFrame("Frame", "JamboHarmDD", line4, "UIDropDownMenuTemplate")
    harmDD:SetPoint("LEFT", line4.label, "RIGHT", -20, 0)
    UIDropDownMenu_SetWidth(harmDD, 120)
    UIDropDownMenu_Initialize(harmDD, function(self)
        for _, s in ipairs(NS.Spells:BuildList("Harm")) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format("%s (%dyd)", s.name, s.range or 40)
            info.checked = (NS.db.options.targetHarmSpellId == s.id)
            info.func = function() 
                NS.db.options.targetHarmSpellId = s.id
                UIDropDownMenu_SetText(harmDD, s.name)
                NS.Groups:UpdateList() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    local dID = NS.db.options.targetHarmSpellId; UIDropDownMenu_SetText(harmDD, (dID and GetSpellInfo(dID)) or "Select Harm")

    -- 5. HP PERCENT SLIDER
    local line5 = CreateConfigLine(config, "HP % Thresh:", 40)
    line5:SetPoint("TOPLEFT", 0, -180)
    local sPct = CreateFrame("Slider", "JamboDeficitSlider", line5, "OptionsSliderTemplate")
    sPct:SetWidth(150); sPct:SetHeight(16)
    sPct:SetPoint("LEFT", line5.label, "RIGHT", 5, 0)
    sPct:SetMinMaxValues(0, 100); sPct:SetValueStep(1)
    SkinSlider(sPct)
    _G[sPct:GetName().."Low"]:SetText("0%"); _G[sPct:GetName().."High"]:SetText("100%")
    sPct.text = _G[sPct:GetName().."Text"]
    
    sPct:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        if self.text then self.text:SetText(val .. "%") end
        NS.db.options.targetDeficitPercent = val
        _G[C.DB_NAME] = NS.db
        NS.Groups:UpdateList()
    end)
    sPct:SetValue(NS.db.options.targetDeficitPercent or 20)

    -- 6. HP RAW SLIDER (Stand Alone Position)
    local line6 = CreateConfigLine(config, "Deficit HP:", 40)
    line6:SetPoint("TOPLEFT", 0, -225) 
    local sRaw = CreateFrame("Slider", "JamboDeficitHPSlider", line6, "OptionsSliderTemplate")
    sRaw:SetWidth(150); sRaw:SetHeight(16)
    sRaw:SetPoint("LEFT", line6.label, "RIGHT", 5, 0)
    SkinSlider(sRaw)
    
    sRaw.text = _G[sRaw:GetName().."Text"]
    frame.config.deficitHPSlider = sRaw
    
    sRaw:SetScript("OnValueChanged", function(self, value)
        -- Inverted Logic: Value is Left(0)..Right(Max)
        -- Left = MaxDeficit, Right = 0
        local max = self.dataMax or 1000
        local actualSetting = math.floor(max - value)
        
        if actualSetting < 0 then actualSetting = 0 end
        if self.text then self.text:SetText(actualSetting) end
        
        NS.db.options.targetDeficitHP = actualSetting
        _G[C.DB_NAME] = NS.db
        NS.Groups:UpdateList()
    end)

    scroll = CreateFrame("ScrollFrame", "JamboScroll", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -320)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, C.ROW_HEIGHT, UI.RedrawRows)
    end)
    
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(scroll)
    frame.content = content

    UI:UpdateLayout()
    NS.Groups:UpdateList()
end

SLASH_JAMBOTARGET1 = "/jambo"
SlashCmdList["JAMBOTARGET"] = function()
    if not frame then UI:Init() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end