local ADDON, NS = ...
local C = NS.Constants

NS.Groups = {}
NS.Groups.rowsData = {} 

-- Local reference to distance API if available
local GetDist = UnitDistanceSquared 

-- Called by Core on Roster Update or Login
function NS.Groups:RecalculateLimits()
    local minMax = 9999999
    
    -- Always check player first
    local pMax = UnitHealthMax("player")
    if pMax and pMax > 0 then minMax = pMax end
    
    -- Check Group
    if IsInGroup() then
        local members = GetNumGroupMembers()
        local prefix = IsInRaid() and "raid" or "party"
        
        -- Iterate group slots (Note: GetNumGroupMembers includes player in raid, but party1..4 are separate)
        if prefix == "party" then
            for i = 1, 4 do
                local unit = "party"..i
                if UnitExists(unit) then
                    local m = UnitHealthMax(unit)
                    if m > 0 and m < minMax then minMax = m end
                end
            end
        else
            for i = 1, 40 do
                local unit = "raid"..i
                if UnitExists(unit) then
                    local m = UnitHealthMax(unit)
                    if m > 0 and m < minMax then minMax = m end
                end
            end
        end
    end
    
    -- Sanity check
    if minMax == 9999999 then minMax = 1000 end
    
    -- Send to UI if loaded
    if NS.UI and NS.UI.UpdateSliderLimit then
        NS.UI:UpdateSliderLimit(minMax)
    end
end

function NS.Groups:UpdateList()
    local gPriority = {}   
    local gHarm = {}       
    local gFriendInj = {}  
    local gEnemyOther = {} 
    local gFriendOther = {}
    
    local showAll = NS.db.options.showAllGroups or false
    
    -- Settings
    local pctThreshold = NS.db.options.targetDeficitPercent or 0
    local hpThreshold = NS.db.options.targetDeficitHP or 0
    
    local healSpellName = nil
    if NS.db.options.targetHealSpellId then
        healSpellName = GetSpellInfo(NS.db.options.targetHealSpellId)
    end
    
    local harmSpellName = nil
    if NS.db.options.targetHarmSpellId then
        harmSpellName = GetSpellInfo(NS.db.options.targetHarmSpellId)
    end
    
    local sortMode = NS.db.options.enemySortMode or C.SORT_HP_ASC

    -- 2. Sort Units
    for _, unitInfo in pairs(NS.units) do
        local uid = unitInfo.unitid
        if UnitExists(uid) then
            local hp = UnitHealth(uid)
            local max = UnitHealthMax(uid)
            if max == 0 then max = 1 end
            
            local incoming = UnitGetIncomingHeals(uid) or 0
            local deficit = max - hp
            local effectiveDeficit = deficit - incoming
            local pct = math.floor((hp/max)*100)
            local threat = NS:GetThreatRatio(uid) or 0
            
            local dist = 99999
            if GetDist then 
                local d = GetDist("player", uid)
                if d then dist = d end
            end

            local entry = {
                uid = uid, name = UnitName(uid),
                hp = hp, maxhp = max, pct = pct,
                deficit = deficit, effectiveDeficit = effectiveDeficit,
                threat = threat, priority = unitInfo.priority or 999,
                dist = dist
            }
            
            local isDead = UnitIsDeadOrGhost(uid)
            local isFriend = UnitIsFriend("player", uid)
            local assigned = false

            -- A. PRIORITY HEALS
            if healSpellName and isFriend and not isDead then
                local hitPct = (pctThreshold > 0 and pct <= pctThreshold)
                local hitHP = (hpThreshold > 0 and deficit >= hpThreshold)
                
                if (hitPct or hitHP) then
                    if IsSpellInRange(healSpellName, uid) == 1 then
                        entry.isPriority = true
                        table.insert(gPriority, entry)
                        assigned = true
                    end
                end
            end
            
            if not assigned then
                if not isFriend and not isDead then
                    -- B. ENEMIES
                    local inRange = true
                    if harmSpellName and IsSpellInRange(harmSpellName, uid) ~= 1 then inRange = false end
                    
                    if inRange then table.insert(gHarm, entry)
                    else table.insert(gEnemyOther, entry) end
                    
                elseif isFriend and not isDead then
                    -- C. FRIENDLY INJURED
                    if deficit > 0 then table.insert(gFriendInj, entry)
                    else table.insert(gFriendOther, entry) end
                
                else
                    -- Dead
                    if isFriend then table.insert(gFriendOther, entry)
                    else table.insert(gEnemyOther, entry) end
                end
            end
        end
    end
    
    local function SortPrio(a,b)
        if a.effectiveDeficit ~= b.effectiveDeficit then return a.effectiveDeficit > b.effectiveDeficit end
        return a.priority < b.priority
    end
    local function SortDeficit(a,b)
        if a.deficit ~= b.deficit then return a.deficit > b.deficit end
        return a.priority < b.priority
    end
    local function SortEnemy(a,b)
        if sortMode == C.SORT_HP_ASC then
             if a.hp ~= b.hp then return a.hp < b.hp end
        elseif sortMode == C.SORT_HP_DESC then
             if a.hp ~= b.hp then return a.hp > b.hp end
        elseif sortMode == C.SORT_THREAT_ASC then
             if a.threat ~= b.threat then return a.threat < b.threat end
        elseif sortMode == C.SORT_THREAT_DESC then
             if a.threat ~= b.threat then return a.threat > b.threat end
        end
        return a.priority < b.priority
    end
    local function SortRange(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.priority < b.priority
    end
    
    table.sort(gPriority, SortPrio)
    table.sort(gHarm, SortEnemy)
    table.sort(gFriendInj, SortDeficit)
    table.sort(gEnemyOther, SortRange)
    table.sort(gFriendOther, SortDeficit)
    
    local bestIdx = 255
    if #gPriority > 0 then bestIdx = gPriority[1].priority
    elseif #gHarm > 0 then bestIdx = gHarm[1].priority
    elseif #gFriendInj > 0 then bestIdx = gFriendInj[1].priority
    elseif #gEnemyOther > 0 then bestIdx = gEnemyOther[1].priority
    end
    if JamboTarget then JamboTarget.BestUnitIndex = bestIdx end

    self.rowsData = {}
    
    local function AddGroup(list, title, filterText)
        if #list > 0 or showAll then
            local fullTitle = string.format("%s %s", title, filterText or "")
            table.insert(self.rowsData, {isHeader=true, text=fullTitle})
            for _, v in ipairs(list) do table.insert(self.rowsData, v) end
            if #list == 0 and showAll then
                table.insert(self.rowsData, {isHeader=true, text="  (Empty)"})
            end
        end
    end
    
    local prioInfo = ""
    if healSpellName then
        prioInfo = string.format("(<%d%% or >%d HP | %s)", pctThreshold, hpThreshold, healSpellName)
    else
        prioInfo = "(DISABLED - No Heal Spell)"
    end
    
    local harmInfo = ""
    if harmSpellName then harmInfo = string.format("(%s In Range)", harmSpellName) end

    AddGroup(gPriority, "PRIORITY HEALS", prioInfo)
    AddGroup(gHarm, "ENEMIES", harmInfo)
    AddGroup(gFriendInj, "FRIENDLY", "(Deficit > 0)")
    AddGroup(gEnemyOther, "OTHER ENEMIES", "(Sort: Range)") 
    AddGroup(gFriendOther, "OTHER FRIENDLIES", "(Full HP/Dead)")

    if NS.UI and NS.UI.RedrawRows then
        NS.UI:RedrawRows()
    end
end