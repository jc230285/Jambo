-- Jambo Gear Core Functions
-- Updated: Dynamic Weights from DB, Automation Dropdown Logic

local JG = _G.JamboGear
if not JG then return end

-- ==========================================================
-- 1. INITIALIZATION & DEFAULTS
-- ==========================================================

-- Standard Default Weights (Fallback)
JG.DefaultWeights = {
    WARRIOR = {
        Arms = { Strength=1.0, AttackPower=1.0, Crit=0.8, Hit=0.9, Agility=0.6, Stamina=0.4 },
        Fury = { Strength=1.0, AttackPower=1.0, Crit=0.9, Hit=0.8, Agility=0.6, Haste=0.7, Stamina=0.4 },
        Protection = { Stamina=1.0, Defense=1.0, Armor=0.9, Block=0.8, Dodge=0.7, Parry=0.6, Strength=0.5 }
    },
    PALADIN = {
        Holy = { Intellect=1.0, SpellPower=1.0, MP5=0.9, Spirit=0.8, SpellCrit=0.6, Stamina=0.5 },
        Protection = { Stamina=1.0, Defense=1.0, Armor=0.9, Block=0.8, Dodge=0.7, Intellect=0.6, Strength=0.5 },
        Retribution = { Strength=1.0, AttackPower=1.0, Crit=0.8, Hit=0.9, Stamina=0.5, Intellect=0.4 }
    },
    PRIEST = {
        Holy = { Intellect=1.0, SpellPower=1.0, Spirit=0.9, MP5=0.8, SpellCrit=0.6 },
        Shadow = { Intellect=1.0, SpellPower=1.0, SpellHit=0.9, SpellCrit=0.8, Spirit=0.5 },
        Discipline = { Intellect=1.0, SpellPower=1.0, Spirit=0.8, MP5=0.7, SpellCrit=0.6 }
    },
    ROGUE = {
        Combat = { Agility=1.0, AttackPower=1.0, Hit=0.9, Crit=0.7, Stamina=0.5, Strength=0.3 },
        Assassination = { Agility=1.0, AttackPower=1.0, Hit=0.9, Crit=0.8, Stamina=0.5 },
        Subtlety = { Agility=1.0, AttackPower=1.0, Crit=0.9, Hit=0.8, Stamina=0.5 }
    },
    MAGE = {
        Frost = { Intellect=1.0, SpellPower=1.0, SpellHit=0.8, SpellCrit=0.7, Spirit=0.4 },
        Fire = { Intellect=1.0, SpellPower=1.0, SpellCrit=0.9, SpellHit=0.8, Spirit=0.4 },
        Arcane = { Intellect=1.0, SpellPower=1.0, SpellHit=0.9, SpellCrit=0.7, MP5=0.6 }
    },
    WARLOCK = {
        Affliction = { Intellect=1.0, SpellPower=1.0, SpellHit=0.9, Stamina=0.7, SpellCrit=0.6 },
        Destruction = { Intellect=1.0, SpellPower=1.0, SpellCrit=0.9, SpellHit=0.8, Stamina=0.6 },
        Demonology = { Intellect=1.0, SpellPower=1.0, Stamina=0.8, SpellHit=0.8, SpellCrit=0.6 }
    },
    HUNTER = {
        Marksmanship = { Agility=1.0, AttackPower=1.0, Crit=0.9, Hit=0.8, Intellect=0.3 },
        ["Beast Mastery"] = { Agility=1.0, AttackPower=1.0, Crit=0.8, Hit=0.9, Stamina=0.5 },
        Survival = { Agility=1.0, AttackPower=1.0, Hit=0.9, Stamina=0.7, Crit=0.6 }
    },
    DRUID = {
        Restoration = { Intellect=1.0, SpellPower=1.0, Spirit=0.9, MP5=0.8, SpellCrit=0.6 },
        Balance = { Intellect=1.0, SpellPower=1.0, SpellCrit=0.8, SpellHit=0.9, Spirit=0.5 },
        Feral = { Agility=1.0, AttackPower=1.0, Strength=0.7, Crit=0.8, Stamina=0.7, Hit=0.6 },
        Guardian = { Stamina=1.0, Agility=0.8, Armor=0.9, Dodge=0.7, Defense=0.6 }
    },
    SHAMAN = {
        Restoration = { Intellect=1.0, SpellPower=1.0, Spirit=0.9, MP5=0.8, SpellCrit=0.6 },
        Elemental = { Intellect=1.0, SpellPower=1.0, SpellCrit=0.8, SpellHit=0.9, MP5=0.5 },
        Enhancement = { AttackPower=1.0, Strength=0.8, Agility=0.9, Hit=0.9, Crit=0.7, Intellect=0.6 }
    }
}

