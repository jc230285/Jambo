local addonName, J = ...

-- Tooltip scanner
local tooltip = CreateFrame("GameTooltip", "JamboScanTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function GetSpellTooltipData(id)
    tooltip:ClearLines()
    tooltip:SetSpellByID(id)
    local desc = (JamboScanTooltipTextLeft2 and JamboScanTooltipTextLeft2:GetText()) or ""
    
    local heal = 0
    local dmg = 0
    
    -- Parse Tooltip Text
    local h1, h2 = string.match(desc, "Heals.-for (%d+).-to (%d+)")
    if not h1 then h1 = string.match(desc, "Heals.-for (%d+)") end
    
    local d1, d2 = string.match(desc, "Deals.-(%d+).-to (%d+)")
    if not d1 then d1 = string.match(desc, "Deals.-(%d+)") end
    if not d1 then d1 = string.match(desc, "(%d+) .- damage") end
    
    if h1 then heal = h2 and (tonumber(h1)+tonumber(h2))/2 or tonumber(h1) end
    if d1 then dmg = d2 and (tonumber(d1)+tonumber(d2))/2 or tonumber(d1) end
    
    return desc, heal, dmg
end

function J:ScanSpells()
    local spells = {}
    
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSpells do
            local type, id = GetSpellBookItemInfo(j, "spell")
            if type == "SPELL" and id then
                local name, rankText = GetSpellInfo(id)
                local rank = tonumber(string.match(rankText or "", "(%d+)")) or 1
                
                local dbData = J.classData.spells[id] or {}
                local desc, scrapeHeal, scrapeDmg = GetSpellTooltipData(id)
                
                -- Cost
                local cost = dbData.cost or 0
                if cost == 0 then
                    local costs = GetSpellPowerCost(id)
                    if costs and costs[1] then cost = costs[1].cost end
                end
                
                -- Cast Time (default to 1.5 if instant/missing to avoid div by zero)
                local castTime = dbData.castTime or 0
                if castTime == 0 then
                    local _, _, _, castMS = GetSpellInfo(id)
                    castTime = (castMS or 0) / 1000
                    if castTime == 0 then castTime = 1.5 end 
                end
                
                -- Heal/Dmg Values
                local heal = dbData.HEAL_TOTAL or 0
                if heal == 0 then heal = scrapeHeal end
                
                local dmg = dbData.DMG_TOTAL or 0
                if dmg == 0 then dmg = scrapeDmg end
                
                -- Calculations
                local hps = (castTime > 0) and (heal / castTime) or 0
                local dps = (castTime > 0) and (dmg / castTime) or 0
                local hpm = (cost > 0) and (heal / cost) or 0
                local dpm = (cost > 0) and (dmg / cost) or 0

                local entry = {
                    TYPE = "SPELL", NAME = name, SPELLID = id, RANK = rank,
                    LEVEL = dbData.levelReq or 0, DESCRIPTION = desc,
                    COST = cost, CAST_TIME = castTime, RANGE = dbData.range or 0,
                    TAGS = dbData.tags or {},
                    
                    HEAL_TOTAL = heal, DMG_TOTAL = dmg,
                    HPS = hps, HPM = hpm, DPS = dps, DPM = dpm,
                }
                
                table.insert(spells, entry)
            end
        end
    end
    
    J.data.spells = spells
    if J.RefreshUI then J:RefreshUI() end
end