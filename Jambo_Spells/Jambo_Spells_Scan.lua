local addonName, J = ...

local tooltip = CreateFrame("GameTooltip", "JamboScanTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- Tooltip Scraper
local function GetTooltipStats(link_or_id, isItem)
    tooltip:ClearLines()
    if isItem then tooltip:SetHyperlink(link_or_id)
    else tooltip:SetSpellByID(link_or_id) end
    
    local heal, dmg = 0, 0
    local desc = ""
    
    for i = 1, tooltip:NumLines() do
        local line = _G["JamboScanTooltipTextLeft"..i]
        if line then
            local text = line:GetText() or ""
            if i == 2 then desc = text end -- Description is usually line 2
            
            -- Heal Regex
            local h1, h2 = text:match("Heals.-for (%d+).-to (%d+)")
            if not h1 then h1 = text:match("Heals.-for (%d+)") end
            if not h1 then h1 = text:match("Restores (%d+)") end
            
            if h1 then 
                heal = h2 and (tonumber(h1)+tonumber(h2))/2 or tonumber(h1) 
            end

            -- Damage Regex
            local d1, d2 = text:match("Deals.-(%d+).-to (%d+)")
            if not d1 then d1 = text:match("Deals.-(%d+)") end
            if not d1 then d1 = text:match("(%d+) .- damage") end
            
            if d1 then 
                dmg = d2 and (tonumber(d1)+tonumber(d2))/2 or tonumber(d1) 
            end
        end
    end
    return desc, heal, dmg
end

local function FindSlotForSpell(spellID)
    for slot = 1, 120 do
        local type, id = GetActionInfo(slot)
        if type == "spell" and id == spellID then return slot end
    end
    return 0
end

local function FindSlotForMacro(macroIndex)
    for slot = 1, 120 do
        local type, id = GetActionInfo(slot)
        if type == "macro" and id == macroIndex then return slot end
    end
    return 0
end

function J:FullScan()
    local masterList = {}
    local seenIDs = {}
    
    -- 1. CLASS DB SCAN
    if J.classData and J.classData.spells then
        for id, dbData in pairs(J.classData.spells) do
            local name, rankText, icon, castTimeMS, minRange, maxRange = GetSpellInfo(id)
            
            if name then
                seenIDs[id] = true
                local known = IsSpellKnown(id)
                local slot = FindSlotForSpell(id)
                
                -- Priority Rank: Calculated DB > API
                local rank = dbData.rank
                if not rank or rank == 0 then
                    if rankText then rank = tonumber(string.match(rankText, "(%d+)")) end
                end
                if not rank or rank == 0 then rank = 1 end
                
                local desc, sHeal, sDmg = GetTooltipStats(id, false)
                
                -- Cost
                local cost = 0
                if known then
                    local costs = GetSpellPowerCost(id)
                    if costs and costs[1] then cost = costs[1].cost end
                end
                if cost == 0 then cost = dbData.cost or 0 end

                local castSec = (castTimeMS or 0) / 1000
                if castSec == 0 then castSec = 1.5 end
                
                local heal = (sHeal > 0) and sHeal or (dbData.HEAL_TOTAL or 0)
                local dmg = (sDmg > 0) and sDmg or (dbData.DMG_TOTAL or 0)
                
                table.insert(masterList, {
                    TYPE = "SPELL", NAME = name, ID = id, RANK = rank, LEVEL = dbData.levelReq or 0,
                    ICON = icon, DESC = desc, COST = cost, CAST = castSec, RANGE = maxRange or 0, SLOT = slot, KNOWN = known,
                    HEAL_TOTAL = heal, DMG_TOTAL = dmg,
                    HPS = (castSec > 0 and heal/castSec or 0), 
                    HPM = (cost > 0 and heal/cost or 0),
                    DPS = (castSec > 0 and dmg/castSec or 0),
                    DPM = (cost > 0 and dmg/cost or 0)
                })
            end
        end
    end

    -- 2. SPELLBOOK SCAN (Extras)
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, num = GetSpellTabInfo(i)
        for j = offset + 1, offset + num do
            local type, id = GetSpellBookItemInfo(j, "spell")
            if type == "SPELL" and id and not seenIDs[id] then
                local name, rankText, icon, castMS, _, maxRange = GetSpellInfo(id)
                local rank = 1
                if rankText then rank = tonumber(string.match(rankText, "(%d+)")) or 1 end
                
                local desc, heal, dmg = GetTooltipStats(id, false)
                local slot = FindSlotForSpell(id)
                
                local costs = GetSpellPowerCost(id)
                local cost = (costs and costs[1]) and costs[1].cost or 0
                
                local cast = (castMS or 0) / 1000
                if cast == 0 then cast = 1.5 end
                
                table.insert(masterList, {
                    TYPE = "SPELL", NAME = name, ID = id, RANK = rank, LEVEL = 0,
                    ICON = icon, DESC = desc, COST = cost, CAST = cast, RANGE = maxRange or 0, SLOT = slot, KNOWN = true,
                    HEAL_TOTAL = heal, DMG_TOTAL = dmg,
                    HPS = heal/cast, HPM = (cost>0 and heal/cost or 0),
                    DPS = dmg/cast, DPM = (cost>0 and dmg/cost or 0)
                })
                seenIDs[id] = true
            end
        end
    end
    
    -- 3. ITEMS (Bags + Equipped Trinkets)
    local seenItems = {}
    
    -- Scan bags
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local id = info.itemID
                if not seenItems[id] then
                    seenItems[id] = true
                    local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(id)
                    local spellName, spellID = GetItemSpell(id)
                    if spellID then
                        local desc, heal, dmg = GetTooltipStats(link, true)
                        table.insert(masterList, {
                            TYPE = "ITEM", NAME = name, ID = id, RANK = 1, LEVEL = 0,
                            ICON = icon, DESC = desc, COST = 0, CAST = 0, RANGE = 0, SLOT = 0, KNOWN = true,
                            HEAL_TOTAL = heal, DMG_TOTAL = dmg, HPS = heal, HPM = 0, DPS = dmg, DPM = 0
                        })
                    end
                end
            end
        end
    end
    
    -- Scan equipped trinkets/items with usable effects
    local equippedSlots = {13, 14}  -- Trinket slots
    for _, slotID in ipairs(equippedSlots) do
        local id = GetInventoryItemID("player", slotID)
        if id and not seenItems[id] then
            seenItems[id] = true
            local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(id)
            local spellName, spellID = GetItemSpell(id)
            if spellID then
                local desc, heal, dmg = GetTooltipStats(link, true)
                table.insert(masterList, {
                    TYPE = "ITEM", NAME = name, ID = id, RANK = 1, LEVEL = 0,
                    ICON = icon, DESC = desc, COST = 0, CAST = 0, RANGE = 0, SLOT = 0, KNOWN = true,
                    HEAL_TOTAL = heal, DMG_TOTAL = dmg, HPS = heal, HPM = 0, DPS = dmg, DPM = 0,
                    EQUIPPED = true  -- Mark as equipped
                })
            end
        end
    end

    -- 4. MACROS (FIXED: Uses FindSlotForMacro)
    local numGlobal, numChar = GetNumMacros()
    for i = 1, numGlobal + numChar do
        local name, icon, body = GetMacroInfo(i)
        if name then
            local slot = FindSlotForMacro(i) -- Detect if this macro is on the bar
            table.insert(masterList, {
                TYPE = "MACRO", NAME = name, ID = i, RANK = 1, LEVEL = 0,
                ICON = icon, DESC = body, COST = 0, CAST = 0, RANGE = 0, SLOT = slot, KNOWN = true,
                HEAL_TOTAL = 0, DMG_TOTAL = 0, HPS = 0, HPM = 0, DPS = 0, DPM = 0
            })
        end
    end

    J.data.spells = masterList
    if J.SaveCache then J:SaveCache() end
    if J.RefreshUI then J:RefreshUI() end
    if J.ScanBagsForMacros then J:ScanBagsForMacros() end
end

-- Targeted icon updates
function J:UpdateItemIcons(itemID)
    if not itemID then return end
    local id = tonumber(itemID) or itemID
    if not id then return end
    local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(id)
    if not icon then return end
    local updated = false
    local list = J.data.spells or {}
    for _, info in ipairs(list) do
        if info and info.TYPE == "ITEM" and info.ID == id then
            info.ICON = icon
            updated = true
        end
    end
    if updated and J.RefreshUI then J:RefreshUI() end
end

function J:UpdateSpellIcon(spellID)
    if not spellID then return end
    local id = tonumber(spellID) or spellID
    if not id then return end
    local name, rankText, icon = GetSpellInfo(id)
    if not icon then return end
    local updated = false
    local list = J.data.spells or {}
    for _, info in ipairs(list) do
        if info and info.TYPE == "SPELL" and info.ID == id then
            info.ICON = icon
            updated = true
        end
    end
    if updated and J.RefreshUI then J:RefreshUI() end
end