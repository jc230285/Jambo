local addonName, J = ...
_G.JamboSpells = J

JamboSpellsDB = JamboSpellsDB or {}
local charKey = UnitName("player") .. " - " .. GetRealmName()

J.data = { spells = {} }
J.classData = { spells = {} }
J.SpellsByLevel = {}
J.OverriddenSpells = {}

local _, playerClass = UnitClass("player")
J.currentClass = playerClass
J.playerClass = playerClass

function J:AddOverriddenSpells(...)
    for i = 1, select("#", ...) do
        local spellTable = select(i, ...)
        if type(spellTable) == "table" then
            table.insert(J.OverriddenSpells, spellTable)
        end
    end
end

function J:ProcessClassData()
    local idToInfo = {}
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

    local rankCache = {}
    local function getRank(id, depth)
        if depth > 20 then return 1 end
        if rankCache[id] then return rankCache[id] end
        local info = idToInfo[id]
        if not info then rankCache[id] = 1; return 1 end
        if not info.requiredIds or #info.requiredIds == 0 then
            rankCache[id] = 1; return 1
        end
        local parentID = info.requiredIds[1]
        local r = getRank(parentID, depth + 1) + 1
        rankCache[id] = r
        return r
    end

    for id, info in pairs(idToInfo) do
        local r = getRank(id, 0)
        J.classData.spells[id] = {
            levelReq = info.levelReq, cost = info.cost, id = id, rank = r,
            HEAL_TOTAL = 0, DMG_TOTAL = 0,
        }
    end
    
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

function J:LoadCache()
    if JamboSpellsDB[charKey] then J.data.spells = JamboSpellsDB[charKey] end
end
function J:SaveCache()
    JamboSpellsDB[charKey] = J.data.spells
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED") 

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        J:ProcessClassData()
        J:LoadCache()
        if J.InitUI then J:InitUI() end
        if J.CreateMinimapButton then J:CreateMinimapButton() end
        C_Timer.After(3, function() 
            if J.FullScan then J:FullScan() end 
        end)
        
    elseif event == "PLAYER_LOGOUT" then
        J:SaveCache()
        
    elseif event == "BAG_UPDATE" then
        if not InCombatLockdown() and not J.bagTimer then
            -- DEBUG PRINT
            print("|cff00ccff[Jambo]|r Bag Update Detected - Scheduling Scan...")
            J.bagTimer = C_Timer.NewTimer(2.0, function()
                print("|cff00ccff[Jambo]|r Executing Scheduled Scan...")
                if J.ScanBagsForMacros then J:ScanBagsForMacros() end
                if J.FullScan then J:FullScan() end 
                J.bagTimer = nil
            end)
        end

    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        if not J.scanTimer then
            J.scanTimer = C_Timer.NewTimer(1.0, function()
                if J.FullScan then J:FullScan() end
                J.scanTimer = nil
            end)
        end
        
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if J.ScanBagsForMacros then J:ScanBagsForMacros() end
    end
end)

SLASH_JAMBOSPELLS1 = "/js"
SlashCmdList["JAMBOSPELLS"] = function() J:Toggle() end