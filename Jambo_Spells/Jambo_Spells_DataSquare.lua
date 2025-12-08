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

-- 17 Fields + Checksum = 18 Bytes
local NUMERIC_FIELD_DEFINITIONS = {
    { name = "slotid", min = 0, max = 120 },
    { name = "target_priority", min = 0, max = 255 },
    { name = "player_hp", min = 0, max = 255 },
    { name = "player_resource", min = 0, max = 255 },
    { name = "player_resource_type", min = 0, max = 255 },
    { name = "target_hp", min = 0, max = 255 },
    { name = "target_is_enemy", min = 0, max = 1 },
    { name = "map_id_lo", min = 0, max = 255 },
    { name = "map_id_hi", min = 0, max = 255 },
    { name = "coord_x_lo", min = 0, max = 255 },
    { name = "coord_x_hi", min = 0, max = 255 },
    { name = "coord_y_lo", min = 0, max = 255 },
    { name = "coord_y_hi", min = 0, max = 255 },
    { name = "player_facing", min = 0, max = 255 },
    { name = "money_lo", min = 0, max = 255 },
    { name = "money_hi", min = 0, max = 255 },
    { name = "player_in_combat", min = 0, max = 1 },
}

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
    if JamboTarget and JamboTarget.BestUnitIndex then
        return JamboTarget.BestUnitIndex
    end
    if UnitExists("target") then return 0 end
    return 255
end

local function gatherAutoStats()
    local stats = {}
    
    stats["slotid"] = J.CurrentActionSlot or 2
    stats["target_priority"] = getTargetPriority()

    stats["player_hp"] = percentToByte(UnitHealth("player"), UnitHealthMax("player"))
    local pp, pmax = UnitPower("player") or 0, UnitPowerMax("player") or 0
    stats["player_resource"] = percentToByte(pp, pmax)
    stats["player_resource_type"] = UnitPowerType("player") or 0
    stats["player_in_combat"] = UnitAffectingCombat("player") and 1 or 0

    if UnitExists("target") then
        stats["target_hp"] = percentToByte(UnitHealth("target"), UnitHealthMax("target"))
        stats["target_is_enemy"] = UnitIsEnemy("player", "target") and 1 or 0
    else
        stats["target_hp"] = 0
        stats["target_is_enemy"] = 0
    end
    
    local mapID, x, y = getPlayerMapInfo()
    -- If the target priority is a nameplate and is friendly, offset the mapID by +25
    local bestIdx = stats["target_priority"]
    if bestIdx and bestIdx >= 200 and JamboTarget and JamboTarget.GetUnitID then
        local uid = JamboTarget:GetUnitID(bestIdx)
        -- Only add offset if the unit is a nameplate AND friendly, and if mapID is valid (> 0)
        if uid and UnitExists(uid) and tostring(uid):match("^nameplate%d+$") and UnitIsFriend("player", uid) then
            if mapID and mapID > 0 then
                local original = mapID
                mapID = mapID + 25
                -- Debugging: If JamboDataSquareDB.debug is set we print a throttled message so you can confirm
                if JamboDataSquareDB and JamboDataSquareDB.debug then
                    ds_debug_time = ds_debug_time or 0
                    if (GetTime() - ds_debug_time) > 1 then
                        print(string.format("[JamboDataSquare] Friendly nameplate offset applied. mapID: %d -> %d (bestIdx=%s uid=%s)", original, mapID, tostring(bestIdx), tostring(uid)))
                        ds_debug_time = GetTime()
                    end
                end
            end
        end
    end
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
    
    local mLo, mHi = packMoney()
    stats["money_lo"] = mLo
    stats["money_hi"] = mHi

    return stats
end

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

    -- Use local size, but update if DB changes externally
    local size = JamboDataSquareDB.size or 50
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

function J:ToggleDataDebug()
    -- (Debug window code omitted for brevity, use previous version if needed)
end

local function Init()
    -- LOAD DB CORRECTLY
    JamboDataSquareDB = JamboDataSquareDB or {}
    local db = JamboDataSquareDB
    db.size = db.size or 50

    if db.point then
        dataSquare:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    else
        dataSquare:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 6, -1)
    end

    dataSquare:SetSize(db.size, db.size)
    dataSquare:SetMovable(true)
    dataSquare:EnableMouse(true)
    dataSquare:SetClampedToScreen(true)
    dataSquare:RegisterForDrag("LeftButton")
    dataSquare:SetFrameStrata("TOOLTIP")
    dataSquare:SetFrameLevel(9999)
    
    dataSquare:SetScript("OnDragStart", function(self) print("DataSquare drag start"); dataSquare.StartMoving(self) end)
    dataSquare:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        -- Save to GLOBAL DB
        JamboDataSquareDB.point = point
        JamboDataSquareDB.relativePoint = relativePoint
        JamboDataSquareDB.x = x
        JamboDataSquareDB.y = y
        print("DataSquare moved to: " .. point .. " anchored to " .. relativePoint .. " at " .. x .. ", " .. y)
        DEFAULT_CHAT_FRAME:AddMessage("DataSquare moved to: " .. point .. " anchored to " .. relativePoint .. " at " .. x .. ", " .. y)
    end)
    
    dataSquare:RegisterForClicks("AnyUp")
    dataSquare:SetScript("OnClick", function() if J and J.Toggle then J:Toggle() end end)
    
    local bg = dataSquare:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 1)
    
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
-- Timestamp: 2023-12-04 10:10:00