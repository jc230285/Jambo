local addonName, addon = ...
local S = {}
addon.Scoring = S

-- Mapping standard stats to the keys in the weights table
-- You may need to expand this based on what GetItemStats returns in your specific client version
local STAT_MAP = {
    ["ITEM_MOD_AGILITY_SHORT"] = "AGILITY",
    ["ITEM_MOD_STRENGTH_SHORT"] = "STRENGTH",
    ["ITEM_MOD_INTELLECT_SHORT"] = "INTELLECT",
    ["ITEM_MOD_SPIRIT_SHORT"] = "SPIRIT",
    ["ITEM_MOD_STAMINA_SHORT"] = "STAMINA",
    ["ITEM_MOD_CRIT_RATING_SHORT"] = "CRIT",
    ["ITEM_MOD_HASTE_RATING_SHORT"] = "HASTE",
    ["ITEM_MOD_HIT_RATING_SHORT"] = "HIT",
    ["ITEM_MOD_MASTERY_RATING_SHORT"] = "MASTERY",
    ["ITEM_MOD_PARRY_RATING_SHORT"] = "PARRY",
    ["ITEM_MOD_DODGE_RATING_SHORT"] = "DODGE",
    ["ITEM_MOD_SPELL_POWER_SHORT"] = "SPELL_DAMAGE_DONE", -- Approximation for generic SP
    ["ITEM_MOD_ATTACK_POWER_SHORT"] = "ATTACK_POWER",
    -- Add more mappings as required by the client API
}

function S:CalculateItemScore(itemLink, weights)
    if not itemLink or not weights then return 0 end
    
    local stats = GetItemStats(itemLink)
    local score = 0
    
    if stats then
        for stat, value in pairs(stats) do
            local key = STAT_MAP[stat]
            if key and weights[key] then
                score = score + (value * weights[key])
            end
        end
    end
    
    -- Handle raw DPS if present in weights
    -- Note: This requires parsing the item tooltip or using specific APIs
    -- For lightweight purposes, we assume GetItemStats covers secondary stats. 
    -- If DPS is crucial, use GetItemInfo detail.
    local _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = GetItemInfo(itemLink)
    -- Simplified Logic: Add specific weapon DPS logic here if needed.
    
    return score
end

function S:GetBestLoadoutForSpec(specName)
    local allWeights = addon:GetClassWeights()
    local weights
    
    for _, specData in ipairs(allWeights) do
        if specData.name == specName then
            weights = specData.weights
            break
        end
    end
    
    if not weights then return nil end

    -- 1. Scan Bags and Inventory for all equipable items
    local candidates = {
        ["INVTYPE_HEAD"] = {}, ["INVTYPE_NECK"] = {}, ["INVTYPE_SHOULDER"] = {},
        ["INVTYPE_CHEST"] = {}, ["INVTYPE_WAIST"] = {}, ["INVTYPE_LEGS"] = {},
        ["INVTYPE_FEET"] = {}, ["INVTYPE_WRIST"] = {}, ["INVTYPE_HAND"] = {},
        ["INVTYPE_FINGER"] = {}, ["INVTYPE_TRINKET"] = {}, ["INVTYPE_CLOAK"] = {},
        ["INVTYPE_WEAPON"] = {}, ["INVTYPE_SHIELD"] = {}, ["INVTYPE_2HWEAPON"] = {},
        ["INVTYPE_WEAPONMAINHAND"] = {}, ["INVTYPE_WEAPONOFFHAND"] = {}, ["INVTYPE_HOLDABLE"] = {}
    }

    local function ScanLocation(bagId)
        local numSlots = C_Container.GetContainerNumSlots(bagId)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagId, slot)
            if info then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(info.hyperlink)
                if equipLoc and candidates[equipLoc] then
                    local score = S:CalculateItemScore(info.hyperlink, weights)
                    table.insert(candidates[equipLoc], { link = info.hyperlink, score = score, bag = bagId, slot = slot })
                end
            end
        end
    end

    -- Scan Backpack (0-4)
    for i = 0, 4 do ScanLocation(i) end
    
    -- Helper to find best single item
    local function GetBest(equipLoc)
        local best = nil
        local maxScore = -1
        local list = candidates[equipLoc]
        if not list then return nil, 0 end
        
        for _, item in ipairs(list) do
            if item.score > maxScore then
                maxScore = item.score
                best = item
            end
        end
        return best, maxScore
    end

    local loadout = {}

    -- Handle Simple Slots
    local simpleSlots = {"INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_CLOAK"}
    for _, loc in ipairs(simpleSlots) do
        loadout[loc], _ = GetBest(loc)
    end

    -- Handle Weapon Logic (2H vs MH/OH)
    -- Group 1: Two Handed
    local best2H, score2H = GetBest("INVTYPE_2HWEAPON")
    
    -- Group 2: Main Hand (Includes One-Handers that can be MH)
    -- We need to merge INVTYPE_WEAPON (One-Hand) into MH and OH pools conceptually
    -- For this simplified version, we treat specific types.
    local bestMH, scoreMH = GetBest("INVTYPE_WEAPONMAINHAND")
    local bestGenericMH, scoreGenericMH = GetBest("INVTYPE_WEAPON") -- One-Handers
    
    if scoreGenericMH > scoreMH then
        bestMH = bestGenericMH
        scoreMH = scoreGenericMH
    end

    -- Group 3: Off Hand (Shields, Off-hands, or One-Handers if dual wield is allowed)
    local bestOH, scoreOH = GetBest("INVTYPE_SHIELD")
    local bestHoldable, scoreHoldable = GetBest("INVTYPE_HOLDABLE")
    local bestWeaponOH, scoreWeaponOH = GetBest("INVTYPE_WEAPONOFFHAND")
    
    -- Logic to pick absolute best OH
    local actualBestOH = bestOH
    local actualScoreOH = scoreOH
    
    if scoreHoldable > actualScoreOH then actualBestOH = bestHoldable; actualScoreOH = scoreHoldable end
    if scoreWeaponOH > actualScoreOH then actualBestOH = bestWeaponOH; actualScoreOH = scoreWeaponOH end
    
    -- Can user Dual Wield? (Check class/spec or assume yes for simplified logic if strict weights provided)
    -- If the class can dual wield, we should also check the "INVTYPE_WEAPON" pool again excluding the one picked for MH
    
    -- Comparison
    if score2H > (scoreMH + actualScoreOH) then
        loadout["MAIN_HAND"] = best2H
        loadout["OFF_HAND"] = nil
    else
        loadout["MAIN_HAND"] = bestMH
        loadout["OFF_HAND"] = actualBestOH
    end

    return loadout
end