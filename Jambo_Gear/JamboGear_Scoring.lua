-- Jambo Gear Scoring System
-- Enhanced scoring with Zygor integration and class-specific weights

local JG = _G.JamboGear
if not JG then
    print("ERROR: JamboGear object not found - scoring system will not load")
    return
end

-- Class-specific stat weights for different specs
JG.ClassStatWeights = {
    WARRIOR = {
        Arms = {
            primary = {AttackPower = 1.0, Strength = 1.0, Crit = 0.8, Hit = 0.9},
            secondary = {Agility = 0.6, Stamina = 0.4},
            tertiary = {Spirit = 0.1}
        },
        Fury = {
            primary = {AttackPower = 1.0, Strength = 1.0, Crit = 0.9, Hit = 0.8},
            secondary = {Agility = 0.6, Haste = 0.7, Stamina = 0.4},
            tertiary = {Spirit = 0.1}
        },
        Protection = {
            primary = {Stamina = 1.0, Defense = 1.0, Armor = 0.9, Block = 0.8},
            secondary = {Dodge = 0.7, Parry = 0.6, Strength = 0.5},
            tertiary = {Agility = 0.3, Hit = 0.2}
        }
    },
    PALADIN = {
        Holy = {
            primary = {Intellect = 1.0, SpellPower = 1.0, MP5 = 0.9, Spirit = 0.8},
            secondary = {Stamina = 0.5, SpellCrit = 0.6},
            tertiary = {Strength = 0.2, SpellHit = 0.3}
        },
        Protection = {
            primary = {Stamina = 1.0, Defense = 1.0, Armor = 0.9, Block = 0.8},
            secondary = {Intellect = 0.6, Strength = 0.5, Dodge = 0.7},
            tertiary = {Spirit = 0.3, MP5 = 0.4}
        },
        Retribution = {
            primary = {AttackPower = 1.0, Strength = 1.0, Crit = 0.8, Hit = 0.9},
            secondary = {Stamina = 0.5, Intellect = 0.4},
            tertiary = {Spirit = 0.2, MP5 = 0.3}
        }
    },
    HUNTER = {
        ["Beast Mastery"] = {
            primary = {AttackPower = 1.0, Agility = 1.0, Crit = 0.8, Hit = 0.9},
            secondary = {Stamina = 0.5, Intellect = 0.3},
            tertiary = {Spirit = 0.2, MP5 = 0.3}
        },
        Marksmanship = {
            primary = {AttackPower = 1.0, Agility = 1.0, Crit = 0.9, Hit = 0.8},
            secondary = {Stamina = 0.5, Intellect = 0.3},
            tertiary = {Spirit = 0.2, MP5 = 0.3}
        },
        Survival = {
            primary = {AttackPower = 1.0, Agility = 1.0, Hit = 0.9, Stamina = 0.7},
            secondary = {Crit = 0.6, Intellect = 0.3},
            tertiary = {Spirit = 0.2, MP5 = 0.3}
        }
    },
    ROGUE = {
        Assassination = {
            primary = {AttackPower = 1.0, Agility = 1.0, Hit = 0.9, Crit = 0.8},
            secondary = {Stamina = 0.5, Strength = 0.3},
            tertiary = {Intellect = 0.1, Spirit = 0.1}
        },
        Combat = {
            primary = {AttackPower = 1.0, Agility = 1.0, Hit = 0.9, Crit = 0.7},
            secondary = {Stamina = 0.5, Haste = 0.6, Strength = 0.3},
            tertiary = {Intellect = 0.1, Spirit = 0.1}
        },
        Subtlety = {
            primary = {AttackPower = 1.0, Agility = 1.0, Crit = 0.9, Hit = 0.8},
            secondary = {Stamina = 0.5, Strength = 0.3},
            tertiary = {Intellect = 0.1, Spirit = 0.1}
        }
    },
    PRIEST = {
        Discipline = {
            primary = {Intellect = 1.0, SpellPower = 1.0, Spirit = 0.8, MP5 = 0.7},
            secondary = {Stamina = 0.5, SpellCrit = 0.6},
            tertiary = {Strength = 0.1, SpellHit = 0.3}
        },
        Holy = {
            primary = {Intellect = 1.0, SpellPower = 1.0, Spirit = 0.9, MP5 = 0.8},
            secondary = {Stamina = 0.5, SpellCrit = 0.6},
            tertiary = {Strength = 0.1, SpellHit = 0.2}
        },
        Shadow = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellHit = 0.9, SpellCrit = 0.8},
            secondary = {Stamina = 0.6, Spirit = 0.5, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.4}
        }
    },
    SHAMAN = {
        Elemental = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellCrit = 0.8, SpellHit = 0.9},
            secondary = {Stamina = 0.6, Spirit = 0.5, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.4}
        },
        Enhancement = {
            primary = {AttackPower = 1.0, Strength = 0.8, Agility = 0.9, Hit = 0.9},
            secondary = {Intellect = 0.6, Crit = 0.7, Stamina = 0.5},
            tertiary = {Spirit = 0.3, MP5 = 0.3, SpellPower = 0.4}
        },
        Restoration = {
            primary = {Intellect = 1.0, SpellPower = 1.0, Spirit = 0.9, MP5 = 0.8},
            secondary = {Stamina = 0.5, SpellCrit = 0.6},
            tertiary = {Strength = 0.1, SpellHit = 0.2}
        }
    },
    MAGE = {
        Arcane = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellHit = 0.9, SpellCrit = 0.7},
            secondary = {Stamina = 0.5, Spirit = 0.4, MP5 = 0.6},
            tertiary = {Strength = 0.1, Haste = 0.5, Armor = 0.1}
        },
        Fire = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellCrit = 0.9, SpellHit = 0.8},
            secondary = {Stamina = 0.5, Spirit = 0.4, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.6, Armor = 0.1}
        },
        Frost = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellHit = 0.8, SpellCrit = 0.7},
            secondary = {Stamina = 0.6, Spirit = 0.4, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.4, Armor = 0.1}
        }
    },
    WARLOCK = {
        Affliction = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellHit = 0.9, Stamina = 0.7},
            secondary = {SpellCrit = 0.6, Spirit = 0.4, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.5}
        },
        Demonology = {
            primary = {Intellect = 1.0, SpellPower = 1.0, Stamina = 0.8, SpellHit = 0.8},
            secondary = {SpellCrit = 0.6, Spirit = 0.4, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.4}
        },
        Destruction = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellCrit = 0.9, SpellHit = 0.8},
            secondary = {Stamina = 0.6, Spirit = 0.4, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.6}
        }
    },
    DRUID = {
        Balance = {
            primary = {Intellect = 1.0, SpellPower = 1.0, SpellCrit = 0.8, SpellHit = 0.9},
            secondary = {Stamina = 0.6, Spirit = 0.5, MP5 = 0.5},
            tertiary = {Strength = 0.1, Haste = 0.4}
        },
        Feral = {
            primary = {AttackPower = 1.0, Agility = 1.0, Strength = 0.7, Crit = 0.8},
            secondary = {Stamina = 0.7, Hit = 0.6},
            tertiary = {Intellect = 0.3, Spirit = 0.2}
        },
        Guardian = {
            primary = {Stamina = 1.0, Agility = 0.8, Armor = 0.9, Dodge = 0.7},
            secondary = {Strength = 0.5, Defense = 0.6},
            tertiary = {Intellect = 0.3, Spirit = 0.2}
        },
        Restoration = {
            primary = {Intellect = 1.0, SpellPower = 1.0, Spirit = 0.9, MP5 = 0.8},
            secondary = {Stamina = 0.5, SpellCrit = 0.6},
            tertiary = {Strength = 0.1, SpellHit = 0.2}
        }
    }
}

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

