-- Jambo_Spells_Export.lua
local addonName, J = ...

local function serialize(o)
    if type(o) == "number" then return o
    elseif type(o) == "string" then return string.format("%q", o)
    elseif type(o) == "boolean" then return tostring(o)
    elseif type(o) == "table" then
        local s = "{"
        local i = 1
        for k, v in pairs(o) do
            if i > 1 then s = s .. "," end
            s = s .. string.format("%q:%s", k, serialize(v))
            i = i + 1
        end
        return s .. "}"
    else return "null" end
end

function J:GetExportJSON()
    return serialize(self.data.spells)
end