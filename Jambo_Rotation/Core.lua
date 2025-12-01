local ADDON, NS = ...

JamboRotDB = JamboRotDB or {}

NS.db = JamboRotDB
NS.db.rotation = NS.db.rotation or {}

NS.Rot = {}
local Rot = NS.Rot
Rot.autoRescanOnLogin = false -- disable automatic rescan at login by default to avoid duplicate work
Rot.debug = false -- enable debug printing when true

-- Pull spell data from Jambo_Spells if available
-- SpellDB reference will be looked up dynamically inside functions so it works when the spells addon
-- loads after the rot addon.

------------------------------------------------------------
-- Utility: get all spells by name (including unlearned)
------------------------------------------------------------
function Rot:GetAllSpells()
    local list = {}
    -- Prefer to get the live addon object if it's loaded (supports dynamic updates)
    local SpellsAddon = _G["Jambo_Spells"] or _G["Jambo Spells"]
    local SpellDB = nil
    if SpellsAddon and SpellsAddon.db and SpellsAddon.db.data and SpellsAddon.db.data.spells then
        SpellDB = SpellsAddon.db.data.spells
    else
        SpellDB = (Jambo_SpellsDB and Jambo_SpellsDB.data and Jambo_SpellsDB.data.spells) or {}
    end

    for _, entry in pairs(SpellDB) do
        if entry.name then
            list[entry.name] = list[entry.name] or {}
            -- Ensure fields we rely on are present and normalize field names
            local e = {
                id = entry.id,
                name = entry.name,
                rankIndex = entry.rankIndex or entry.rank or 0,
                rankText = entry.rankText or (entry.rank and ("Rank "..tostring(entry.rank))) or (entry.rankIndex and ("Rank "..tostring(entry.rankIndex))) or "",
                range = entry.range,
                known = entry.known,
                levelReq = entry.levelReq,
                -- preserve raw entry for any other lookups
                __raw = entry,
            }
            -- copy common metric fields (if present in the entry)
            e.dps = entry.dps
            e.dpm = entry.dpm
            e.hps = entry.hps
            e.hpm = entry.hpm
            table.insert(list[entry.name], e)
        end
    end

    -- Sort ranks
    for name, ranks in pairs(list) do
        table.sort(ranks, function(a,b)
            return (a.rankIndex or 0) < (b.rankIndex or 0)
        end)
    end

    -- If no spells in SpellDB (addon not loaded), fallback to scanning player's spellbook
    if next(list) == nil then
        if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
            for tab = 1, (GetNumSpellTabs() or 0) do
                local name, texture, offset, numSlots = GetSpellTabInfo(tab)
                for i = 1, (numSlots or 0) do
                    local slot = offset + i
                    local sname, srank = GetSpellBookItemName(slot, "spell")
                    if sname then
                        local link = GetSpellLink and GetSpellLink(slot, "spell")
                        local id = nil
                        if link then id = tonumber(link:match("|Hspell:(%d+)|h")) end
                        list[sname] = list[sname] or {}
                        table.insert(list[sname], {
                            id = id,
                            name = sname,
                            rankIndex = tonumber((srank or ""):match("%d+")) or 0,
                            rankText = srank or "",
                            known = true,
                            range = nil,
                            levelReq = nil,
                            __raw = nil,
                        })
                    end
                end
            end
        end
    end

    return list
end

-- Find a spell ID by spell name by scanning the Spells DB first then the player's spellbook
function Rot:FindSpellIdByName(name)
    if not name then return nil end
    -- Check Spells DB
    local spells = Rot:GetAllSpells()[name]
    if spells and #spells > 0 then
        for _, r in ipairs(spells) do
            if r.id then return r.id end
        end
    end
    -- Fallback: scan player's spellbook
    if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
        for tab = 1, (GetNumSpellTabs() or 0) do
            local tname, ttexture, offset, numSlots = GetSpellTabInfo(tab)
            for i = 1, (numSlots or 0) do
                local slot = offset + i
                local sname, srank = GetSpellBookItemName(slot, "spell")
                if sname and sname == name then
                    local link = GetSpellLink and GetSpellLink(slot, "spell")
                    if link then
                        local id = tonumber(link:match("|Hspell:(%d+)|h"))
                        if id then return id end
                    end
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------
-- Auto-rank resolver
------------------------------------------------------------
local function BestRankByMetric(ranks, metric)
    local best
    local bestValue = -math.huge

    for _, r in ipairs(ranks) do
        local v = r[metric]
        if v and v > bestValue then
            bestValue = v
            best = r
        end
    end

    return best
