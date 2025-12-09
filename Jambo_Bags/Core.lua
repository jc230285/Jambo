local addonName, addon = ...
JamboBags = addon

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        JamboBags:InitDB()
    elseif event == "PLAYER_LOGIN" then
        JamboBags:Initialize()
    end
end)

function JamboBags:InitDB()
    -- Initialize SavedVariables
    JamboBagsDB = JamboBagsDB or {}
    JamboBagsDB.profiles = JamboBagsDB.profiles or {}
    JamboBagsDB.customWeights = JamboBagsDB.customWeights or {}
    
    -- FIX: Determine class immediately, as InitDB runs before Initialize
    if not addon.MyClass then
        addon.MyClass = select(2, UnitClass("player"))
    end
    
    -- Load default weights if no custom ones exist
    -- Added safety check for addon.MyClass to prevent 'table index is nil'
    if addon.MyClass and not JamboBagsDB.customWeights[addon.MyClass] then
        JamboBagsDB.customWeights[addon.MyClass] = CopyTable(addon.DefaultSpecs[addon.MyClass] or {})
    end
end

function JamboBags:Initialize()
    -- Ensure class is set (fallback)
    if not addon.MyClass then
        addon.MyClass = select(2, UnitClass("player"))
    end
    
    -- Initialize the main visual frame
    if JamboBags.CreateBagFrame then
        JamboBags:CreateBagFrame()
    end

    -- Register Slash Command /jambobags
    SLASH_JAMBOBAGS_TOGGLE1 = "/jambobags"
    SlashCmdList["JAMBOBAGS_TOGGLE"] = function(msg)
        JamboBags:Toggle()
    end

    -- Hook into standard bag toggles
    hooksecurefunc("ToggleAllBags", function() JamboBags:Toggle() end)
    hooksecurefunc("OpenAllBags", function() JamboBags:Open() end)
    hooksecurefunc("CloseAllBags", function() JamboBags:Close() end)

    print("|cFF00FF00Jambo_Bags|r loaded. Auto-BiS active. Press B or /jambobags to open.")
end

-- Main Open/Close/Toggle Logic
function JamboBags:Open()
    if JamboBags.Frame then 
        JamboBags.Frame:Show()
        JamboBags:RefreshBagView()
        
        -- Close default Blizzard bags if they try to open
        if ContainerFrame1 and ContainerFrame1:IsShown() then
            CloseAllBags() 
            -- Re-open ours because CloseAllBags closes ours too due to the hook
            JamboBags.Frame:Show()
        end
    end
end

function JamboBags:Close()
    if JamboBags.Frame then JamboBags.Frame:Hide() end
end

function JamboBags:Toggle()
    if JamboBags.Frame and JamboBags.Frame:IsShown() then
        JamboBags:Close()
    else
        JamboBags:Open()
    end
end

function JamboBags:IsReady()
    return JamboBagsDB and addon.DefaultSpecs
end