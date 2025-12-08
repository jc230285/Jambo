local ADDON, NS = ...

NS.Data = NS.Data or {}
NS.Book = NS.Book or {}

local Data = NS.Data
Data.isBuilding = false
local Utils = NS.Utils

local function scanActionBars()
    local map = {}
    for slot = 1, 120 do
        local t, id = GetActionInfo(slot)
        if t == "spell" then
            local name, rankTxt = GetSpellInfo(id)
            if name then
                local rank = tonumber(rankTxt and rankTxt:match("(%d+)") or "1") or 1
                map[name] = map[name] or {}
                table.insert(map[name], { slot = slot, id = id, rank = rank })
            end
        elseif t == "macro" then
            local macroName = GetMacroInfo(id)
            if macroName then
                map[macroName] = map[macroName] or {}
                table.insert(map[macroName], { slot = slot, id = id, rank = 0, isMacro = true })
            end
        end
    end
    return map
end

local function pickBestBar(entries)
    if not entries or #entries == 0 then return nil end
    local best = entries[1]
    for _, e in ipairs(entries) do if e.rank > best.rank then best = e end end
    return best
end

function Data:BuildBook()
    if Data.isBuilding then return end
    Data.isBuilding = true
    wipe(NS.Book)
    if not _G.JamboSpells or not _G.JamboSpells.data or not _G.JamboSpells.data.spells then Data.isBuilding = false; return end

    local bars = scanActionBars()
    local criteriaGroups = {}

    for _, info in ipairs(_G.JamboSpells.data.spells) do
        local name = info.NAME
        if name then
            local known = (info.TYPE == "SPELL") and IsSpellKnown(info.ID)
            local usableType = (info.TYPE == "ITEM" or info.TYPE == "MACRO")
            if known or usableType then
                local bestBar = pickBestBar(bars[name])
                local realSlot = bestBar and bestBar.slot or 0
                local realID = (bestBar and not bestBar.isMacro) and bestBar.id or info.ID
                local realRank = (bestBar and not bestBar.isMacro) and bestBar.rank or (info.RANK or 1)

                NS.Book[name] = {
                    type = info.TYPE,
                    name = name,
                    id = realID,
                    slot = realSlot,
                    rank = realRank,
                    icon = info.ICON,
                    range = info.RANGE,
                }

                if info.TYPE == "SPELL" then
                    criteriaGroups[name] = criteriaGroups[name] or {}
                    table.insert(criteriaGroups[name], {
                        id = realID,
                        slot = realSlot,
                        rank = realRank,
                        icon = info.ICON,
                        range = info.RANGE,
                        dps = info.DPS or 0,
                        hps = info.HPS or 0,
                        dpm = info.DPM or 0,
                        hpm = info.HPM or 0,
                    })
                end
            end
        end
    end

    for name, variants in pairs(criteriaGroups) do
        local best = { dps = nil, hps = nil, dpm = nil, hpm = nil }
        for _, v in ipairs(variants) do
            if not best.dps or v.dps > best.dps.dps then best.dps = v end
            if not best.hps or v.hps > best.hps.hps then best.hps = v end
            if not best.dpm or v.dpm > best.dpm.dpm then best.dpm = v end
            if not best.hpm or v.hpm > best.hpm.hpm then best.hpm = v end
        end
        local function save(tag, entry)
            if entry then
                NS.Book[name .. "_" .. tag] = {
                    type = "SPELL",
                    name = name,
                    id = entry.id,
                    slot = entry.slot,
                    rank = entry.rank,
                    icon = entry.icon,
                    range = entry.range,
                }
            end
        end
        save("DPS", best.dps)
        save("HPS", best.hps)
        save("DPM", best.dpm)
        save("HPM", best.hpm)
    end

    if NS.UI and NS.UI.RefreshList then NS.UI:RefreshList() end
    if NS.UI and NS.UI.RefreshPicker and NS.UI.pickerScroll then NS.UI:RefreshPicker(true) end
    Data.isBuilding = false
end

function Data:SyncWithJamboSpells()
    Data:BuildBook()
end

local evt = CreateFrame("Frame")
evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
evt:RegisterEvent("SPELLS_CHANGED")
evt:RegisterEvent("LEARNED_SPELL_IN_TAB")
evt:RegisterEvent("UPDATE_MACROS")
evt:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() Data:BuildBook() end)
end)

local retries = 0
C_Timer.NewTicker(1.0, function()
    if (not NS.Book or not next(NS.Book)) and retries < 5 then
        Data:BuildBook()
        retries = retries + 1
    end
end)