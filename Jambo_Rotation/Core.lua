local ADDON, NS = ...
_G.JamboRotation = NS

JamboRotationDB = JamboRotationDB or {}

NS.Rot = {}
local Rot = NS.Rot

Rot.Conditions = {}
function Rot:RegisterCondition(type, checkFunc)
    Rot.Conditions[type] = checkFunc
end

function Rot:InitDB()
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    if not JamboRotationDB[charKey] then
        JamboRotationDB[charKey] = { steps = {} }
    end
    NS.db = JamboRotationDB[charKey]
end

-- --- JSON HELPER ---
local function Serialize(o)
    if type(o) == "number" then return o
    elseif type(o) == "string" then return string.format("%q", o):gsub("\n", "\\n")
    elseif type(o) == "boolean" then return tostring(o)
    elseif type(o) == "table" then
        local s = ""
        local isArray = (#o > 0)
        if isArray then
            s = "["
            for i, v in ipairs(o) do
                if i > 1 then s = s .. "," end
                s = s .. Serialize(v)
            end
            return s .. "]"
        else
            s = "{"
            local first = true
            for k, v in pairs(o) do
                if not first then s = s .. "," end
                s = s .. string.format("%q:%s", tostring(k), Serialize(v))
                first = false
            end
            return s .. "}"
        end
    else return "null" end
end

local function Deserialize(str)
    local luaStr = str:gsub("%[", "{"):gsub("%]", "}"):gsub('"([^"]+)":', '["%1"]=')
    local func, err = loadstring("return " .. luaStr)
    if func then
        setfenv(func, {}) 
        local success, res = pcall(func)
        if success and type(res) == "table" then return res end
    end
    return nil
end

function Rot:GetExportString()
    if not NS.db or not NS.db.steps then return "" end
    return Serialize(NS.db.steps)
end

function Rot:ImportString(str)
    local data = Deserialize(str)
    if data then
        NS.db.steps = data
        return true
    end
    return false
end

-- --- LOGIC ---

function Rot:GetGroupedSpells()
    local groups = {}
    local rawData = _G.JamboSpells and _G.JamboSpells.data and _G.JamboSpells.data.spells
    if not rawData then return {} end

    for _, info in ipairs(rawData) do
        local name = info.NAME
        if not groups[name] then 
            groups[name] = { 
                name = name, 
                type = info.TYPE, 
                ranks = {},
                hasHPS = (info.HPS > 0),
                hasHPM = (info.HPM > 0),
                hasDPS = (info.DPS > 0),
                hasDPM = (info.DPM > 0)
            } 
        else
            if info.HPS > 0 then groups[name].hasHPS = true end
            if info.HPM > 0 then groups[name].hasHPM = true end
            if info.DPS > 0 then groups[name].hasDPS = true end
            if info.DPM > 0 then groups[name].hasDPM = true end
        end
        table.insert(groups[name].ranks, info)
    end
    return groups
end

function Rot:EvaluateConditions(step)
    if not step.conditions or #step.conditions == 0 then return true, {} end
    local allPass = true
    local results = {}
    
    for i, cond in ipairs(step.conditions) do
        local check = Rot.Conditions[cond.type]
        local pass = false
        local note = ""
        local value = 0
        
        if check then
            pass, note, value = check(cond, step)
        end
        
        local expected = (cond.expected == nil) and true or cond.expected
        if pass ~= expected then pass = false else pass = true end
        
        table.insert(results, { type=cond.type, pass=pass, note=note, val=value })
        if not pass then allPass = false end
    end
    return allPass, results
end

function Rot:ResolveStep(step)
    local pass = Rot:EvaluateConditions(step)
    if not pass then return nil end

    local groups = Rot:GetGroupedSpells()
    local group = groups[step.name]
    if not group then return nil end
    
    local candidates = {}
    for _, info in ipairs(group.ranks) do
        if info.SLOT and info.SLOT > 0 then
            table.insert(candidates, info)
        end
    end
    
    if #candidates == 0 then return nil end
    
    local crit = step.criteria or "RANK"
    table.sort(candidates, function(a,b)
        local vA = a[crit] or 0
        local vB = b[crit] or 0
        if vA == vB then return a.RANK > b.RANK end
        return vA > vB
    end)
    
    return candidates[1]
end

-- API
function Rot:AddStep(name, criteria, note)
    table.insert(NS.db.steps, { name = name, criteria = criteria, note = note, conditions = {} })
end
function Rot:UpdateStep(index, name, criteria, note)
    local step = NS.db.steps[index]
    if step then 
        step.name = name
        step.criteria = criteria 
        step.note = note
    end
end
function Rot:RemoveStep(index) table.remove(NS.db.steps, index) end
function Rot:MoveStep(index, direction)
    local list = NS.db.steps
    if direction == -1 and index > 1 then list[index], list[index-1] = list[index-1], list[index]
    elseif direction == 1 and index < #list then list[index], list[index+1] = list[index+1], list[index] end
end
function Rot:AddCondition(stepIndex, data)
    local step = NS.db.steps[stepIndex]
    if step then step.conditions = step.conditions or {}; local n={}; for k,v in pairs(data) do n[k]=v end; table.insert(step.conditions, n) end
end
function Rot:UpdateCondition(stepIndex, condIndex, data)
    local step = NS.db.steps[stepIndex]
    if step and step.conditions[condIndex] then local n={}; for k,v in pairs(data) do n[k]=v end; step.conditions[condIndex]=n end
end
function Rot:RemoveCondition(stepIndex, condIndex)
    local step = NS.db.steps[stepIndex]
    if step and step.conditions then table.remove(step.conditions, condIndex) end
end
function Rot:MoveCondition(stepIndex, condIndex, direction)
    local step = NS.db.steps[stepIndex]
    if not step or not step.conditions then return end
    local list = step.conditions
    if direction == -1 and condIndex > 1 then list[condIndex], list[condIndex-1] = list[condIndex-1], list[condIndex]
    elseif direction == 1 and condIndex < #list then list[condIndex], list[condIndex+1] = list[condIndex+1], list[condIndex] end
end

-- Loop & Init
local timer = 0
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(self, elapsed)
    timer = timer + elapsed
    if timer < 0.1 then return end
    timer = 0
    if not NS.db then Rot:InitDB() end
    if not NS.db then return end
    local bestSlot = 2
    for _, step in ipairs(NS.db.steps) do
        local bestSpell = Rot:ResolveStep(step)
        if bestSpell then bestSlot = bestSpell.SLOT; break end
    end
    if JamboSpells and JamboSpells.SetActionSlot then JamboSpells:SetActionSlot(bestSlot) end
end)
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() Rot:InitDB() end)