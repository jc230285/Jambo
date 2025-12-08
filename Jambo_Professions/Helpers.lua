local addonName, ns = ...

-- UI: ElvUI Style Border
function ns.SetElvUIBorder(f)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", 
        edgeFile = "Interface\\Buttons\\WHITE8x8", 
        edgeSize = 1, 
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Math: Format Item Count
function ns.GetItemCountFormatted(itemID)
    if not itemID then return "" end
    local count = C_Item.GetItemCount(itemID, true) 
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not icon then 
        return string.format(" |cffaaaaaa(Have: %d)|r", count)
    else
        return string.format("  |T%s:12:12:0:0|t |cffffffff%d|r", icon, count)
    end
end

-- Math: Bag vs Bank Count
function ns.GetDetailedItemCount(itemID)
    if not itemID then return 0, 0, "" end
    local bagCount = C_Item.GetItemCount(itemID, false)
    local totalCount = C_Item.GetItemCount(itemID, true)
    local bankCount = totalCount - bagCount
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    local iconStr = icon and ("|T"..icon..":12:12:0:0|t ") or ""
    
    local countStr = ""
    if bankCount > 0 then
        countStr = string.format("%s%d |cffaaaaaa(+%d Bank)|r", iconStr, bagCount, bankCount)
    else
        countStr = string.format("%s%d", iconStr, bagCount)
    end
    return bagCount, totalCount, countStr
end

-- Math: Distance to coordinate
function ns.GetDistance(mapID, x, y)
    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap or playerMap ~= mapID then return 99999 end
    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then return 99999 end
    local dx = (pos.x - x)
    local dy = (pos.y - y)
    return math.sqrt(dx*dx + dy*dy)
end