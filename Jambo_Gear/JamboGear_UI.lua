-- Jambo Gear - Dark Grid UI (Final Polish)
-- Features: No Scrollbar, Top Equip Button, Green(Equipped)/Red(Bank)/Purple(BoE) Highlights

local JG = _G.JamboGear
if not JG then return end

-- ==========================================================
-- 1. STATIC POPUP
-- ==========================================================

StaticPopupDialogs["JAMBOGEAR_ADDSET"] = {
    text = "Enter a name for the new gear set:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        name = name:match("^%s*(.-)%s*$") or "" 
        
        if name == "" then
            JG:Print("Set name cannot be empty.")
            return
        end
        
        local classConfig = JG:GetCurrentClassConfig()
        if not classConfig then return end
        
        classConfig.gearSets = classConfig.gearSets or {}
        if classConfig.gearSets[name] then
            JG:Print("A set named '"..name.."' already exists.")
            return
        end
        
        -- Create new set
        classConfig.gearSets[name] = { 
            meta = { 
                assignedSpec = (JG.GetDefaultSpec and JG:GetDefaultSpec()) or "Default",
                role = "DPS" 
            } 
        }
        
        JG:ScanAndUpdateGear()
        JG:UpdateGUI()
    end,
}

-- ==========================================================
-- 2. STYLING & HELPERS
-- ==========================================================

local SLOT_ORDER = {
    { key = "HeadSlot", label = "Head" },
    { key = "NeckSlot", label = "Neck" },
    { key = "ShoulderSlot", label = "Shoulder" },
    { key = "BackSlot", label = "Back" },
    { key = "ChestSlot", label = "Chest" },
    { key = "WristSlot", label = "Wrist" },
    { key = "HandsSlot", label = "Hands" },
    { key = "WaistSlot", label = "Waist" },
    { key = "LegsSlot", label = "Legs" },
    { key = "FeetSlot", label = "Feet" },
    { key = "Finger0Slot", label = "Ring 1" },
    { key = "Finger1Slot", label = "Ring 2" },
    { key = "Trinket0Slot", label = "Trinket 1" },
    { key = "Trinket1Slot", label = "Trinket 2" },
    { key = "MainHandSlot", label = "Main Hand" },
    { key = "SecondaryHandSlot", label = "Off Hand" },
    { key = "RangedSlot", label = "Ranged" },
}

local BACKDROP_DARK = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local function SkinFrame(f)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop(BACKDROP_DARK)
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

local function SkinButton(btn)
    if not btn.SetBackdrop then Mixin(btn, BackdropTemplateMixin) end
    btn:SetNormalFontObject("GameFontHighlightSmall")
    btn:SetHighlightFontObject("GameFontHighlight")
    btn:SetBackdrop(BACKDROP_DARK)
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)
end

-- ==========================================================
-- 3. MAIN FRAME
-- ==========================================================

function JG:CreateGUI()
    if self.gui then return end
    
    local f = CreateFrame("Frame", "JamboGearFrame", UIParent, "BackdropTemplate")
    f:SetSize(850, 680)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetToplevel(true)
    f:Hide()
    
    SkinFrame(f)

    -- Header
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Jambo Gear Manager")

    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    
    -- Content Area
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", 10, -40)
    f.content:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Initialize Tabs
    self:CreateTabs(f)
    
    -- Initialize Tab Views
    self:CreateGearSetsView(f)
    self:CreateOptionsView(f)

    self.gui = f
    self:SelectTab(1)
end

function JG:CreateTabs(frame)
    frame.tabs = {}
    local tabNames = {"Gear Sets", "Options"}
    
    frame.numTabs = #tabNames
    frame.selectedTab = 1
    
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", "JamboGearFrameTab"..i, frame, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(name)
        tab:SetScript("OnClick", function() JG:SelectTab(i) end)
        
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 2)
        else
            tab:SetPoint("LEFT", _G["JamboGearFrameTab"..(i-1)], "RIGHT", -16, 0)
        end
        frame.tabs[i] = tab
    end
