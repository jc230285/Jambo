local addonName, J = ...

function J:ScanBagsForMacros()
    -- 1. Defaults
    J:CreateUtilityMacros()

    local potions = { heal = {}, mana = {} }
    local food = {}
    local water = {}
    local scrolls = {}
    local bandages = {}
    
    local hasData = true
    local foundCount = 0
    
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local id = info.itemID
                local name, _, _, _, minLevel, _, _, _, _, _, _, classID, subClassID = GetItemInfo(id)
                
                if not name then
                    hasData = false 
                elseif classID == 0 then -- Consumable
                    foundCount = foundCount + 1
                    local lower = string.lower(name)
                    
                    -- DETECT BY NAME (Since SubClassID is often 0 in Classic)
                    
                    -- 1. Potions
                    if lower:find("healing potion") or lower:find("health potion") or lower:find("minor potion") or lower:find("lesser potion") then 
                        table.insert(potions.heal, {name=name, lvl=minLevel or 0, id = id}) 
                    elseif lower:find("mana potion") then 
                        table.insert(potions.mana, {name=name, lvl=minLevel or 0, id = id}) 
                    
                    -- 2. Bandages
                    elseif lower:find("bandage") then
                        table.insert(bandages, {name=name, lvl=minLevel or 0, id = id})
                        
                    -- 3. Scrolls
                    elseif lower:find("scroll of") then
                        table.insert(scrolls, {name=name, lvl=minLevel or 0, id = id})
                    
                    -- 4. Drinks
                    elseif lower:find("water") or lower:find("milk") or lower:find("juice") or lower:find("refreshing") or lower:find("beverage") or lower:find("drink") or lower:find("nectar") or lower:find("ice cold") then
                        table.insert(water, {name=name, lvl=minLevel or 0, id = id})
                    
                    -- 5. Food (Fallback for other consumables that aren't the above)
                    -- Exclude specific non-food items if needed (like stones, oils)
                    elseif not lower:find("stone") and not lower:find("oil") and not lower:find("powder") then
                        table.insert(food, {name=name, lvl=minLevel or 0, id = id})
                    end
                end
            end
        end
    end
    
    if not hasData then
        -- Silent retry to avoid spam, or print once
        C_Timer.After(1.0, function() J:ScanBagsForMacros() end)
        return
    end
    
    -- Sort: Lowest Level First
    local function sortLvl(a,b) return a.lvl < b.lvl end
    table.sort(potions.heal, sortLvl)
    table.sort(potions.mana, sortLvl)
    table.sort(food, sortLvl)
    table.sort(water, sortLvl)
    table.sort(scrolls, sortLvl)
    table.sort(bandages, sortLvl)
    
    -- Debug Report
    if foundCount > 0 then
        print(string.format("|cff00ff00[Jambo]|r Scan: %d Food, %d Drink, %d HealPot, %d ManaPot, %d Scroll", 
            #food, #water, #potions.heal, #potions.mana, #scrolls))
    end

    -- Update Macros
    if #potions.heal > 0 then
        local itemInfo = potions.heal[1]
        local itemIcon = "134832"
        if itemInfo and itemInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(itemInfo.id)
            if ic then itemIcon = ic end
        end
        local item = itemInfo.name
        J:UpdateMacro("AutoHeal", "/use " .. item, itemIcon)
        J:UpdateMacro("HPPotion", "#showtooltip " .. item .. "\n/use " .. item, itemIcon)
    end
    
    if #potions.mana > 0 then
        local itemInfo = potions.mana[1]
        local itemIcon = "134850"
        if itemInfo and itemInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(itemInfo.id)
            if ic then itemIcon = ic end
        end
        local item = itemInfo.name
        J:UpdateMacro("AutoMana", "/use " .. item, itemIcon)
        J:UpdateMacro("MPPotion", "#showtooltip " .. item .. "\n/use " .. item, itemIcon)
    end
    
    if #food > 0 then
        local itemInfo = food[1]
        local itemIcon = "133972"
        if itemInfo and itemInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(itemInfo.id)
            if ic then itemIcon = ic end
        end
        local item = itemInfo.name
        J:UpdateMacro("EatFood", "#showtooltip " .. item .. "\n/use " .. item, itemIcon)
    end
    
    if #water > 0 then
        local itemInfo = water[1]
        local itemIcon = "132794"
        if itemInfo and itemInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(itemInfo.id)
            if ic then itemIcon = ic end
        end
        local item = itemInfo.name
        J:UpdateMacro("DrinkWater", "#showtooltip " .. item .. "\n/use " .. item, itemIcon)
    end
    
    if #food > 0 and #water > 0 then
        local fInfo = food[1]
        local wInfo = water[1]
        local itemIcon = "132794"
        if fInfo and fInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(fInfo.id)
            if ic then itemIcon = ic end
        elseif wInfo and wInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(wInfo.id)
            if ic then itemIcon = ic end
        end
        local f = fInfo.name
        local w = wInfo.name
        J:UpdateMacro("Feast", "#showtooltip " .. f .. "\n/use " .. f .. "\n/use " .. w, itemIcon)
    end

    if #bandages > 0 then
        local itemInfo = bandages[1]
        local itemIcon = "134330"
        if itemInfo and itemInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(itemInfo.id)
            if ic then itemIcon = ic end
        end
        local item = itemInfo.name
        J:UpdateMacro("AutoBandage", "#showtooltip " .. item .. "\n/use [target=player] " .. item, itemIcon)
    end
    
    if #scrolls > 0 then
        -- Stack scrolls in one macro
        local sInfo = scrolls[1]
        local body = "#showtooltip " .. sInfo.name
        local itemIcon = "134937"
        if sInfo and sInfo.id then
            local n, link, _, _, _, _, _, _, _, ic = GetItemInfo(sInfo.id)
            if ic then itemIcon = ic end
        end
        for _, s in ipairs(scrolls) do
            body = body .. "\n/use " .. s.name
        end
        J:UpdateMacro("AutoScrolls", body, itemIcon)
    end
end

function J:UpdateMacro(name, body, icon)
    if InCombatLockdown() then return end
    
    local idx = GetMacroIndexByName(name)
    if idx > 0 then
        EditMacro(idx, name, icon, body)
    else
        local numGlobal, numChar = GetNumMacros()
        if numGlobal < 120 then
            CreateMacro(name, icon, body, nil) 
        end
    end
end

function J:CreateUtilityMacros()
    if InCombatLockdown() then return end
    
    local macros = {
        {"DrinkWater", "132794", "#showtooltip item:159\n/use item:159"}, 
        {"Feast", "132794", "#showtooltip item:117\n/use item:117\n/use item:159"},
        {"EatFood", "133972", "#showtooltip item:117\n/use item:117"}, 
        {"AutoHeal", "134832", "#showtooltip item:118\n/use item:118"}, 
        {"AutoMana", "134850", "#showtooltip item:2455\n/use item:2455"}, 
        {"AutoBandage", "134330", "#showtooltip item:1251\n/use [target=player] item:1251"},
        {"AutoScrolls", "134937", "#showtooltip item:955\n/use Scroll of Strength\n/use Scroll of Agility"},
        
        {"Break 10", "254288", "/dbm timer 600 10 Minute Break!\n/y 10 Minute Break!"},
        {"Break 5", "132161", "/dbm timer 300 5 Minute Break!\n/y 5 Minute Break!"},
        {"CycleEnemy", "132108", "#showtooltip\n/cleartarget [dead][noexists]\n/targetenemy [noexists][dead]"},
        {"CycleFriend", "132108", "#showtooltip\n/cleartarget [dead][noexists]\n/targetfriend [noharm]"},
        {"Reload", "132096", "/reload"},
        {"Roll", "252184", "/roll"},
        {"AutoShoot", "132329", "#showtooltip Shoot\n/castsequence [harm] reset=2 !Shoot, null\n/castsequence [help,target=targettarget] reset=2 !Shoot, null"},
        {"AutoAttack", "132349", "#showtooltip 16\n/cleartarget [dead]\n/startattack [harm,nodead]\n/targetenemy [noexists]"},
        {"T1", "134400", "#showtooltip 13\n/use 13"},
        {"T2", "134400", "#showtooltip 14\n/use 14"},
    }
    
    for _, m in ipairs(macros) do
        local idx = GetMacroIndexByName(m[1])
        if idx == 0 then
            J:UpdateMacro(m[1], m[3], m[2])
        end
    end
end

-- Debug
SLASH_JSDEBUGBAGS1 = "/jsdebugbags"
SlashCmdList["JSDEBUGBAGS"] = function()
    print("|cff00ff00[Jambo]|r Bag Scan Debug:")
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local n, _, _, _, _, _, _, _, _, _, _, cID, sID = GetItemInfo(info.itemID)
                if n and cID == 0 then
                    print(string.format("  [%s] Class:%d Sub:%d", n, cID, sID))
                end
            end
        end
    end
end

-- Timestamp: 2023-12-06 10:00:00