function JG:GetWeaponScore(item, specName)
    local weaponScore = 0
    local class = self.playerClass
    
    -- Get weapon damage/DPS if available
    -- Note: GetItemInfo doesn't return damage values in Classic, this is just placeholder
    local itemName, itemLink, itemRarity = GetItemInfo(item.link)
    
    -- Basic weapon scoring
    if item.subtype then
        -- Class-specific weapon preferences
        local weaponBonus = 0
        
        if class == "WARRIOR" then
            if item.subtype == "Two-Handed Swords" or item.subtype == "Two-Handed Axes" or item.subtype == "Two-Handed Maces" then
                weaponBonus = 50
            elseif item.subtype == "One-Handed Swords" or item.subtype == "One-Handed Axes" or item.subtype == "One-Handed Maces" then
                weaponBonus = 40
            end
        elseif class == "PALADIN" then
            if specName == "Retribution" and (item.subtype == "Two-Handed Swords" or item.subtype == "Two-Handed Maces") then
                weaponBonus = 60
            elseif specName == "Protection" and item.subtype == "One-Handed Swords" then
                weaponBonus = 50
            elseif specName == "Holy" and (item.subtype == "Maces" or item.subtype == "One-Handed Maces") then
                weaponBonus = 45
            end
        elseif class == "HUNTER" then
            if item.subtype == "Bows" or item.subtype == "Crossbows" or item.subtype == "Guns" then
                weaponBonus = 60
            elseif item.subtype == "Two-Handed Axes" or item.subtype == "Polearms" then
                weaponBonus = 30
            end
        elseif class == "ROGUE" then
            if item.subtype == "Daggers" then
                weaponBonus = 50
            elseif item.subtype == "One-Handed Swords" or item.subtype == "Fist Weapons" then
                weaponBonus = 45
            end
        elseif class == "PRIEST" then
            if item.subtype == "Staves" or item.subtype == "Wands" then
                weaponBonus = 40
            elseif item.subtype == "One-Handed Maces" or item.subtype == "Daggers" then
                weaponBonus = 35
            end
        elseif class == "SHAMAN" then
            if item.subtype == "Two-Handed Maces" or item.subtype == "Staves" then
                weaponBonus = 45
            elseif item.subtype == "One-Handed Maces" or item.subtype == "Daggers" then
                weaponBonus = 40
            end
        elseif class == "MAGE" then
            if item.subtype == "Staves" or item.subtype == "Wands" then
                weaponBonus = 50
            elseif item.subtype == "One-Handed Swords" or item.subtype == "Daggers" then
                weaponBonus = 30
            end
        elseif class == "WARLOCK" then
            if item.subtype == "Staves" or item.subtype == "Wands" then
                weaponBonus = 50
            elseif item.subtype == "One-Handed Swords" or item.subtype == "Daggers" then
                weaponBonus = 30
            end
        elseif class == "DRUID" then
            if item.subtype == "Staves" or item.subtype == "Two-Handed Maces" then
                weaponBonus = 45
            elseif item.subtype == "One-Handed Maces" or item.subtype == "Daggers" then
                weaponBonus = 35
            end
        end
        
        weaponScore = weaponScore + weaponBonus
    end
    
    return weaponScore