end

function JG:SelectTab(id)
    if not self.gui then return end
    PanelTemplates_SetTab(self.gui, id)
    
    if self.gearSetsContent then self.gearSetsContent:Hide() end
    if self.optionsContent then self.optionsContent:Hide() end
    
    if id == 1 then
        self.gearSetsContent:Show()
        self:UpdateGearSetsTab()
    elseif id == 2 then
        self.optionsContent:Show()
        self:UpdateOptionsTab()
    end
end

function JG:ToggleGUI()
    if not self.gui then self:CreateGUI() end
    if self.gui:IsShown() then self.gui:Hide() else self.gui:Show(); self:UpdateGUI() end
end

function JG:UpdateGUI()
    if self.gui and self.gui:IsShown() then 
        self:UpdateGearSetsTab()
        self:UpdateOptionsTab()
    end
end

-- ==========================================================
-- 4. GEAR SETS VIEW (Grid)
-- ==========================================================

function JG:CreateGearSetsView(frame)
    local content = CreateFrame("Frame", nil, frame.content)
    content:SetAllPoints()
    content:Hide()
    
    -- Add Set Button
    local addBtn = CreateFrame("Button", nil, content)
    SkinButton(addBtn)
    addBtn:SetSize(80, 20)
    addBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    addBtn:SetText("New Set")
    addBtn:SetScript("OnClick", function() StaticPopup_Show("JAMBOGEAR_ADDSET") end)
    
    -- Container for Grid
    local container = CreateFrame("Frame", nil, content)
    container:SetPoint("TOPLEFT", 0, -30)
    container:SetPoint("BOTTOMRIGHT", 0, 0)
    content.container = container
    
    self.gearSetsContent = content
end

