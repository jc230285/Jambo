local addonName, J = ...

J.FullScan = J.ScanBagsForMacros

function J:ScanBagsForMacros()
    -- Logic to find lowest rank potions/food/water
    local potions = { heal = {}, mana = {} }
    local food = {}
    local water = {}
    
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local id = info.itemID
                local name, _, _, _, minLevel, type, subType = GetItemInfo(id)
                if name then
                    local lower = string.lower(name)
                    if type == "Consumable" then
                        if subType == "Potion" then
                            if lower:find("healing") then 
                                table.insert(potions.heal, {name=name, lvl=minLevel}) 
                            elseif lower:find("mana") then 
                                table.insert(potions.mana, {name=name, lvl=minLevel}) 
                            end
                        elseif subType == "Food & Drink" or subType == "Food" or subType == "Drink" then
                            if lower:find("water") or lower:find("drink") or lower:find("beverage") then
                                table.insert(water, {name=name, lvl=minLevel})
                            else
                                table.insert(food, {name=name, lvl=minLevel})
                            end
                        end
                    end
                end
            end
        end
    end
    
    local function sortLvl(a,b) return a.lvl < b.lvl end
    table.sort(potions.heal, sortLvl)
    table.sort(potions.mana, sortLvl)
    table.sort(food, sortLvl)
    table.sort(water, sortLvl)
    
    if #potions.heal > 0 then
        J:UpdateMacro("AutoHeal", "/use " .. potions.heal[1].name, "INV_Potion_51")
        J:UpdateMacro("HPPotion", "/use " .. potions.heal[1].name, "134832")
    end
    if #potions.mana > 0 then
        J:UpdateMacro("AutoMana", "/use " .. potions.mana[1].name, "INV_Potion_76")
        J:UpdateMacro("MPPotion", "/use " .. potions.mana[1].name, "134850")
    end
    if #food > 0 then
        J:UpdateMacro("EatFood", "#showtooltip\n/use " .. food[1].name, "133972")
    end
    if #water > 0 then
        J:UpdateMacro("DrinkWater", "#showtooltip\n/use " .. water[1].name, "132794")
    end
    if #food > 0 and #water > 0 then
        J:UpdateMacro("Feast", "#showtooltip\n/use " .. food[1].name .. "\n/use " .. water[1].name, "132794")
    end
    
    J:CreateUtilityMacros()
end

function J:CreateUtilityMacros()
    if InCombatLockdown() then return end
    
    -- Create utility macros
    local macros = {
        {"DrinkWater", "#showtooltip item:159\n/use item:159", "132794"},
        {"Feast", "#showtooltip item:117\n/use item:117\n/use item:159", "132794"},
        {"EatFood", "#showtooltip item:117\n/use item:117", "133972"},
        {"HPPotion", "#showtooltip item:1710\n/use item:1710", "134832"},
        {"MPPotion", "#showtooltip item:2455\n/use item:2455", "134850"},
        {"Break 10", "/dbm timer 600 10 Minute Break!\n/y 10 Minute Break!", "254288"},
        {"Break 5", "/dbm timer 300 5 Minute Break!\n/y 5 Minute Break!", "132161"},
        {"CycleEnemy", "#showtooltip\n/cleartarget [dead][noexists]\n/targetenemy [noexists][dead]", "INV_Misc_QuestionMark"},
        {"CycleFriend", "#showtooltip\n/cleartarget [dead][noexists]\n/targetfriend [noharm]", "INV_Misc_QuestionMark"},
        {"Reload", "/reload", "132096"},
        {"Roll", "/roll", "252184"},
        {"Shoot", "#showtooltip Shoot\n/castsequence [harm] reset=2 !Shoot, null\n/castsequence [help,target=targettarget] reset=2 !Shoot, null", "INV_MISC_QUESTIONMARK"},
        {"Attack", "#showtooltip 16\n/cleartarget [dead]\n/startattack [harm,nodead]\n/targetenemy [noexists]", "INV_MISC_QUESTIONMARK"},
        {"T1", "#showtooltip 13\n/use 13", "INV_MISC_QUESTIONMARK"},
        {"T2", "#showtooltip 14\n/use 14", "INV_MISC_QUESTIONMARK"},
    }
    
    for _, macro in ipairs(macros) do
        J:UpdateMacro(macro[1], macro[2], macro[3])
    end
end