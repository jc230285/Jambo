local addonName, J = ...

function J:ScanBagsForMacros()
    -- Logic to find lowest rank potions/food
    local potions = { heal = {}, mana = {} }
    
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local id = info.itemID
                local name, _, _, _, minLevel, type, subType = GetItemInfo(id)
                if name then
                    local lower = string.lower(name)
                    if lower:find("healing potion") then 
                        table.insert(potions.heal, {name=name, lvl=minLevel}) 
                    elseif lower:find("mana potion") then 
                        table.insert(potions.mana, {name=name, lvl=minLevel}) 
                    end
                end
            end
        end
    end
    
    local function sortLvl(a,b) return a.lvl < b.lvl end
    table.sort(potions.heal, sortLvl)
    table.sort(potions.mana, sortLvl)
    
    if #potions.heal > 0 then
        J:UpdateMacro("AutoHeal", "/use " .. potions.heal[1].name, "INV_Potion_51")
    end
    if #potions.mana > 0 then
        J:UpdateMacro("AutoMana", "/use " .. potions.mana[1].name, "INV_Potion_76")
    end
end

function J:UpdateMacro(name, body, icon)
    if InCombatLockdown() then return end
    local idx = GetMacroIndexByName(name)
    if idx > 0 then
        EditMacro(idx, name, icon, body)
    else
        local numGlobal = GetNumMacros()
        if numGlobal < 120 then CreateMacro(name, icon, body, nil) end
    end
end