function JG:CheckWeightsInit()
    local class = self.playerClass
    if not self.db.profile.weights then self.db.profile.weights = {} end
    
    -- If no weights exist for this class, copy defaults
    if not self.db.profile.weights[class] then
        self.db.profile.weights[class] = {}
        local defaults = self.DefaultWeights[class]
        if defaults then
            for spec, stats in pairs(defaults) do
                self.db.profile.weights[class][spec] = CopyTable(stats)
            end
        end
    end
end

-- ==========================================================
-- 2. GEAR SCANNING
-- ==========================================================

function JG:ScanAndUpdateGear()
    if not self.db.profile.enabled then return end
    self:CheckWeightsInit() -- Ensure weights are ready
    
    local availableGear = self:GetAvailableGear()
    self.availableGear = availableGear
    
    -- Score Gear using DB Weights
    local classConfig = self:GetCurrentClassConfig()
    -- Ensure defaults if missing
    if classConfig and classConfig.specPriority then
         -- We need to score for EVERY spec in the Weights DB, not just priority list
         local classWeights = self.db.profile.weights[self.playerClass] or {}
         for specName, _ in pairs(classWeights) do
             self:ScoreGearForSpec(availableGear, specName)
         end
    end
    
    self:UpdateGearSets(availableGear)
    
    if self.gui and self.gui:IsShown() and self.UpdateGUI then self:UpdateGUI() end
    if self.UpdateAllContainerFrameOverlays then self:UpdateAllContainerFrameOverlays() end
end

function JG:GetAvailableGear()
    local gear = {}
    local bankIsOpen = (C_Container and C_Container.GetContainerNumSlots(-1) > 0) or (GetContainerNumSlots(-1) > 0)
    
    -- Bags 0-4
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local itemInfo = self:GetItemInfo(info.hyperlink)
                    if itemInfo and itemInfo.equipSlot then
                        itemInfo.bag = bag; itemInfo.slot = slot; itemInfo.isBound = info.isBound
                        table.insert(gear, itemInfo)
                    end
                end
            end
        end
    end
    
    -- Bank
    if bankIsOpen then
        self.db.profile.cachedBank = {} 
        for bag = -1, 11 do
            if bag == -1 or bag >= 5 then
                local numSlots = C_Container.GetContainerNumSlots(bag)
                if numSlots and numSlots > 0 then
                    for slot = 1, numSlots do
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and info.hyperlink then
                            local itemInfo = self:GetItemInfo(info.hyperlink)
                            if itemInfo and itemInfo.equipSlot then
                                itemInfo.bag = bag; itemInfo.slot = slot; itemInfo.isBound = info.isBound; itemInfo.isBank = true
                                table.insert(gear, itemInfo)
                                table.insert(self.db.profile.cachedBank, itemInfo)
                            end
                        end
                    end
                end
            end
        end
    else
        if self.db.profile.cachedBank then
            for _, itemInfo in ipairs(self.db.profile.cachedBank) do
                local cachedItem = CopyTable(itemInfo)
                cachedItem.isBank = true
                table.insert(gear, cachedItem)
            end
        end
    end
    
    -- Equipped
    for slot = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local itemInfo = self:GetItemInfo(itemLink)
            if itemInfo and itemInfo.equipSlot then
                itemInfo.isEquipped = true; itemInfo.isBound = true 
                table.insert(gear, itemInfo)
            end
        end
    end
    return gear
end

function JG:GetItemInfo(itemLink)
    if not itemLink then return nil end
    local itemName, _, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, _, itemEquipLoc, itemTexture = GetItemInfo(itemLink)
    if not itemName then return nil end
    local equipSlot = self:GetEquipSlotFromLocation(itemEquipLoc)
    if not equipSlot then return nil end
    local stats = {}; if GetItemStats then stats = GetItemStats(itemLink) or {} end
    return { link = itemLink, name = itemName, quality = itemQuality, level = itemLevel, equipSlot = equipSlot, invType = itemEquipLoc, stats = stats, texture = itemTexture, type = itemType, subtype = itemSubType }
end

