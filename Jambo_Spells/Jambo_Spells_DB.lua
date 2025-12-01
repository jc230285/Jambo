-- Jambo_Spells_DB.lua
local addonName, J = ...
J = _G.JamboSpells

-- Determine the current class for filtering class files
local currentClass = select(2, UnitClass("player"))
local classDB = _G.JamboSpells_SpellDB
if currentClass then
    classDB.currentClass = currentClass
end

-- Helper stub for handling spells that only the highest rank is available
function J:AddOverriddenSpells(...)
    -- Stub logic for rank replacement
end

-- Function used by the class files (like Paladin.lua) to add spell data
function classDB:AddSpellData(level, data)
    for _, spellInfo in ipairs(data) do
        local id = spellInfo.id
        -- Create a base entry if it doesn't exist
        classDB.spells[id] = classDB.spells[id] or {
            id = id,
            levelReq = level,
            cost = spellInfo.cost,
            requiredIds = spellInfo.requiredIds,
            requiredTalentId = spellInfo.requiredTalentId,
            
            -- Defaults matching your required format
            HPS=0, HPM=0, DPS=0, DPM=0,
            HEAL_TOTAL=0, DMG_TOTAL=0, CAST_TIME=0, MANA_COST=0, AURATIME=0, RANGE=0,
            TAGS = {},
            CATEGORY = "Other",
        }
    end
end

-- Function wrapper for the class files to use
function classDB:AddSpellsByLevel(levelData)
    for level, spells in pairs(levelData) do
        classDB:AddSpellData(level, spells)
    end
end