local addonName, addon = ...

-- --- CONFIGURATION ---
local COLS = 12                 -- Items per row
local ICON_SIZE = 34            -- Size of item buttons
local SPACING = 4               -- Space between buttons
local SECTION_SPACING = 24      -- Vertical space between categories
local FRAME_PADDING = 12        -- Padding inside the main window
local FONT_PATH = "Fonts\\FRIZQT__.TTF"

function JamboBags:CreateBagFrame()
    -- 1. Main Window (ElvUI Style Backdrop)
    -- We use BackdropTemplate to ensure backdrops work on all client versions
    local f = CreateFrame("Frame", "JamboBagsMainFrame", UIParent, "BackdropTemplate")
    
    -- ElvUI Style: Solid dark gray background, 1px black border
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.95) 
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Initial Size (will resize dynamically)
    f:SetSize(FRAME_PADDING*2 + (COLS * (ICON_SIZE + SPACING)), 500)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 50)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()

    -- 2. Draggable Title Bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(22)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.15, 0.15, 0.15, 1) -- Lighter header bar

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_PATH, 11, "OUTLINE")
    titleText:SetPoint("CENTER", 0, 0)
    titleText:SetText("Jambo Bags")
    titleText:SetTextColor(1, 0.82, 0) -- Gold Text

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:GetNormalTexture():SetVertexColor(1, 1, 1)
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:GetPushedTexture():SetVertexColor(0.5, 0.5, 0.5)
    closeBtn:SetScript("OnClick", function() JamboBags:Close() end)

    -- 3. Scroll Frame (Holds the shelves)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", FRAME_PADDING, -32)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, FRAME_PADDING)
    
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(f:GetWidth() - 40, 100) 
    scroll:SetScrollChild(content)

    f.Content = content
    JamboBags.Frame = f

    -- Events
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("PLAYER_MONEY")
    f:SetScript("OnEvent", function(self, event)
        if f:IsShown() then JamboBags:RefreshBagView() end
    end)

    -- Object Pools
    f.Buttons = {}
    f.Headers = {}
    f.Dividers = {}
end

-- --- ELEMENT FACTORIES ---

local function GetButton(index)
    local f = JamboBags.Frame
    if not f.Buttons[index] then
        -- Create a clean button without Blizzard templates to strip default art
        local btn = CreateFrame("Button", "JamboItemBtn"..index, f.Content, "ItemButtonTemplate") 
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        
        -- Remove default textures
        btn:SetNormalTexture(nil)
        btn:SetPushedTexture(nil)
        
        -- Custom 1px Border (Backdrop)
        local backdrop = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        backdrop:SetAllPoints()
        backdrop:SetFrameLevel(btn:GetFrameLevel() - 1)
        backdrop:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
        })
        backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        btn.CustomBorder = backdrop

        -- Score Text Overlay
        btn.ScoreText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        btn.ScoreText:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.ScoreText:SetFont(FONT_PATH, 11, "OUTLINE")
        btn.ScoreText:SetTextColor(1, 1, 0) 

        -- BiS Glow Effect
        btn.BisGlow = btn:CreateTexture(nil, "OVERLAY")
        btn.BisGlow:SetAllPoints()
        btn.BisGlow:SetColorTexture(0, 1, 0, 0.15) -- Faint green background
        btn.BisGlow:Hide()

        f.Buttons[index] = btn
    end
    return f.Buttons[index]
end

local function GetHeader(index)
    local f = JamboBags.Frame
    if not f.Headers[index] then
        local h = f.Content:CreateFontString(nil, "ARTWORK")
        h:SetFont(FONT_PATH, 12, "OUTLINE")
        h:SetTextColor(1, 0.82, 0) -- Gold
        h:SetJustifyH("LEFT")
        f.Headers[index] = h
    end
    return f.Headers[index]
end

local function GetDivider(index)
    local f = JamboBags.Frame
    if not f.Dividers[index] then
        local t = f.Content:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(0.3, 0.3, 0.3, 0.5) -- Grey line
        t:SetHeight(1)
        f.Dividers[index] = t
    end
    return f.Dividers[index]
end

-- --- REFRESH LOGIC ---

