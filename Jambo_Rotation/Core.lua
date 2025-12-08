local ADDON, NS = ...

local function defaultProfile()
    return {
        steps = {
            {
                name = "Auto Attack",
                criteria = "RANK",
                conditions = {
                    { type = "RESOURCE", unit = "target", resType = "HEALTH", op = ">", val = 0 },
                },
            },
        },
        iconPos = nil,
    }
end

local function initDB()
    JamboRotDB = JamboRotDB or {}
    local key = UnitName("player") .. " - " .. GetRealmName()
    if not JamboRotDB[key] then JamboRotDB[key] = defaultProfile() end
    NS.db = JamboRotDB[key]
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON then return end
    initDB()
    if NS.Data and NS.Data.SyncWithJamboSpells then NS.Data:SyncWithJamboSpells() end
    if NS.UI and NS.UI.Init then NS.UI:Init() end
end)

SLASH_JAMBOROT1 = "/jr"
SlashCmdList["JAMBOROT"] = function()
    if not NS.UI or not NS.UI.frame then return end
    if NS.UI.frame:IsShown() then NS.UI.frame:Hide() else NS.UI.frame:Show() end
end

local runner = CreateFrame("Frame")
local tick = 0
runner:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + elapsed
    if tick < 0.1 then return end
    tick = 0
    if not NS.db or not NS.db.steps then return end

    local winner
    for _, step in ipairs(NS.db.steps) do
        if not step.disabled then
            local pass = NS.Engine:EvaluateStep(step)
            if pass then winner = step; break end
        end
    end

    if _G.JamboSpells and _G.JamboSpells.SetActionSlot then
        if winner then
            local data = NS.Engine:ResolveSpell(winner)
            _G.JamboSpells:SetActionSlot(data and data.slot or 0)
        else
            _G.JamboSpells:SetActionSlot(0)
        end
    end

    if NS.UI and NS.UI.UpdateIcon then
        local tex = nil
        if winner then
            local data = NS.Engine:ResolveSpell(winner)
            tex = data and data.icon
        end
        NS.UI:UpdateIcon(tex)
    end
end)