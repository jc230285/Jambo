local ADDON, NS = ...
local C = NS.Constants

NS.Groups = {}
NS.Groups.rowsData = {} 

function NS.Groups:UpdateList()
    local priority, harm, friendly, enemy, dead = {}, {}, {}, {}, {}
    
    local pctThreshold = NS.db.options.targetDeficitPercent or 0
    local hpThreshold = NS.db.options.targetDeficitHP or 0
    
    local healSpell = NS.db.options.targetHealSpellId and GetSpellInfo(NS.db.options.targetHealSpellId)
    local harmSpell = NS.db.options.targetHarmSpellId and GetSpellInfo(NS.db.options.targetHarmSpellId)
    
    local partyMaxHP = 0
    
    -- 1. Calculate Party Max HP
    for _, unitInfo in pairs(NS.units) do
        local uid = unitInfo.unitid
        if UnitExists(uid) then
            local max = UnitHealthMax(uid)
            if max > partyMaxHP then partyMaxHP = max end
        end
    end
    
    if NS.UI and NS.UI.frame and NS.UI.frame.deficitHPSlider then
        local slider = NS.UI.frame.deficitHPSlider
        local currentMax = select(2, slider:GetMinMaxValues())
        if partyMaxHP > currentMax then slider:SetMinMaxValues(0, partyMaxHP) end
    end
    
    local deficitFromPct = (pctThreshold / 100) * partyMaxHP
    
    -- 2. Sort Units into Groups
    for _, unitInfo in pairs(NS.units) do
        local uid = unitInfo.unitid
        if UnitExists(uid) then
            local hp = UnitHealth(uid)
            local max = UnitHealthMax(uid)
            if max == 0 then max = 1 end
            
            local deficit = max - hp
            local pct = math.floor((hp/max)*100)
            local threat = NS:GetThreatRatio(uid) or 0
            
            local entry = {
                uid = uid, name = UnitName(uid),
                hp = hp, maxhp = max, pct = pct,
                deficit = deficit, threat = threat,
                priority = unitInfo.priority or 999
            }
            
            if UnitIsDeadOrGhost(uid) then
                if UnitCanAttack("player", uid) then 
                    entry.groupType = "ENEMY"
                    table.insert(dead, entry) 
                end
                
            elseif UnitIsFriend("player", uid) then
                entry.groupType = "FRIENDLY"
                local isPriority = false
                local hitHP = (hpThreshold > 0 and deficit >= hpThreshold)
                local hitPct = (pctThreshold > 0 and deficit >= deficitFromPct)
                
                if (hitHP or hitPct) then
                    if not healSpell or IsSpellInRange(healSpell, uid) == 1 then
                        isPriority = true
                    end
                end
                
                if isPriority then table.insert(priority, entry)
                else table.insert(friendly, entry) end
                
            elseif UnitCanAttack("player", uid) then
                entry.groupType = "ENEMY"
                if harmSpell and IsSpellInRange(harmSpell, uid) == 1 then
                    table.insert(harm, entry)
                else
                    table.insert(enemy, entry)
                end
            else
                entry.groupType = "FRIENDLY"
                table.insert(friendly, entry)
            end
        end
    end
    
    -- 3. Sort Functions
    local function SortFriendly(a,b) 
        if a.deficit ~= b.deficit then return a.deficit > b.deficit end
        return a.priority < b.priority
    end
    
    local function SortEnemy(a,b) 
        if a.hp ~= b.hp then return a.hp < b.hp end
        return a.priority < b.priority
    end
    
    local function SortIndex(a,b) return a.priority < b.priority end
    
    table.sort(priority, SortFriendly)
    table.sort(friendly, SortFriendly)
    table.sort(harm, SortEnemy)
    table.sort(enemy, SortEnemy)
    table.sort(dead, SortIndex)
    
    -- 4. Determine BEST UNIT for Data Square (UPDATED)
    -- Hierarchy: Priority Heal > Harm Target > Friendly (e.g. Self) > Any Enemy
    local bestIdx = 255
    
    if #priority > 0 then
        bestIdx = priority[1].priority
    elseif #harm > 0 then
        bestIdx = harm[1].priority
    elseif #friendly > 0 then
        bestIdx = friendly[1].priority -- FIX: Now considers Friendly list (like yourself)
    elseif #enemy > 0 then
        bestIdx = enemy[1].priority
    end
    
    -- EXPORT GLOBAL FOR DATA SQUARE
    if JamboTarget then
        JamboTarget.BestUnitIndex = bestIdx
    end

    -- 5. Flatten for UI
    self.rowsData = {}
    
    if #priority > 0 then
        table.insert(self.rowsData, {isHeader=true, text=string.format("PRIORITY HEALS (Sort: Highest Deficit)")})
        for _, v in ipairs(priority) do table.insert(self.rowsData, v) end
    end
    
    if #harm > 0 then
        table.insert(self.rowsData, {isHeader=true, text="ENEMIES (Sort: Lowest HP)"})
        for _, v in ipairs(harm) do table.insert(self.rowsData, v) end
    end
    
    if #friendly > 0 then
        table.insert(self.rowsData, {isHeader=true, text="FRIENDLY (Sort: Highest Deficit)"})
        for _, v in ipairs(friendly) do table.insert(self.rowsData, v) end
    end
    
    if #enemy > 0 then
        table.insert(self.rowsData, {isHeader=true, text="ENEMIES (Out of Range)"})
        for _, v in ipairs(enemy) do table.insert(self.rowsData, v) end
    end
    
    if #dead > 0 then
        table.insert(self.rowsData, {isHeader=true, text="DEAD"})
        for _, v in ipairs(dead) do table.insert(self.rowsData, v) end
    end

    if NS.UI and NS.UI.RedrawRows then
        NS.UI:RedrawRows()
    end
end