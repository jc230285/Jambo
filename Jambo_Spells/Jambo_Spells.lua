local addonName, J = ...
_G.JamboSpells = J

J.data = { spells = {}, macros = {}, items = {} }
J.classData = { spells = {} } -- Holder for class file data

-- Determine Class
local _, playerClass = UnitClass("player")
J.playerClass = playerClass

-- Global table for class files to inject data into
_G.JamboSpells_SpellDB = {
    spells = {},
    AddSpellsByLevel = function(self, levelData)
        for level, spells in pairs(levelData) do
            for _, spellInfo in ipairs(spells) do
                local id = spellInfo.id
                J.classData.spells[id] = spellInfo
                J.classData.spells[id].levelReq = level
            end
        end
    end
}

-- Public API for other addons
function J:GetSpellData(spellName)
    if not spellName then return nil end
    for _, spell in ipairs(J.data.spells) do
        if spell.NAME == spellName then return spell end
    end
    return nil
end

function J:GetAllSpells()
    return J.data.spells
end

-- Event Handling
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        J:InitUI()
        J:CreateMinimapButton()
        J:ScanSpells()
        J:ScanBags()
    elseif event == "BAG_UPDATE" then
        J:ScanBags()
    else
        J:ScanSpells()
    end
end)