end

function JG:GetArmorScore(item, specName)
    local armorScore = 0
    local class = self.playerClass
    
    -- Armor type preferences based on class (best available armor type gets highest bonus)
    if item.subtype then
        local armorBonus = 0
        
        -- Each class should prefer their highest available armor type
        if class == "WARRIOR" or class == "PALADIN" then
            if item.subtype == "Plate" then
                armorBonus = 50
            elseif item.subtype == "Mail" then
                armorBonus = 30
            elseif item.subtype == "Leather" then
                armorBonus = 20
            elseif item.subtype == "Cloth" then
                armorBonus = 10
            end
        elseif class == "HUNTER" or class == "SHAMAN" then
            if item.subtype == "Mail" then
                armorBonus = 50
            elseif item.subtype == "Leather" then
                armorBonus = 30
            elseif item.subtype == "Cloth" then
                armorBonus = 20
            end
        elseif class == "DRUID" or class == "ROGUE" then
            if item.subtype == "Leather" then
                armorBonus = 50
            elseif item.subtype == "Cloth" then
                armorBonus = 30
            end
        else -- PRIEST, MAGE, WARLOCK
            if item.subtype == "Cloth" then
                armorBonus = 50
            end
        end
        
        armorScore = armorScore + armorBonus
    end
    
    return armorScore
end

function JG:GetStatValue(stats, statName)
    -- Map common stat names to their actual keys in GetItemStats
    local statMap = {
        Armor = "RESISTANCE0_NAME",
        Stamina = "ITEM_MOD_STAMINA_SHORT", 
        Strength = "ITEM_MOD_STRENGTH_SHORT",
        Agility = "ITEM_MOD_AGILITY_SHORT",
        Intellect = "ITEM_MOD_INTELLECT_SHORT",
        Spirit = "ITEM_MOD_SPIRIT_SHORT",
        Defense = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
        Dodge = "ITEM_MOD_DODGE_RATING_SHORT",
        Parry = "ITEM_MOD_PARRY_RATING_SHORT",
        Block = "ITEM_MOD_BLOCK_RATING_SHORT",
        Hit = "ITEM_MOD_HIT_RATING_SHORT",
        Crit = "ITEM_MOD_CRIT_RATING_SHORT",
        Haste = "ITEM_MOD_HASTE_RATING_SHORT",
        SpellPower = "ITEM_MOD_SPELL_POWER_SHORT",
        SpellHit = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
        SpellCrit = "ITEM_MOD_CRIT_SPELL_RATING_SHORT",
        MP5 = "ITEM_MOD_MANA_REGENERATION_SHORT",
        AttackPower = "ITEM_MOD_ATTACK_POWER_SHORT"
    }
    
    local statKey = statMap[statName] or statName
    return stats[statKey] or 0
end