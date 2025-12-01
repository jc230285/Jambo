local addonName, J = ...
_G.JamboSpells = J

-- Global DB
JamboSpellsDB = JamboSpellsDB or {}
local charKey = UnitName("player") .. " - " .. GetRealmName()

J.data = { spells = {} }
J.classData = { spells = {} }

-- Tables for Class Files
J.SpellsByLevel = {}
J.OverriddenSpells = {}

-- 1. Detect Class
local _, playerClass = UnitClass("player")
J.currentClass = playerClass
J.playerClass = playerClass

-- 2. API for Class Files
function J:AddOverriddenSpells(...)
    for i = 1, select("#", ...) do
        local spellTable = select(i, ...)
        if type(spellTable) == "table" then
            table.insert(J.OverriddenSpells, spellTable)
        end
    end
end

-- 3. Process Class Data (Calculate Ranks)
function J:ProcessClassData()
    local idToInfo = {}
    
    -- A. Map IDs from SpellsByLevel
    if J.SpellsByLevel then
        for level, spellList in pairs(J.SpellsByLevel) do
            for _, info in ipairs(spellList) do
                if info.id then
                    idToInfo[info.id] = info
                    info.levelReq = level
                end
            end
        end
    end

    -- B. Recursive Rank Calculator
    local rankCache = {}
    local function getRank(id, depth)
        if depth > 20 then return 1 end -- Safety break
        if rankCache[id] then return rankCache[id] end
        
        local info = idToInfo[id]
        
        -- If ID not in our DB, assume it's Rank 1
        if not info then 
            rankCache[id] = 1
            return 1 
        end
        
        -- If no requirements, it's Rank 1
        if not info.requiredIds or #info.requiredIds == 0 then
            rankCache[id] = 1
            return 1
        end
        
        -- Recursive check parent
        local parentID = info.requiredIds[1]
        local r = getRank(parentID, depth + 1) + 1
        rankCache[id] = r
        return r
    end

    -- C. Populate Main DB
    for id, info in pairs(idToInfo) do
        local r = getRank(id, 0)
        J.classData.spells[id] = {
            levelReq = info.levelReq,
            cost = info.cost,
            id = id,
            rank = r, -- Calculated Rank
            
            HEAL_TOTAL = 0, DMG_TOTAL = 0, 
            HPS = 0, HPM = 0, DPS = 0, DPM = 0
        }
    end
    
    -- D. Process OverriddenSpells (Explicit Rank Lists)
    if J.OverriddenSpells then
        for _, list in ipairs(J.OverriddenSpells) do
            for r, id in ipairs(list) do
                if not J.classData.spells[id] then
                    J.classData.spells[id] = { id = id, HEAL_TOTAL=0, DMG_TOTAL=0 }
                end
                J.classData.spells[id].rank = r
            end
        end
    end
end

-- 4. Cache Logic
function J:LoadCache()
    if JamboSpellsDB[charKey] then
        J.data.spells = JamboSpellsDB[charKey]
    end
end

function J:SaveCache()
    JamboSpellsDB[charKey] = J.data.spells
end

-- 5. Events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        J:ProcessClassData() -- Run rank calc
        J:LoadCache()
        
        if J.InitUI then J:InitUI() end
        if J.CreateMinimapButton then J:CreateMinimapButton() end
        
        C_Timer.After(3, function() if J.FullScan then J:FullScan() end end)
        
    elseif event == "PLAYER_LOGOUT" then
        J:SaveCache()
        
    elseif event == "BAG_UPDATE" or event == "ACTIONBAR_SLOT_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        if not J.scanTimer then
            J.scanTimer = C_Timer.NewTimer(1.0, function()
                if J.FullScan then J:FullScan() end
                J.scanTimer = nil
            end)
        end
    end
end)

SLASH_JAMBOSPELLS1 = "/js"
SlashCmdList["JAMBOSPELLS"] = function() J:Toggle() end
-- Timestamp: 2023-12-04 10:00:00