function JG:UpdateGearSetsTab()
    if not self.gearSetsContent or not self.gearSetsContent:IsVisible() then return end
    local container = self.gearSetsContent.container
    
    -- Wipe previous
    if container.children then
        for _, c in pairs(container.children) do c:Hide() end
    end
    container.children = {}

    local classConfig = self:GetCurrentClassConfig()
    local sets = {}
    
    -- Only Saved Sets
    if classConfig and classConfig.gearSets then
        for name, data in pairs(classConfig.gearSets) do
            local role = (data.meta and data.meta.role) or "DPS"
            table.insert(sets, { name = name, data = data, role = role })
        end
    end
    table.sort(sets, function(a,b) return a.name < b.name end)

    local COL_WIDTH = 130
    local ROW_HEIGHT = 28
    local HEADER_HEIGHT = 85
    local START_X = 80 
    local START_Y = -10

    -- Left Column Labels
    for i, slot in ipairs(SLOT_ORDER) do
        local fs = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 5, START_Y - HEADER_HEIGHT - ((i-1)*ROW_HEIGHT) - 6)
        fs:SetSize(70, ROW_HEIGHT)
        fs:SetJustifyH("RIGHT")
        fs:SetText(slot.label)
        table.insert(container.children, fs)
    end

    -- Draw Columns
    for colIdx, set in ipairs(sets) do
        local xPos = START_X + ((colIdx-1) * COL_WIDTH)
        
        -- --- HEADER ---
        local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
        header:SetSize(COL_WIDTH-5, HEADER_HEIGHT)
        header:SetPoint("TOPLEFT", xPos, START_Y)
        header:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        header:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        header:SetBackdropBorderColor(0, 0, 0, 1)
        table.insert(container.children, header)

        -- Role Icon
        local roleBtn = CreateFrame("Button", nil, header)
        roleBtn:SetSize(18, 18)
        roleBtn:SetPoint("TOPLEFT", 5, -5)
        local roleTex = roleBtn:CreateTexture(nil, "ARTWORK")
        roleTex:SetAllPoints()
        
        if set.role == "Tank" then roleTex:SetTexture("Interface\\Icons\\Ability_Defend")
        elseif set.role == "Healer" then roleTex:SetTexture("Interface\\Icons\\Spell_Holy_HolyBolt")
        else roleTex:SetTexture("Interface\\Icons\\Ability_DualWield") end 
        
        roleBtn:SetScript("OnClick", function()
            local roles = {"DPS", "Tank", "Healer"}
            local current = set.role or "DPS"
            local nextIdx = 1
            for k,v in ipairs(roles) do if v == current then nextIdx = k + 1 end end
            if nextIdx > 3 then nextIdx = 1 end
            
            set.data.meta = set.data.meta or {}
            set.data.meta.role = roles[nextIdx]
            JG:UpdateGearSetsTab()
        end)
        table.insert(container.children, roleBtn)

        -- Set Name
        local nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", roleBtn, "RIGHT", 5, 0)
        nameText:SetPoint("TOP", 0, -8)
        nameText:SetText(set.name)

        -- Delete (X)
        local delBtn = CreateFrame("Button", nil, header)
        delBtn:SetSize(14,14)
        delBtn:SetPoint("TOPRIGHT", -2, -2)
        delBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        delBtn:SetScript("OnClick", function()
            classConfig.gearSets[set.name] = nil
            JG:UpdateGearSetsTab()
        end)
        table.insert(container.children, delBtn)

        -- Spec/Weights Toggle
        local currentSpec = (set.data and set.data.meta and set.data.meta.assignedSpec) or "Default"
        local specBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
        specBtn:SetSize(COL_WIDTH-10, 16)
        specBtn:SetPoint("TOP", header, "TOP", 0, -26)
        specBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground"})
        specBtn:SetBackdropColor(0,0,0,0.3)
        local specLabel = specBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        specLabel:SetPoint("CENTER")
        specLabel:SetText(currentSpec)
        
        specBtn:SetScript("OnClick", function()
            local specs = JG.ClassSpecs[JG.playerClass] or {}
            local nextIdx = 1
            for k,v in ipairs(specs) do if v.name == currentSpec then nextIdx = k + 1 end end
            if nextIdx > #specs then nextIdx = 1 end
            local newSpec = specs[nextIdx].name
            set.data.meta = set.data.meta or {}
            set.data.meta.assignedSpec = newSpec
            JG:ScanAndUpdateGear()
            JG:UpdateGearSetsTab()
        end)
        table.insert(container.children, specBtn)

        -- EQUIP BUTTON
        local equipBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
        equipBtn:SetSize(COL_WIDTH-10, 20)
        equipBtn:SetPoint("BOTTOM", header, "BOTTOM", 0, 5)
        equipBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        equipBtn:SetBackdropColor(0.2, 0.4, 0.8, 0.6)
        equipBtn:SetBackdropBorderColor(0,0,0,1)
        
        local btnTxt = equipBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btnTxt:SetPoint("CENTER")
        btnTxt:SetText("Equip Set")
        equipBtn:SetScript("OnClick", function() JG:SwapToOptimalGear(set.name) end)
        equipBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.5, 0.9, 0.8) end)
        equipBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.4, 0.8, 0.6) end)
        table.insert(container.children, equipBtn)

        -- --- GRID CELLS ---
        for rowIdx, slot in ipairs(SLOT_ORDER) do
            local yPos = START_Y - HEADER_HEIGHT - ((rowIdx-1)*ROW_HEIGHT)
            
            local itemData = set.data and set.data[slot.key]
            local link = itemData and itemData.link
            
            -- STATUS CHECKS
            local isEquipped = false
            local isBank = itemData and itemData.isBank
            local isUnbound = false
            
            if link then
                local slotID = GetInventorySlotInfo(slot.key)
                local currentLink = GetInventoryItemLink("player", slotID)
                if currentLink then
                    local cID = currentLink:match("item:(%d+)")
                    local sID = link:match("item:(%d+)")
                    if cID == sID then isEquipped = true end
                end
                
                -- Check BoE
                if itemData then
                     local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(link)
                     if (bindType == 2 or bindType == 3) and not itemData.isBound then
                         isUnbound = true
                     end
                end
            end

            local cell = CreateFrame("Frame", nil, container, "BackdropTemplate")
            cell:SetSize(COL_WIDTH-5, ROW_HEIGHT-2)
            cell:SetPoint("TOPLEFT", xPos, yPos)
            cell:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            
            -- COLOR LOGIC: Green (Equipped) > Purple (Unbound BoE) > Red (Bank) > Dark (Normal)
            if isEquipped then
                cell:SetBackdropColor(0.1, 0.4, 0.1, 0.6) -- Green Hue
            elseif isUnbound then
                 cell:SetBackdropColor(0.5, 0.2, 0.6, 0.6) -- Purple Hue
            elseif isBank then
                cell:SetBackdropColor(0.4, 0.1, 0.1, 0.6) -- Red Hue
            else
                cell:SetBackdropColor(0.1, 0.1, 0.1, 0.5) -- Default Dark
            end
            
            cell:SetBackdropBorderColor(0, 0, 0, 1)
            table.insert(container.children, cell)

            if link then
                local icon = cell:CreateTexture(nil, "ARTWORK")
                icon:SetSize(ROW_HEIGHT-4, ROW_HEIGHT-4)
                icon:SetPoint("LEFT", 2, 0)
                icon:SetTexture(GetItemIcon(link))

                local txt = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", icon, "RIGHT", 5, 0)
                txt:SetPoint("RIGHT", -2, 0)
                txt:SetText(GetItemInfo(link) or "Loading...")
                txt:SetJustifyH("LEFT")

                cell:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(link)
                    GameTooltip:Show()
                end)
                cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                cell:SetScript("OnMouseDown", function()
                    if link then JG:EquipItem(itemData, slot.key) end
                end)
            else
                local txt = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                txt:SetPoint("CENTER")
                txt:SetText("-")
            end
        end
    end
