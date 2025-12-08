local ADDON, NS = ...

NS.Utils = NS.Utils or {}
local Utils = NS.Utils

local powermap = {
    HEALTH = -1,
    MANA   = 0,
    RAGE   = 1,
    FOCUS  = 2,
    ENERGY = 3,
    COMBO  = 4,
}

function Utils.Compare(a, op, b)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    if op == "<" then return a < b end
    if op == "<=" then return a <= b end
    if op == ">" then return a > b end
    if op == ">=" then return a >= b end
    if op == "=" or op == "==" then return math.abs(a - b) < 0.01 end
    if op == "!=" then return math.abs(a - b) > 0.01 end
    return false
end

function Utils.GetPowerTypeID(kind)
    return powermap[kind or ""] or 0
end

function Utils.SafeNumber(val, default)
    return tonumber(val) or default or 0
end

function Utils.FormatVal(val)
    if type(val) == "boolean" then return val and "T" or "F" end
    if type(val) == "number" then
        if val % 1 == 0 then return tostring(val) end
        return string.format("%.1f", val)
    end
    return tostring(val or "")
end

function Utils.DeepCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = Utils.DeepCopy(v) end
    return out
end

function Utils.ShallowCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = v end
    return out
end