function JG:GetEquipSlotFromLocation(invType)
    local slotMap = { INVTYPE_HEAD="HeadSlot", INVTYPE_NECK="NeckSlot", INVTYPE_SHOULDER="ShoulderSlot", INVTYPE_CLOAK="BackSlot", INVTYPE_CHEST="ChestSlot", INVTYPE_ROBE="ChestSlot", INVTYPE_WRIST="WristSlot", INVTYPE_HAND="HandsSlot", INVTYPE_WAIST="WaistSlot", INVTYPE_LEGS="LegsSlot", INVTYPE_FEET="FeetSlot", INVTYPE_FINGER="Finger0Slot", INVTYPE_TRINKET="Trinket0Slot", INVTYPE_WEAPON="MainHandSlot", INVTYPE_WEAPONMAINHAND="MainHandSlot", INVTYPE_WEAPONOFFHAND="SecondaryHandSlot", INVTYPE_2HWEAPON="MainHandSlot", INVTYPE_SHIELD="SecondaryHandSlot", INVTYPE_HOLDABLE="SecondaryHandSlot", INVTYPE_RANGED="RangedSlot", INVTYPE_RANGEDRIGHT="RangedSlot", INVTYPE_THROWN="RangedSlot", INVTYPE_RELIC="RangedSlot" }
    return slotMap[invType]
end

-- ==========================================================
-- 3. SCORING
-- ==========================================================

function JG:ScoreGearForSpec(availableGear, specName)
    for _, item in ipairs(availableGear) do
        item.specScores = item.specScores or {}
        item.specScores[specName] = self:GetEnhancedItemScore(item, specName)
    end
end

function JG:GetEnhancedItemScore(item, specName)
    if item.equipSlot:find("Trinket") then return 0 end
    
    local class = self.playerClass
    -- Look in DB first
    local weights = self.db.profile.weights and self.db.profile.weights[class] and self.db.profile.weights[class][specName]
    
    if not weights then return 0 end
    
    -- Base Score: Level & Quality
    local score = item.level * (item.quality + 1) * 2
    
    -- Stat Mapping
    local statMap = {
        Armor="RESISTANCE0_NAME", Stamina="ITEM_MOD_STAMINA_SHORT", Strength="ITEM_MOD_STRENGTH_SHORT",
        Agility="ITEM_MOD_AGILITY_SHORT", Intellect="ITEM_MOD_INTELLECT_SHORT", Spirit="ITEM_MOD_SPIRIT_SHORT",
        Defense="ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", Dodge="ITEM_MOD_DODGE_RATING_SHORT",
        Parry="ITEM_MOD_PARRY_RATING_SHORT", Block="ITEM_MOD_BLOCK_RATING_SHORT", Hit="ITEM_MOD_HIT_RATING_SHORT",
        Crit="ITEM_MOD_CRIT_RATING_SHORT", Haste="ITEM_MOD_HASTE_RATING_SHORT", SpellPower="ITEM_MOD_SPELL_POWER_SHORT",
        SpellHit="ITEM_MOD_HIT_SPELL_RATING_SHORT", SpellCrit="ITEM_MOD_CRIT_SPELL_RATING_SHORT",
        MP5="ITEM_MOD_MANA_REGENERATION_SHORT", AttackPower="ITEM_MOD_ATTACK_POWER_SHORT"
    }
    
    for statName, multiplier in pairs(weights) do
        local key = statMap[statName] or statName
        local val = item.stats[key] or 0
        if val > 0 then
            score = score + (val * multiplier * 10) -- Base multiplier x10 for visibility
        end
    end
    
    return math.floor(score)
end

-- ==========================================================
-- 4. SET BUILDING & WEAPONS
-- ==========================================================

function JG:UpdateGearSets(availableGear)
    local classConfig = self:GetCurrentClassConfig()
    if not classConfig then return end
    classConfig.gearSets = classConfig.gearSets or {}
    local tempSets = {} 
    for setName, setDef in pairs(classConfig.gearSets) do tempSets[setName] = setDef end
    for setName, setDef in pairs(tempSets) do
        local newSet = self:BuildGearSet(availableGear, setName)
        newSet.meta = setDef.meta or newSet.meta
        classConfig.gearSets[setName] = newSet
    end
end

