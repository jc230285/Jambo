local addonName, J = ...

JamboDataSquareDB = JamboDataSquareDB or {}
local db = JamboDataSquareDB
db.size = db.size or 50

J.CurrentActionSlot = 2 
function J:SetActionSlot(slotID)
    J.CurrentActionSlot = tonumber(slotID) or 2
end

local dataSquare = CreateFrame("Button", "JamboDataSquareFrame", UIParent)
local cells = {}
local debugFrame = nil

------------------------------------------------------------
-- EXTENDED DEFINITIONS (17 Fields + Checksum = 18 Bytes)
------------------------------------------------------------
local NUMERIC_FIELD_DEFINITIONS = {
    -- Index 1 is Checksum (Implicit)
    { name = "slotid", min = 0, max = 120 },           -- Index 2
    { name = "target_priority", min = 0, max = 255 },  -- Index 3
    { name = "player_hp", min = 0, max = 255 },        -- Index 4
    { name = "player_resource", min = 0, max = 255 },  -- Index 5
    { name = "player_resource_type", min = 0, max = 255 }, -- Index 6
    { name = "target_hp", min = 0, max = 255 },        -- Index 7
    { name = "target_is_enemy", min = 0, max = 1 },    -- Index 8
    
    -- Extended Data
    { name = "map_id_lo", min = 0, max = 255 },        -- Index 9
    { name = "map_id_hi", min = 0, max = 255 },        -- Index 10
    { name = "coord_x_lo", min = 0, max = 255 },       -- Index 11
    { name = "coord_x_hi", min = 0, max = 255 },       -- Index 12
    { name = "coord_y_lo", min = 0, max = 255 },       -- Index 13
    { name = "coord_y_hi", min = 0, max = 255 },       -- Index 14
    { name = "player_facing", min = 0, max = 255 },    -- Index 15
    { name = "money_lo", min = 0, max = 255 },         -- Index 16
    { name = "money_hi", min = 0, max = 255 },         -- Index 17
    { name = "player_in_combat", min = 0, max = 1 },   -- Index 18
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function percentToByte(current, maximum)
    if not maximum or maximum <= 0 then return 0 end
    local pct = current / maximum
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    return math.floor(pct * 255 + 0.5)
end

local function split16bits(value, maxValue)
    local v = math.floor((value or 0) + 0.5)
    if v < 0 then v = 0 end
    if maxValue and v > maxValue then v = maxValue end
    if v > 65535 then v = 65535 end
    return v % 256, math.floor(v / 256)
end

local function getPlayerMapInfo()
    if not C_Map then return 0, 0, 0 end
    local mapID = C_Map.GetBestMapForUnit("player") or 0
    if mapID == 0 then return 0, 0, 0 end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID, 0, 0 end
    local x, y = pos:GetXY()
    
    local function clamp(val)
        if not val then return 0 end
        local s = math.floor(val * 1000 + 0.5)
        if s < 0 then s = 0 elseif s > 1000 then s = 1000 end
        return s
    end
    return mapID, clamp(x), clamp(y)
end

local function quantizeFacing()
    local facing = GetPlayerFacing() or 0
    local normalized = facing % (2 * math.pi)
    return math.min(255, math.max(0, math.floor((normalized / (2 * math.pi)) * 256 + 0.5)))
end

local function packMoney()
    local money = GetMoney() or 0
    local silver = math.floor(money / 100) 
    if silver > 65025 then silver = 65025 end
    return split16bits(silver, 65025)
end

local function getTargetPriority()
    -- 1. Best Unit from Sorting Logic
    if JamboTarget and JamboTarget.BestUnitIndex then
        return JamboTarget.BestUnitIndex
    end
    
    -- 2. Fallback to Target if exists
    if UnitExists("target") then return 0 end

    return 255
end

------------------------------------------------------------
-- STAT GATHERING
------------------------------------------------------------
local function gatherAutoStats()
    local stats = {}
    
    stats["slotid"] = J.CurrentActionSlot or 2
    stats["target_priority"] = getTargetPriority()

    -- Player
    stats["player_hp"] = percentToByte(UnitHealth("player"), UnitHealthMax("player"))
    local pp, pmax = UnitPower("player") or 0, UnitPowerMax("player") or 0
    stats["player_resource"] = percentToByte(pp, pmax)
    stats["player_resource_type"] = UnitPowerType("player") or 0
    stats["player_in_combat"] = UnitAffectingCombat("player") and 1 or 0

    -- Target
    if UnitExists("target") then
        stats["target_hp"] = percentToByte(UnitHealth("target"), UnitHealthMax("target"))
        stats["target_is_enemy"] = UnitIsEnemy("player", "target") and 1 or 0
    else
        stats["target_hp"] = 0
        stats["target_is_enemy"] = 0
    end
    
    -- Map
    local mapID, x, y = getPlayerMapInfo()
    local mapLo, mapHi = split16bits(mapID, 65025)
    stats["map_id_lo"] = mapLo
    stats["map_id_hi"] = mapHi

    local xLo, xHi = split16bits(x, 1000)
    stats["coord_x_lo"] = xLo
    stats["coord_x_hi"] = xHi

    local yLo, yHi = split16bits(y, 1000)
    stats["coord_y_lo"] = yLo
    stats["coord_y_hi"] = yHi
    
    stats["player_facing"] = quantizeFacing()
    
    -- Money
    local mLo, mHi = packMoney()
    stats["money_lo"] = mLo
    stats["money_hi"] = mHi

    return stats
end

------------------------------------------------------------
-- ENCODING
------------------------------------------------------------
local function updateGrid(payloadValues)
    local bytes = {}
    local checksum = 0
    
    for _, def in ipairs(NUMERIC_FIELD_DEFINITIONS) do
        local val = payloadValues[def.name] or 0
        if val < def.min then val = def.min elseif val > def.max then val = def.max end
        val = math.floor(val)
        table.insert(bytes, val)
        checksum = (checksum + val) % 256
    end
    
    table.insert(bytes, 1, checksum)

    local size = db.size or 50
    if dataSquare:GetWidth() ~= size then
        dataSquare:SetSize(size, size)
    end

    local N = 5 
    local cellSize = math.floor(size / N)

    for i = 1, (N*N) do
        if not cells[i] then cells[i] = dataSquare:CreateTexture(nil, "ARTWORK") end
        local cell = cells[i]
        local row = math.floor((i - 1) / N)
        local col = (i - 1) % N
        cell:ClearAllPoints()
        cell:SetSize(cellSize, cellSize)
        cell:SetPoint("TOPLEFT", dataSquare, "TOPLEFT", col * cellSize, -row * cellSize)
        
        local bIdx = (i - 1) * 3 + 1
        local r = (bytes[bIdx] or 0) / 255
        local g = (bytes[bIdx+1] or 0) / 255
        local b = (bytes[bIdx+2] or 0) / 255
        
        cell:SetColorTexture(r, g, b, 1)
        cell:Show()
    end
end

------------------------------------------------------------
-- DEBUG WINDOW
------------------------------------------------------------
function J:ToggleDataDebug()
    if not debugFrame then
        local f = CreateFrame("Frame", "JamboDataDebug", UIParent, "BackdropTemplate")
        f:SetSize(300, 500)
        f:SetPoint("CENTER")
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        f:SetBackdropBorderColor(0, 0, 0, 1)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -8); title:SetText("Data Square Debug"); title:SetTextColor(0.2, 0.6, 1, 1)
        
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        
        local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 15, -40); text:SetPoint("BOTTOMRIGHT", -15, 15); text:SetJustifyH("LEFT"); text:SetJustifyV("TOP")
        
        f:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            if self.timer < 0.1 then return end
            self.timer = 0
            
            local stats = gatherAutoStats()
            local bytes = {}
            local checksum = 0
            
            for _, def in ipairs(NUMERIC_FIELD_DEFINITIONS) do
                local val = stats[def.name] or 0
                val = math.floor(val)
                table.insert(bytes, val)
                checksum = (checksum + val) % 256
            end
            table.insert(bytes, 1, checksum)
            
            local lines = {}
            table.insert(lines, "|cff00ff00HEX:|r")
            local hex = ""
            for _, b in ipairs(bytes) do hex = hex .. string.format("%02X", b) end
            table.insert(lines, hex)
            
            table.insert(lines, "\n|cff00ff00NUMBERS:|r")
            table.insert(lines, table.concat(bytes, ", "))
            
            table.insert(lines, "\n|cff00ff00FIELDS:|r")
            table.insert(lines, string.format("Checksum: %d", checksum))
            for i, def in ipairs(NUMERIC_FIELD_DEFINITIONS) do
                table.insert(lines, string.format("%s: %d", def.name, stats[def.name] or 0))
            end
            text:SetText(table.concat(lines, "\n"))
        end)
        debugFrame = f
    end
    if debugFrame:IsShown() then debugFrame:Hide() else debugFrame:Show() end
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
local function Init()
    JamboDataSquareDB = JamboDataSquareDB or {}
    local db = JamboDataSquareDB
    db.size = db.size or 50

    if db.point then dataSquare:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    else dataSquare:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    
    dataSquare:SetSize(db.size, db.size)
    dataSquare:SetMovable(true); dataSquare:EnableMouse(true); dataSquare:SetClampedToScreen(true)
    dataSquare:RegisterForDrag("LeftButton"); dataSquare:SetFrameStrata("TOOLTIP"); dataSquare:SetFrameLevel(9999)
    
    dataSquare:SetScript("OnDragStart", dataSquare.StartMoving)
    dataSquare:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing(); local point, _, relativePoint, x, y = self:GetPoint()
        JamboDataSquareDB.point = point; JamboDataSquareDB.relativePoint = relativePoint; JamboDataSquareDB.x = x; JamboDataSquareDB.y = y
    end)
    
    -- CLICK TO TOGGLE DEBUG
    dataSquare:RegisterForClicks("AnyUp")
    dataSquare:SetScript("OnClick", function() 
        if J and J.ToggleDataDebug then J:ToggleDataDebug() end 
    end)
    
    local bg = dataSquare:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 1)
    
    -- Clean White Border
    local borderFrame = CreateFrame("Frame", nil, dataSquare, "BackdropTemplate")
    local borderThick = 2
    borderFrame:SetPoint("TOPLEFT", dataSquare, "TOPLEFT", -borderThick, borderThick)
    borderFrame:SetPoint("BOTTOMRIGHT", dataSquare, "BOTTOMRIGHT", borderThick, -borderThick)
    borderFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = borderThick })
    borderFrame:SetBackdropBorderColor(1, 1, 1, 1)
    
    dataSquare:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer < 0.1 then return end
        self.timer = 0
        local stats = gatherAutoStats()
        updateGrid(stats)
    end)
    dataSquare:Show()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", Init)

SLASH_JSQ1 = "/jsq"
SlashCmdList["JSQ"] = function(msg)
    local val = tonumber(msg)
    if val and val >= 10 then JamboDataSquareDB.size = val; dataSquare:SetSize(val, val) else print("Usage: /jsq 50") end
end