function JamboBags:RefreshBagView()
    local f = JamboBags.Frame
    if not f or not f:IsShown() then return end

    -- 1. Gather all items
    local items = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                info.bag = bag
                info.slot = slot
                table.insert(items, info)
            end
        end
    end

    -- 2. Determine Spec & Weights
    local currentSpec = nil
    -- Safe check for Retail function
    if GetSpecialization then
        local idx = GetSpecialization()
        if idx then _, currentSpec = GetSpecializationInfo(idx) end
    end
    -- Fallback for Classic
    if not currentSpec then
        local s = addon:GetClassWeights()
        if s and s[1] then currentSpec = s[1].name end
    end

    local bestLoadout = addon.Scoring:GetBestLoadoutForSpec(currentSpec) or {}
    local currentWeights = nil
    for _, spec in ipairs(addon:GetClassWeights()) do
        if spec.name == currentSpec then currentWeights = spec.weights break end
    end

    local function IsBiS(link)
        if not link then return false end
        for _, lItem in pairs(bestLoadout) do
            if lItem and lItem.link == link then return true end
        end
        return false
    end

    -- 3. Sort Items into Sections
    -- Define the shelf layout order here
    local sections = {
        { name = "Quest", items = {} },
        { name = "Hearthstone & Potions", items = {} },
        { name = "BiS Gear", items = {} },
        { name = "Equipment", items = {} },
        { name = "Trade Goods", items = {} },
        { name = "Consumables", items = {} },
        { name = "Junk", items = {} },
        { name = "Other", items = {} },
    }

    for _, item in ipairs(items) do
        local _, _, rarity, _, _, classType, subClassType, _, equipLoc = GetItemInfo(item.hyperlink)
        local added = false

        if rarity == 0 then
            table.insert(sections[7].items, item) -- Junk
            added = true
        elseif IsBiS(item.hyperlink) then
            table.insert(sections[3].items, item) -- BiS
            added = true
        elseif classType == "Quest" then
            table.insert(sections[1].items, item)
            added = true
        elseif classType == "Consumable" or classType == "Item Enhancement" then
            if subClassType == "Potion" or item.itemID == 6948 then
                 table.insert(sections[2].items, item) -- Potions/HS
            else
                 table.insert(sections[6].items, item) -- Food/Other
            end
            added = true
        elseif equipLoc and equipLoc ~= "" then
            table.insert(sections[4].items, item) -- Equipment
            added = true
        elseif classType == "Trade Goods" or classType == "Recipe" then
            table.insert(sections[5].items, item)
            added = true
        end

        if not added then
            table.insert(sections[8].items, item) -- Other
        end
    end

    -- 4. Render the Shelves
    
    -- Hide everything first
    for _, v in pairs(f.Buttons) do v:Hide() end
    for _, v in pairs(f.Headers) do v:Hide() end
    for _, v in pairs(f.Dividers) do v:Hide() end

    local btnCount = 1
    local headerCount = 1
    local cursorY = 0
    local rowWidth = (COLS * (ICON_SIZE + SPACING)) - SPACING

    for _, section in ipairs(sections) do
        if #section.items > 0 then
            
            -- Divider line (skip for first section)
            if cursorY < 0 then
                cursorY = cursorY - 8
                local div = GetDivider(headerCount)
                div:SetPoint("TOPLEFT", f.Content, "TOPLEFT", 0, cursorY)
                div:SetWidth(rowWidth)
                div:Show()
                cursorY = cursorY - 12
            end

            -- Header Text
            local hdr = GetHeader(headerCount)
            hdr:SetText(section.name)
            hdr:SetPoint("TOPLEFT", f.Content, "TOPLEFT", 2, cursorY)
            hdr:Show()
            headerCount = headerCount + 1
            cursorY = cursorY - 18 -- Height of text

            -- Item Grid
            local col = 0
            for _, item in ipairs(section.items) do
                local btn = GetButton(btnCount)
                btnCount = btnCount + 1
                
                -- Position
                local x = col * (ICON_SIZE + SPACING)
                btn:SetPoint("TOPLEFT", f.Content, "TOPLEFT", x, cursorY)
                btn:Show()

                -- Setup Button Data
                btn:SetID(item.slot)
                if btn.SetBagID then btn:SetBagID(item.bag) end
                
                SetItemButtonTexture(btn, item.iconFileID)
                SetItemButtonCount(btn, item.stackCount)
                SetItemButtonQuality(btn, item.quality, item.hyperlink)

                -- Border Color based on Quality
                local r, g, b = C_Item.GetItemQualityColor(item.quality)
                if item.quality > 1 then
                    btn.CustomBorder:SetBackdropBorderColor(r, g, b, 1)
                else
                    btn.CustomBorder:SetBackdropBorderColor(0, 0, 0, 1) -- Black for Common/Poor
                end

                -- Score Overlay
                local score = 0
                if currentWeights then
                     score = addon.Scoring:CalculateItemScore(item.hyperlink, currentWeights)
                end

                if score > 0 then
                    btn.ScoreText:SetText(math.floor(score))
                    btn.ScoreText:Show()
                else
                    btn.ScoreText:Hide()
                end

                -- BiS Highlight
                if section.name == "BiS Gear" then
                    btn.BisGlow:Show()
                else
                    btn.BisGlow:Hide()
                end

                -- Click Actions
                btn:SetScript("OnClick", function(self, button)
                    local bag, slot = item.bag, item.slot
                    if button == "LeftButton" then
                        C_Container.PickupContainerItem(bag, slot)
                    else
                        C_Container.UseContainerItem(bag, slot)
                    end
                end)
                
                -- Tooltip
                btn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetBagItem(item.bag, item.slot)
                    if score > 0 then
                         GameTooltip:AddLine("BiS Score: "..string.format("%.2f", score), 1, 1, 0)
                    end
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                -- Move to next column
                col = col + 1
                if col >= COLS then
                    col = 0
                    cursorY = cursorY - (ICON_SIZE + SPACING)
                end
            end
            
            -- Move cursor down if the row wasn't finished
            if col > 0 then
                cursorY = cursorY - (ICON_SIZE + SPACING)
            end
        end
    end

    f.Content:SetHeight(math.abs(cursorY) + 50)
end