function JG:BuildGearSet(availableGear, setName)
    local classConfig = self:GetCurrentClassConfig()
    local assignedSpec = setName
    if classConfig and classConfig.gearSets[setName] and 
       classConfig.gearSets[setName].meta and classConfig.gearSets[setName].meta.assignedSpec then
        assignedSpec = classConfig.gearSets[setName].meta.assignedSpec
    end
    
    local gearSet = {}
    gearSet.meta = gearSet.meta or {}
    gearSet.meta.role = self:GetSpecRole(assignedSpec)

    local standardSlots = { "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","RangedSlot" }
    for _, slotName in ipairs(standardSlots) do
        local bestItem, bestScore = nil, -1
        for _, item in ipairs(availableGear) do
            if item.equipSlot == slotName then
                local score = (item.specScores and item.specScores[assignedSpec]) or 0
                if score > bestScore then bestScore = score; bestItem = item end
            end
        end
        if bestItem then gearSet[slotName] = bestItem end
    end

    local rings = {}
    for _, item in ipairs(availableGear) do if item.equipSlot:find("Finger") then table.insert(rings, item) end end
    table.sort(rings, function(a,b) return ((a.specScores and a.specScores[assignedSpec]) or 0) > ((b.specScores and b.specScores[assignedSpec]) or 0) end)
    if rings[1] then
        gearSet["Finger0Slot"] = rings[1]
        local bestID = tonumber(rings[1].link:match("item:(%d+)"))
        for i=2, #rings do
            if tonumber(rings[i].link:match("item:(%d+)")) ~= bestID then gearSet["Finger1Slot"] = rings[i]; break end
        end
    end

    local trinkets = {}
    for _, item in ipairs(availableGear) do if item.equipSlot:find("Trinket") then table.insert(trinkets, item) end end
    table.sort(trinkets, function(a,b) return ((a.specScores and a.specScores[assignedSpec]) or 0) > ((b.specScores and b.specScores[assignedSpec]) or 0) end)
    if trinkets[1] then gearSet["Trinket0Slot"] = trinkets[1] end
    if trinkets[2] then gearSet["Trinket1Slot"] = trinkets[2] end

    local bestMH, bestOH, best2H = self:GetBestWeaponCombination(availableGear, assignedSpec)
    local score2H = (best2H and best2H.specScores[assignedSpec]) or 0
    local score1H = (bestMH and bestMH.specScores[assignedSpec]) or 0
    local scoreOH = (bestOH and bestOH.specScores[assignedSpec]) or 0
    
    if score2H > (score1H + scoreOH) then
        gearSet["MainHandSlot"] = bestTwoHand; gearSet["SecondaryHandSlot"] = nil 
    else
        if bestMH then gearSet["MainHandSlot"] = bestMH end
        if bestOH then gearSet["SecondaryHandSlot"] = bestOH end
    end
    
    return gearSet
end

function JG:GetBestWeaponCombination(availableGear, specName)
    local bestMainHand, bestOffHand, bestTwoHand = nil, nil, nil
    local maxMH, maxOH, max2H = -1, -1, -1
    for _, item in ipairs(availableGear) do
        local score = (item.specScores and item.specScores[specName]) or 0
        local sub = item.subtype or ""
        if item.equipSlot == "MainHandSlot" and (sub:find("Two%-Handed") or sub == "Staff" or sub == "Polearms") then
            if score > max2H then max2H = score; bestTwoHand = item end
        elseif item.equipSlot == "MainHandSlot" then
             if not (sub:find("Two%-Handed") or sub == "Staff" or sub == "Polearms") then
                if score > maxMH then maxMH = score; bestMainHand = item end
             end
        elseif item.equipSlot == "SecondaryHandSlot" then
            if score > maxOH then maxOH = score; bestOffHand = item end
        end
    end
    return bestMainHand, bestOffHand, bestTwoHand
end

-- ==========================================================
-- 5. TOOLTIPS & UTILS
-- ==========================================================

