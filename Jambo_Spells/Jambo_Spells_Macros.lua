local addonName, J = ...

function J:ScanBags()
    -- Logic to find lowest rank potions/food
    local potions = { heal = {}, mana = {} }
    local food = { eat = {}, drink = {} }
    
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local id = info.itemID
                local name, link, _, _, minLevel, type, subType = GetItemInfo(id)
                -- Heuristic: check item name or subType for Potion/Food
                if subType == "Potion" then
                    -- Parse tooltip or name to categorize
                    if name:find("Healing Potion") then table.insert(potions.heal, {name=name, lvl=minLevel}) end
                    if name:find("Mana Potion") then table.insert(potions.mana, {name=name, lvl=minLevel}) end
                elseif subType == "Food & Drink" then
                     -- Categorize food vs drink
                end
            end
        end
    end
    
    -- Sorting by level ascending (lowest first)
    local function sortLvl(a,b) return a.lvl < b.lvl end
    table.sort(potions.heal, sortLvl)
    table.sort(potions.mana, sortLvl)
    
    -- Update Macros
    -- Starting ID 80
    -- NOTE: In Classic, we cannot pick specific macro IDs easily via API like EditMacro(id).
    -- We usually lookup by name or index. 
    -- We will try to create/edit macros named "AutoHealPot" etc.
    
    if #potions.heal > 0 then
        J:UpdateMacro("AutoHealPot", "/use " .. potions.heal[1].name, "INV_Potion_51")
    end
    if #potions.mana > 0 then
        J:UpdateMacro("AutoManaPot", "/use " .. potions.mana[1].name, "INV_Potion_76")
    end
end

function J:UpdateMacro(name, body, icon)
    local index = GetMacroIndexByName(name)
    if index > 0 then
        EditMacro(index, name, icon, body)
    else
        -- Create new (Account wide? char specific?)
        CreateMacro(name, icon, body, nil) 
    end
end