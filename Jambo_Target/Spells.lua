local ADDON, NS = ...

NS.Spells = {}

-- Helper to find spell range from tooltip or API
local function GetSpellRange(spellID)
    local name = GetSpellInfo(spellID)
    if not name then return nil end
    -- Basic heuristic or API call
    local _, _, _, _, minRange, maxRange = GetSpellInfo(spellID)
    if maxRange and maxRange > 0 then return maxRange end
    return 40 -- Default fallback
end

function NS.Spells:BuildList(tag)
    local out = {}
    local seen = {}
    
    -- 1. Scan Player Spellbook to find actual spells
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSpells do
            local spellType, spellID = GetSpellBookItemInfo(j, "spell")
            if spellType == "SPELL" and spellID then
                local name = GetSpellInfo(spellID)
                if name and not seen[name] then
                    local isHarm = IsHarmfulSpell(j, "spell")
                    local isHelp = IsHelpfulSpell(j, "spell")
                    
                    -- Filter by Tag
                    local add = false
                    if tag == "Harm" and isHarm then add = true end
                    if tag == "Heal" and isHelp then add = true end
                    
                    if add then
                        local range = GetSpellRange(spellID)
                        table.insert(out, { 
                            id = spellID, 
                            name = name, 
                            range = range 
                        })
                        seen[name] = true
                    end
                end
            end
        end
    end

    -- 2. Fallback if Spellbook scan failed (e.g. some Classic versions)
    if #out == 0 then
        local fallback = {}
        if tag == "Heal" then 
            fallback = { {2061,"Flash Heal"}, {139,"Renew"}, {774,"Rejuvenation"}, {635,"Holy Light"}, {8004,"Healing Wave"} }
        elseif tag == "Harm" then 
            fallback = { {585,"Smite"}, {5176,"Wrath"}, {403,"Lightning Bolt"}, {686,"Shadow Bolt"}, {133,"Fireball"}, {172,"Corruption"} } 
        end
        for _, s in ipairs(fallback) do
            if IsSpellKnown(s[1]) then 
                table.insert(out, {id=s[1], name=s[2], range=40}) 
            end
        end
    end

    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end