function JG:AnnotateTooltip(tooltip, itemLink)
    if not tooltip or not itemLink then return end
    if tooltip.jgAnnotatedItem == itemLink then return end
    tooltip.jgAnnotatedItem = itemLink

    local itemInfo = self:GetItemInfo(itemLink)
    if not itemInfo then return end
    if not self.availableGear then return end
    
    self:CheckWeightsInit()
    local classWeights = self.db.profile.weights[self.playerClass] or {}

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff00ff00Jambo Gear Scores:|r")

    -- Check against every custom spec
    local displayedAny = false
    for specName, _ in pairs(classWeights) do
        -- Calc Rank
        local myScore = self:GetEnhancedItemScore(itemInfo, specName) or 0
        if myScore > 0 then
            displayedAny = true
            -- Find peers
            local slotItems = {}
            for _, gearItem in ipairs(self.availableGear) do
                local match = false
                if gearItem.equipSlot == itemInfo.equipSlot then match = true end
                if (itemInfo.equipSlot:find("Finger") and gearItem.equipSlot:find("Finger")) then match = true end
                if (itemInfo.equipSlot:find("Trinket") and gearItem.equipSlot:find("Trinket")) then match = true end
                if match then table.insert(slotItems, gearItem) end
            end
            
            table.sort(slotItems, function(a, b) return (self:GetEnhancedItemScore(a, specName) or 0) > (self:GetEnhancedItemScore(b, specName) or 0) end)
            
            local rank = 0
            local myID = itemInfo.link:match("item:(%d+)")
            for i, other in ipairs(slotItems) do
                if other.link:match("item:(%d+)") == myID then rank = i; break end
            end
            
            -- Ref Score
            local validRef = {}
            for _, item in ipairs(slotItems) do
                 local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(item.link)
                 if not ((bindType==2 or bindType==3) and not item.isBound) then table.insert(validRef, item) end
            end
            local ref1 = (validRef[1] and self:GetEnhancedItemScore(validRef[1], specName)) or 0
            local ref2 = (validRef[2] and self:GetEnhancedItemScore(validRef[2], specName)) or 0
            
            local refScore = ref1
            local isDual = (itemInfo.equipSlot:find("Finger") or itemInfo.equipSlot:find("Trinket"))
            if isDual and ref2 > 0 then refScore = ref2 end
            
            local pct = 0; if refScore > 0 then pct = (myScore / refScore) * 100 end
            
            local rText = ""
            if rank > 0 and rank <= 3 then
                local col = "ffffffff"
                if rank == 1 then col = "ff00ff00" end
                if rank == 2 and isDual then col = "ff00ff00" elseif rank == 2 then col = "ffffff00" end
                rText = string.format(" |c%s#%d|r", col, rank)
            end
            
            tooltip:AddDoubleLine(specName, string.format("%d (%.0f%%)%s", myScore, pct, rText), 1, 0.82, 0, 1,1,1)
        end
    end
    if not displayedAny then tooltip:AddLine("No active weights for this item type.", 0.6, 0.6, 0.6) end
    tooltip:Show()
end

function JG:EquipItem(itemData, slotName)
    if not itemData or not itemData.link then return false end
    local slotId = GetInventorySlotInfo(slotName)
    local currentLink = GetInventoryItemLink("player", slotId)
    local currentID = currentLink and tonumber(currentLink:match("item:(%d+)"))
    local targetID = tonumber(itemData.link:match("item:(%d+)"))
    if currentID == targetID then return false end

    for bag = -1, 11 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if link and tonumber(link:match("item:(%d+)")) == targetID then
                     local isBank = (bag == -1 or bag >= 5)
                     C_Container.PickupContainerItem(bag, slot)
                     if CursorHasItem() then EquipCursorItem(slotId); return true 
                     else if isBank then self:Print("Cannot equip from Bank (Out of range).") end return false end
                end
            end
        end
    end
    return false
end

-- ==========================================================
-- 6. AUTOMATION LOGIC
-- ==========================================================

function JG:ApplyAutomationMode(mode)
    self.db.profile.automationMode = mode
    self:Print("Automation Mode set to: " .. mode)
    
    if mode == "None" then return end
    
    -- If user selects "Healer", immediately try to equip the best "Healer" set
    -- Find a spec that belongs to this role
    local classConfig = self:GetCurrentClassConfig()
    local targetSpec = nil
    
    -- Try to find a spec matching the role in our Priority List
    if classConfig and classConfig.specPriority then
        for _, s in ipairs(classConfig.specPriority) do
            if s.role == mode and s.enabled then targetSpec = s.name; break end
        end
    end
    
    -- Fallback to standard class specs
    if not targetSpec then
        local specs = self.ClassSpecs[self.playerClass] or {}
        for _, s in ipairs(specs) do
             if s.role == mode then targetSpec = s.name; break end
        end
    end
    
    if targetSpec then
        self:SwapToOptimalGear(targetSpec)
    else
        self:Print("No spec found for role " .. mode .. ". Check weights configuration.")
    end
end

function JG:GetSpecRole(specName)
    for class, specs in pairs(self.ClassSpecs) do
        for _, spec in ipairs(specs) do
            if spec.name == specName then
                return spec.role
            end
        end
    end
    return "DPS" -- Default fallback
end