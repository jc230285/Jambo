local ADDON, NS = ...
local C = NS.Constants

NS.Core = {}
NS.units = {} 
NS.events = CreateFrame("Frame")

-- PUBLIC API
_G["JamboTarget"] = {}

-- Priority Map Definitions
local PRIORITY_MAP = {
    [0] = "target",
    [1] = "player",
    [10] = "mouseover",
    [11] = "focus",
    [12] = "pet"
}
for i=1,5 do PRIORITY_MAP[1+i] = "party"..i end
for i=1,40 do PRIORITY_MAP[20+i] = "raid"..i end
for i=1,5 do PRIORITY_MAP[70+i] = "arena"..i end
for i=1,5 do PRIORITY_MAP[80+i] = "boss"..i end
for i=1,40 do PRIORITY_MAP[200+i] = "nameplate"..i end

function JamboTarget:GetUnitID(index)
    return PRIORITY_MAP[tonumber(index)]
end

function JamboTarget:GetUnitIndex(unit)
    if not unit then return 255 end
    return NS:GetUnitIndex(unit)
end

local function mergeDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then dst[k] = mergeDefaults(v, dst[k] or {})
        elseif dst[k] == nil then dst[k] = v end
    end
    return dst
end

function NS.Core:EnsureDB()
    _G[C.DB_NAME] = _G[C.DB_NAME] or {}
    NS.db = mergeDefaults(C.DEFAULTS, _G[C.DB_NAME])
    _G[C.DB_NAME] = NS.db
end

function NS:GetThreatRatio(uid)
    if not UnitExists(uid) or not UnitCanAttack("player", uid) then return 0 end
    if not UnitDetailedThreatSituation then return 0 end
    local isTanking, _, threatPct = UnitDetailedThreatSituation("player", uid)
    return threatPct or 0
end

-- STRICT PRIORITY LOGIC
function NS:GetUnitIndex(uid)
    if not UnitExists(uid) then return 255 end
    
    -- 1. ABSOLUTE PRIORITY: Is this the Target?
    if UnitIsUnit(uid, "target") then return 0 end

    -- 2. Identity Checks
    if UnitIsUnit(uid, "player") then return 1 end
    
    for i=1,5 do 
        if UnitIsUnit(uid, "party"..i) then return 1 + i end 
    end

    -- 3. Secondary Tokens
    if UnitIsUnit(uid, "mouseover") then return 10 end
    if UnitIsUnit(uid, "focus") then return 11 end
    if UnitIsUnit(uid, "pet") then return 12 end

    -- 4. Groups
    for i=1,40 do if UnitIsUnit(uid, "raid"..i) then return 20 + i end end
    for i=1,5 do if UnitIsUnit(uid, "arena"..i) then return 70 + i end end
    for i=1,5 do if UnitIsUnit(uid, "boss"..i) then return 80 + i end end
    
    -- 5. Nameplates
    local npNum = uid:match("^nameplate(%d+)$")
    if npNum then return 200 + tonumber(npNum) end
    
    return 200 
end

local BASE_UNITS = { "player", "target", "targettarget", "mouseover", "focus", "pet" }
local CACHED_GROUPS = {}
for i=1,40 do table.insert(CACHED_GROUPS, "raid"..i); table.insert(CACHED_GROUPS, "raidpet"..i) end
for i=1,5 do table.insert(CACHED_GROUPS, "party"..i); table.insert(CACHED_GROUPS, "partypet"..i) end
for i=1,5 do table.insert(CACHED_GROUPS, "boss"..i); table.insert(CACHED_GROUPS, "arena"..i) end

function NS.Core:ScanUnits()
    -- Use GUID as key to separate entities with same name
    local found = {} 
    
    local function add(uid)
        if not uid or not UnitExists(uid) then return end
        
        local guid = UnitGUID(uid)
        if not guid then return end
        
        local prio = NS:GetUnitIndex(uid)
        -- Visual Override for the "target" token itself in the list
        if uid == "target" then prio = 0 end 

        if found[guid] then
            if prio < found[guid].priority then
                found[guid].unitid = uid
                found[guid].priority = prio
            end
        else
            found[guid] = { unitid = uid, priority = prio }
        end
    end

    for _, uid in ipairs(BASE_UNITS) do add(uid) end
    for _, uid in ipairs(CACHED_GROUPS) do add(uid) end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for i, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if plate.namePlateUnitToken then
                add(plate.namePlateUnitToken)
            end
        end
    end

    NS.units = found
    
    if NS.Groups and NS.Groups.UpdateList then
        NS.Groups:UpdateList()
    end
end

NS.events:RegisterEvent("ADDON_LOADED")
NS.events:RegisterEvent("PLAYER_LOGIN")
NS.events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then NS.Core:EnsureDB()
    elseif event == "PLAYER_LOGIN" then
        if NS.UI and NS.UI.Init then NS.UI:Init() end
        C_Timer.NewTicker(0.5, function() NS.Core:ScanUnits() end)
    end
end)