end

local AutoMetrics = {
    ["Auto - Best DPS"] = "dps",
    ["Auto - Best DPM"] = "dpm",
    ["Auto - Best HPS"] = "hps",
    ["Auto - Best HPM"] = "hpm",
}

function Rot:ResolveRank(name, selected)
    local spells = Rot:GetAllSpells()[name]
    if not spells then return nil end

    -- Specific rank?
    if tonumber(selected) then
        for _, r in ipairs(spells) do
            if (r.rankIndex or r.rank) == tonumber(selected) then
                return r
            end
        end
    end

    -- Auto rank?
    local metric = AutoMetrics[selected]
    if metric then
        return BestRankByMetric(spells, metric)
    end

    return spells[#spells] -- fallback highest
end

------------------------------------------------------------
-- Rotation management
------------------------------------------------------------
function Rot:AddStep(name, rank, rankIndex, spellId)
    -- try to auto-resolve spellId if not provided
    local resolvedSpellId = spellId
    if not resolvedSpellId and rankIndex and Rot and Rot.ResolveRank then
        local r = Rot:ResolveRank(name, rankIndex or rank)
        if r and r.id then resolvedSpellId = r.id end
    end
    table.insert(NS.db.rotation, {
        spell = name,
        rank  = rank,
        rankIndex = rankIndex,
        spellId = resolvedSpellId,
        macroName = nil,
        isMacro = false,
        slotId = nil,
    })
    -- Try to immediately resolve the slot if a spellId exists
    if resolvedSpellId and type(GetActionInfo) == "function" then
        local foundSlot = nil
        for s = 1, 120 do
            local atype, aid = GetActionInfo(s)
            if atype == "spell" and aid == resolvedSpellId then
                foundSlot = s; break
            elseif atype == "macro" and aid == resolvedSpellId then
                foundSlot = s; break
            end
        end
        if foundSlot then
            NS.db.rotation[#NS.db.rotation].slotId = foundSlot
        end
    end
    -- ensure global savedvar references updated
    JamboRotDB = NS.db
end

-- Try to resolve spell IDs (and macro ids) for steps that don't have them stored
function Rot:RescanSpellIds()
    if not NS or not NS.db or not NS.db.rotation then return end
    local SpellList = Rot:GetAllSpells()
    for _, step in ipairs(NS.db.rotation) do
        -- Always attempt to re-detect macros by name so we can correct for re-indexed macro IDs
        -- e.g., users re-order macros, which changes the numeric ID but keeps the name
        -- We'll prefer updating the existing `step.spellId` for macros if the name matches
        -- (we still allow non-macro steps to be skipped as before)
        -- if it's a macro name, find macro id
        local wasMacro = false
        if type(GetNumMacros) == "function" then
            local n = GetNumMacros() or 0
            local function norm(s) if not s then return "" end return s:lower():gsub("[^%w]","") end
            for i = 1, n do
                local mname = select(1, GetMacroInfo(i))
                if mname and step.spell and (norm(mname) == norm(step.spell) or (step.macroName and norm(mname) == norm(step.macroName))) then
                    step.spellId = i -- macro id stored as spellId for macros
                    step.isMacro = true
                    step.macroName = mname
                    wasMacro = true
                    break
                end
            end
        end
        if not wasMacro and (not step.spellId or step.spellId == 0) then
            -- try resolve via spell DB
            if not step.spellId and SpellList and SpellList[step.spell] then
                local ranks = SpellList[step.spell]
                local resolved = nil
                if step.rankIndex then
                    for _, r in ipairs(ranks) do if r.rankIndex == step.rankIndex then resolved = r; break end end
                end
                if not resolved then
                    -- fallback to last rank / highest
                    resolved = ranks[#ranks]
                end
                if resolved and resolved.id then
                    step.spellId = resolved.id
                end
            else
                -- SpellDB didn't contain the spell (or we failed). Try scanning player's spellbook as a fallback.
                if not step.spellId and type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
                    -- naive scan through tabs for a matching name
                    for tab = 1, (GetNumSpellTabs() or 0) do
                        local name, texture, offset, numSlots = GetSpellTabInfo(tab)
                        for i = 1, (numSlots or 0) do
                            local slot = offset + i
                            local sname, srank = GetSpellBookItemName(slot, "spell")
                            if sname and sname == step.spell then
                                -- try to pick a spell id from the link
                                local link = GetSpellLink and GetSpellLink(slot, "spell")
                                if link then
                                    local id = tonumber(link:match("|Hspell:(%d+)|h"))
                                    if id then
                                        step.spellId = id
                                        print(string.format("Rot: RescanSpellIds found spellId %s for step '%s' from spellbook slot %d", tostring(id), tostring(step.spell), slot))
                                        break
                                    end
                                end
                            end
                        end
                        if step.spellId then break end
                    end
                end
            end
        end
    end
    JamboRotDB = NS.db
end

-- Scan action bar slots and map them to rotation steps (persist slot id to step.slotId)
function Rot:RescanStepSlots()
    if not NS or not NS.db or not NS.db.rotation then return end
    -- clear existing slot assignments
    for _, step in ipairs(NS.db.rotation) do step.slotId = nil end
    if type(GetActionInfo) ~= "function" then return end
    local function norm(s) if not s then return "" end return s:lower():gsub("[^%w]","") end
    for slot = 1, 120 do
        local atype, id = GetActionInfo(slot)
        -- Only log non-empty action slots to avoid chat spam
        if atype and id then
            print(string.format("Rot: scanning slot %d -> type=%s id=%s", slot, tostring(atype), tostring(id)))
        end
        if atype == "spell" and id and id > 0 then
            -- try match by stored id
            local i, step = Rot:FindStepById(id)
            if step and i then
                step.slotId = slot
                if not step.spellId then
                    -- if step doesn't have an ID yet, populate it with the id provided by the actionbutton
                    step.spellId = id
                    if Rot.debug then print(string.format("Rot: set step %d spellId=%s from actionbar slot %d", i, tostring(id), slot)) end
                end
                if Rot.debug then print(string.format("Rot: matched slot %d to step %d (id=%s) by id", slot, i, tostring(id))) end
            else
                -- match by name fallback
                local sname = GetSpellInfo(id)
                if sname then
                    local j, stepb = Rot:FindStepIndexForSpell(sname)
                    if stepb and j then
                        stepb.slotId = slot
                        -- When matching by name, persist the actionbar id as the spellId for accurate future matching.
                        if not stepb.spellId and id then
                            stepb.spellId = id
                            if Rot.debug then print(string.format("Rot: set step %d spellId=%s from actionbar id for name=%s", j, tostring(id), tostring(stepb.spell))) end
                        end
                        -- fallback: if we still don't have a spellId, try DB lookup
                        if not stepb.spellId then
                            local sid = Rot:FindSpellIdByName(stepb.spell)
                            if sid then
                                stepb.spellId = sid
                                if Rot.debug then print(string.format("Rot: set step %d spellId=%s from spellbook lookup for name=%s", j, tostring(sid), tostring(stepb.spell))) end
                            end
                        end
                        if Rot.debug then print(string.format("Rot: matched slot %d to step %d (name=%s) by name fallback", slot, j, tostring(stepb.spell))) end
                    else
                        if Rot.debug then print(string.format("Rot: no match for spell slot %d name=%s", slot, tostring(sname))) end
                    end
                end
            end
        elseif atype == "macro" and id and id > 0 then
            -- macro id match
            local i, step = Rot:FindStepById(id)
            if step and i then
                step.slotId = slot
                print(string.format("Rot: matched slot %d to step %d (id=%s) macro id match", slot, i, tostring(id)))
            end
            if Rot.debug then print(string.format("Rot: matched slot %d to step %d (id=%s) macro id match", slot, i, tostring(id))) end
            local mname = GetMacroInfo(id)
            if mname then
                local j, stepb = Rot:FindStepIndexForSpell(mname)
                if stepb and j then
                    stepb.slotId = slot
                    -- Persist macro id and macro name for future stable matching
                    stepb.spellId = id
                    stepb.isMacro = true
                    stepb.macroName = mname
                    print(string.format("Rot: matched slot %d to step %d (name=%s) macro name fallback", slot, j, tostring(stepb.spell)))
                end
                if Rot.debug then print(string.format("Rot: matched slot %d to step %d (name=%s) macro name fallback", slot, j, tostring(stepb.spell))) end
            else
                if Rot.debug then print(string.format("Rot: no match for macro slot %d name=%s", slot, tostring(mname))) end
            end
            -- try to match by stored macroName if prior matching didn't find anything
            if (not step or not step.slotId) and mname then
                local found = false
                for k, s in ipairs(NS.db.rotation) do
                    if s.isMacro and s.macroName and norm(s.macroName) == norm(mname) then
                        s.slotId = slot
                        s.spellId = id
                        found = true
                        if Rot.debug then print(string.format("Rot: matched slot %d to step %d by persisted macroName %s", slot, k, tostring(s.macroName))) end
                        break
                    end
                end
                if not found and Rot.debug then print(string.format("Rot: macro slot %d (%s) has no matching persisted macroName", slot, tostring(mname))) end
            end
        end
    end
    JamboRotDB = NS.db
end

-- Debug helper to print mapping of steps->spellId->slotId
function Rot:DumpStepMapping()
    if not NS or not NS.db or not NS.db.rotation then print("Rot: no rotation or NS.db") return end
    for i, step in ipairs(NS.db.rotation) do
        local sId = step.spellId or "<none>"
        local slot = step.slotId or "<none>"
        local mname = step.macroName and tostring(step.macroName) or "<none>"
        local isMacro = step.isMacro and "true" or "false"
        print(string.format("Rot Step %d: %s id=%s slot=%s isMacro=%s macroName=%s", i, tostring(step.spell), tostring(sId), tostring(slot), isMacro, mname))
    end
end

-- Diagnostic: report unmatched steps and possible matches on action bars
function Rot:ReportUnmatchedSteps()
    if not NS or not NS.db or not NS.db.rotation then print("Rot: no rotation or NS.db") return end
    print("Rot: Reporting unmatched steps and potential matches:")
    for i, step in ipairs(NS.db.rotation) do
        if not step.slotId then
            print(string.format("Step %d: %s id=%s slot=%s => searching action bar...", i, tostring(step.spell), tostring(step.spellId or '<none>'), tostring(step.slotId or '<none>')))
            -- scan all action slots and report any that match by name
            if type(GetActionInfo) == "function" then
                for slot = 1, 120 do
                    local atype, id = GetActionInfo(slot)
                    if atype == "spell" and id then
                        local sname = GetSpellInfo(id)
                        if sname and (type(step.spell) == 'string' and sname:lower():gsub("[^%w]","") == step.spell:lower():gsub("[^%w]","") ) then
                            print(string.format("  suggested match: slot %d is spell id=%s name=%s", slot, tostring(id), tostring(sname)))
                        end
                    elseif atype == "macro" and id then
                        local mname = GetMacroInfo(id)
                            if mname and step.spell and (mname:lower():gsub("[^%w]","") == step.spell:lower():gsub("[^%w]","") or (step.macroName and mname:lower():gsub("[^%w]","") == step.macroName:lower():gsub("[^%w]","")) ) then
                            print(string.format("  suggested match: slot %d is macro id=%s name=%s", slot, tostring(id), tostring(mname)))
                        end
                    end
                end
            end
            -- try to show DB ranks if present
            local ranks = Rot:GetAllSpells()[step.spell]
            if ranks and #ranks > 0 then
                for _, r in ipairs(ranks) do
                    print(string.format("  DB rank: id=%s rankIndex=%s rankText=%s known=%s", tostring(r.id), tostring(r.rankIndex), tostring(r.rankText), tostring(r.known)))
                end
            end
        end
    end
end

function Rot:RemoveStep(i)
    table.remove(NS.db.rotation, i)
    JamboRotDB = NS.db
end

function Rot:MoveUp(i)
    if i > 1 then
        NS.db.rotation[i], NS.db.rotation[i-1] = NS.db.rotation[i-1], NS.db.rotation[i]
    end
    JamboRotDB = NS.db
end

function Rot:MoveDown(i)
    local t = NS.db.rotation
    if i < #t then
        t[i], t[i+1] = t[i+1], t[i]
    end
    JamboRotDB = NS.db
end

------------------------------------------------------------
-- Bridge for UI
------------------------------------------------------------
function Rot:GetRotation() return NS.db.rotation end
------------------------------------------------------------
-- Condition system
------------------------------------------------------------
Rot.ConditionTypes = {
    { id="combat", label="Combat (In/Out)" },
}

Rot.ConditionValues = {
    combat = {
        { value=true,  label="In Combat" },
        { value=false, label="Out of Combat" },
    },
}

function Rot:AddCondition(stepIndex, conditionType, conditionValue)
    local step = NS.db.rotation[stepIndex]
    if not step then return end
    step.conditions = step.conditions or {}
    table.insert(step.conditions, {
        type  = conditionType,
        value = conditionValue,
    })
end

function Rot:RemoveCondition(stepIndex, condIndex)
    local step = NS.db.rotation[stepIndex]
    if not (step and step.conditions) then return end
    table.remove(step.conditions, condIndex)
end

-- Find a rotation step by spell/macro name
function Rot:FindStepForSpell(spellName)
    if not spellName or not NS or not NS.db or not NS.db.rotation then return nil end
    local function norm(s)
        if not s then return "" end
        return s:lower():gsub("[^%w]", "")
    end
    for _, step in ipairs(NS.db.rotation) do
        if step.spell == spellName or (type(step.spell) == 'string' and type(spellName) == 'string' and norm(step.spell) == norm(spellName)) then
            return step
        end
    end
    return nil
end

-- Find step index and step by spell name (case-insensitive)
function Rot:FindStepIndexForSpell(spellName)
    if not spellName or not NS or not NS.db or not NS.db.rotation then return nil end
    local function norm(s)
        if not s then return "" end
        return s:lower():gsub("[^%w]", "")
    end
    for i, step in ipairs(NS.db.rotation) do
        if step.spell == spellName or (type(step.spell) == 'string' and type(spellName) == 'string' and norm(step.spell) == norm(spellName)) then
            return i, step
        end
    end
    return nil
end

-- Find a rotation step by spellId (or macro id) - returns index & step
function Rot:FindStepById(spellId)
    if not spellId or not NS or not NS.db or not NS.db.rotation then return nil end
    for i, step in ipairs(NS.db.rotation) do
        if step.spellId and step.spellId == spellId then
            return i, step
        end
    end
    return nil
end

-- Evaluate conditions for a given step. Returns (allPass, condResults)
function Rot:EvaluateConditions(step)
    local results = {}
    if not step or not step.conditions or #step.conditions == 0 then
        return true, results
    end
    local allPass = true
    for i, cond in ipairs(step.conditions) do
        local ok = false
        if cond.type == "combat" then
            local inCombat = UnitAffectingCombat("player")
            if cond.value == true then ok = (inCombat == true) end
            if cond.value == false then ok = (inCombat == false) end
        else
            -- unknown condition types default to false
            ok = false
        end
        results[i] = { type = cond.type, value = cond.value, pass = ok }
        if not ok then allPass = false end
    end
    return allPass, results
end

-- Events: ensure saved vars exist and initialize UI on login
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        JamboRotDB = JamboRotDB or {}
        NS.db = JamboRotDB
        NS.db.rotation = NS.db.rotation or {}
    elseif event == "PLAYER_LOGIN" then
        if NS.UI and NS.UI.Init then NS.UI:Init() end
        -- initial rescan of steps/spells/slots (optional: only if enabled)
        if Rot and Rot.autoRescanOnLogin then
            if Rot and Rot.RescanSpellIds then pcall(Rot.RescanSpellIds, Rot) end
            if Rot and Rot.RescanStepSlots then pcall(Rot.RescanStepSlots, Rot) end
        end
    elseif event == "PLAYER_LOGOUT" then
        JamboRotDB = NS.db
    end
end)

