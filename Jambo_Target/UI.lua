local ADDON, NS = ...
local C = NS.Constants
local MEDIA = C.MEDIA

NS.UI = NS.UI or {}
local UI = NS.UI

local frame, scroll
local rows = {}

local function SkinFrame(f)
    f:SetBackdrop({
        bgFile = MEDIA.bar, edgeFile = MEDIA.bar, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(unpack(MEDIA.bg))
    f:SetBackdropBorderColor(0, 0, 0, 1)
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
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)
    local thumb = slider:GetThumbTexture()
    if thumb then thumb:SetTexture(MEDIA.bar); thumb:SetSize(8, 16); thumb:SetVertexColor(0.2, 0.6, 1, 1) end
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
    if show then
        frame.config:Show()
        scroll:SetPoint("TOPLEFT", 10, -220) -- Pushed down by stacked config
    else
        frame.config:Hide()
        scroll:SetPoint("TOPLEFT", 10, -30) -- Moved up
    end
end

function UI:Init()
    if frame then return end
    
    frame = CreateFrame("Frame", "JamboTargetFrame", UIParent, "BackdropTemplate")
    frame:SetSize(C.FRAME_WIDTH, 600)
    SkinFrame(frame)
    local savedPos = NS.db.options.targetFrameOffset
    if savedPos then frame:SetPoint("CENTER", UIParent, "CENTER", savedPos.x, savedPos.y)
    else frame:SetPoint("CENTER") end
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing()
        local cx,cy = self:GetCenter()
        local px,py = UIParent:GetCenter()
        if cx then 
            NS.db.options.targetFrameOffset={x=cx-px,y=cy-py}
            print("JamboTargetFrame moved to: CENTER anchored to UIParent at CENTER with offset " .. (cx-px) .. ", " .. (cy-py))
            DEFAULT_CHAT_FRAME:AddMessage("JamboTargetFrame moved to: CENTER anchored to UIParent at CENTER with offset " .. (cx-px) .. ", " .. (cy-py))
        end
    end)
    NS.UI.frame = frame

    -- Header & Toggle Button
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("JAMBO TARGET V3.1")
    title:SetTextColor(unpack(MEDIA.headerColor))
    
    local toggleBtn = CreateFrame("Button", nil, frame)
    toggleBtn:SetSize(16, 16)
    toggleBtn:SetPoint("TOPLEFT", 8, -8)
    toggleBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    toggleBtn:SetScript("OnClick", function()
        NS.db.options.showConfig = not NS.db.options.showConfig
        UI:UpdateLayout()
    end)
    
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- Config Area (Stacked vertically for narrow width)
    local config = CreateFrame("Frame", nil, frame)
    config:SetSize(C.FRAME_WIDTH - 20, 190)
    config:SetPoint("TOP", 0, -30)
    frame.config = config

    -- 1. Threshold %
    local sPct = CreateFrame("Slider", "JamboDeficitSlider", config, "OptionsSliderTemplate")
    sPct:SetWidth(180); sPct:SetPoint("TOP", 0, -10); sPct:SetMinMaxValues(0, 100); sPct:SetValueStep(1)
    sPct.text = _G["JamboDeficitSliderText"]; _G["JamboDeficitSliderLow"]:SetText(""); _G["JamboDeficitSliderHigh"]:SetText("")
    SkinSlider(sPct)
    sPct:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        if self.text then self.text:SetText(string.format("Threshold: %d%%", val)) end
        NS.db.options.targetDeficitPercent = val
        if NS.Groups.UpdateList then NS.Groups:UpdateList() end
    end)
    sPct:SetValue(NS.db.options.targetDeficitPercent or 20)

    -- 2. Deficit HP (Inverted)
    local sRaw = CreateFrame("Slider", "JamboDeficitHPSlider", config, "OptionsSliderTemplate")
    sRaw:SetWidth(180); sRaw:SetPoint("TOP", sPct, "BOTTOM", 0, -20); sRaw:SetMinMaxValues(0, 10000); sRaw:SetValueStep(100)
    sRaw.text = _G["JamboDeficitHPSliderText"]; _G["JamboDeficitHPSliderLow"]:SetText(""); _G["JamboDeficitHPSliderHigh"]:SetText("")
    SkinSlider(sRaw)
    sRaw:SetScript("OnValueChanged", function(self, value)
        local min, max = self:GetMinMaxValues(); local actual = max - value
        if actual < 0 then actual = 0 end
        if self.text then self.text:SetText(string.format("Deficit HP: %d", actual)) end
        NS.db.options.targetDeficitHP = actual
        if NS.Groups.UpdateList then NS.Groups:UpdateList() end
    end)
    frame.config.deficitHPSlider = sRaw
    -- Initial value set in Groups Update

    -- 3. Heal Spell
    local healDD = CreateFrame("Frame", "JamboHealDD", config, "UIDropDownMenuTemplate")
    healDD:SetPoint("TOP", sRaw, "BOTTOM", 0, -10); UIDropDownMenu_SetWidth(healDD, 160)
    UIDropDownMenu_Initialize(healDD, function(self, level)
        for _, s in ipairs(NS.Spells:BuildList("Heal")) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format("%s (%dyd)", s.name, s.range or 40)
            info.arg1 = s.id; info.checked = (NS.db.options.targetHealSpellId == s.id)
            info.func = function(_, arg1) NS.db.options.targetHealSpellId = arg1; UIDropDownMenu_SetText(healDD, s.name); NS.Groups:UpdateList() end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- 4. Harm Spell
    local harmDD = CreateFrame("Frame", "JamboHarmDD", config, "UIDropDownMenuTemplate")
    harmDD:SetPoint("TOP", healDD, "BOTTOM", 0, 0); UIDropDownMenu_SetWidth(harmDD, 160)
    UIDropDownMenu_Initialize(harmDD, function(self, level)
        for _, s in ipairs(NS.Spells:BuildList("Harm")) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format("%s (%dyd)", s.name, s.range or 40)
            info.arg1 = s.id; info.checked = (NS.db.options.targetHarmSpellId == s.id)
            info.func = function(_, arg1) NS.db.options.targetHarmSpellId = arg1; UIDropDownMenu_SetText(harmDD, s.name); NS.Groups:UpdateList() end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- 5. Enemy Sort Dropdown
    local sortDD = CreateFrame("Frame", "JamboSortDD", config, "UIDropDownMenuTemplate")
    sortDD:SetPoint("TOP", harmDD, "BOTTOM", 0, 0); UIDropDownMenu_SetWidth(sortDD, 160)
    UIDropDownMenu_Initialize(sortDD, function(self, level)
        local options = {
            {text="HP (Low -> High)", val=C.SORT_HP_ASC},
            {text="HP (High -> Low)", val=C.SORT_HP_DESC},
            {text="Threat (Low -> High)", val=C.SORT_THREAT_ASC},
            {text="Threat (High -> Low)", val=C.SORT_THREAT_DESC},
        }
        for _, o in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.arg1 = o.val; info.checked = (NS.db.options.enemySortMode == o.val)
            info.func = function(_, arg1) 
                NS.db.options.enemySortMode = arg1; UIDropDownMenu_SetText(sortDD, o.text); NS.Groups:UpdateList() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Initial Texts
    local hID = NS.db.options.targetHealSpellId; UIDropDownMenu_SetText(healDD, (hID and GetSpellInfo(hID)) or "Select Heal")
    local dID = NS.db.options.targetHarmSpellId; UIDropDownMenu_SetText(harmDD, (dID and GetSpellInfo(dID)) or "Select Harm")
    UIDropDownMenu_SetText(sortDD, "Enemy Sort")

    -- Scroll Frame
    scroll = CreateFrame("ScrollFrame", "JamboScroll", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -220)
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

-- Slash
SLASH_JAMBOTARGET1 = "/jambo"
SlashCmdList["JAMBOTARGET"] = function()
    if not frame then UI:Init() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end