end

-- ==========================================================
-- 5. OPTIONS VIEW
-- ==========================================================

function JG:CreateOptionsView(frame)
    local content = CreateFrame("Frame", nil, frame.content)
    content:SetAllPoints()
    content:Hide()
    
    local y = -20
    local x = 20

    local function CreateCheck(label, key, tooltip)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        cb.text:SetText(label)
        
        cb:SetScript("OnClick", function(self)
            JG.db.profile[key] = self:GetChecked()
            if key == "showOverlays" then
                if self:GetChecked() then JG:UpdateAllContainerFrameOverlays() end
            end
        end)
        
        if tooltip then
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        content[key.."Check"] = cb
        y = y - 35
        return cb
    end

    CreateCheck("Enable Jambo Gear", "enabled", "Toggle the entire addon functionality.")
    CreateCheck("Auto-swap gear leaving combat", "autoSwap", "Queue gear swaps during combat to occur immediately after.")
    CreateCheck("Auto-equip on Talent Change", "autoEquipOnRoleChange", "Automatically switch gear sets when you respec your talents.")
    CreateCheck("Auto-equip upgrades on loot", "autoEquipOnLoot", "If you loot an item that is an upgrade for your current Role, equip it immediately (Out of Combat).")
    CreateCheck("Show chat messages", "showMessages", "Print details to chat window when swapping gear.")
    CreateCheck("Show Best-Spec bag overlays", "showOverlays", "Display icons on bag items indicating best spec.")
    
    self.optionsContent = content
end

function JG:UpdateOptionsTab()
    if not self.optionsContent then return end
    
    self.optionsContent.enabledCheck:SetChecked(JG.db.profile.enabled)
    self.optionsContent.autoSwapCheck:SetChecked(JG.db.profile.autoSwap)
    self.optionsContent.autoEquipOnRoleChangeCheck:SetChecked(JG.db.profile.autoEquipOnRoleChange)
    self.optionsContent.autoEquipOnLootCheck:SetChecked(JG.db.profile.autoEquipOnLoot)
    self.optionsContent.showMessagesCheck:SetChecked(JG.db.profile.showMessages)
    self.optionsContent.showOverlaysCheck:SetChecked(JG.db.profile.showOverlays)
end