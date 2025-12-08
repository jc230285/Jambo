local addonName, ns = ...

-- ============================================================================
--  STATIC UI HELPERS
-- ============================================================================
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

function ns.GetItemCountFormatted(itemID)
    if not itemID then return "" end
    local count = C_Item.GetItemCount(itemID, true) 
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not icon then 
        return string.format(" |cffaaaaaa(Have: %d)|r", count)
    else
        return string.format("  |T%s:12:12:0:0|t |cffffffff%d|r in bags", icon, count)
    end
end

-- ============================================================================
--  DATA DATABASE
--  tools: Table of ItemIDs required (e.g., {5956} for Blacksmith Hammer)
--  station: String name of station required (e.g., "Anvil", "Fire")
-- ============================================================================

-- NEW: Maps Reagent ID -> Container ID (What holds it?)
ns.ContainerMap = {
    [5503] = 5523, -- Clam Meat is inside Small Barnacled Clam
    [5504] = 5524, -- Tangy Clam Meat is inside Thick-shelled Clam
    [7974] = 7973, -- Zesty Clam Meat is inside Big-mouth Clam
}

ns.vendorItems = {
    [3371]=true, [3372]=true, [8925]=true, [2320]=true, [2321]=true, [4291]=true, 
    [8343]=true, [2605]=true, [2604]=true, [6260]=true, [4340]=true, [2880]=true, 
    [3466]=true, [3857]=true, [4470]=true, [4471]=true, [2901]=true, [5956]=true,
    [6219]=true, [7005]=true, [6256]=true, [5060]=true
}

ns.guideData = {
    ["Mining"] = {
        {min=1, max=65, type="GATHER", text="Farm Copper Ore", item=2770, tools={2901}},
        {min=65, max=75, type="RECIPE", text="Smelt Copper", recipeName="Smelt Copper", item=2840, reagents={[2770]=1}, station="Forge"},
        {min=75, max=125, type="GATHER", text="Farm Tin & Silver", item=2771, tools={2901}},
        {min=125, max=155, type="RECIPE", text="Smelt Bronze", recipeName="Smelt Bronze", item=2841, reagents={[2770]=1, [2771]=1}, station="Forge"},
        {min=155, max=175, type="GATHER", text="Farm Iron & Gold", item=2772, tools={2901}},
        {min=175, max=230, type="GATHER", text="Farm Mithril", item=3858, tools={2901}},
        {min=230, max=300, type="GATHER", text="Farm Thorium", item=10620, tools={2901}},
    },
    ["Blacksmithing"] = {
        {min=1, max=30, type="RECIPE", text="Rough Sharpening Stone", recipeName="Rough Sharpening Stone", item=2862, reagents={[2835]=1}, tools={5956}},
        {min=30, max=65, type="RECIPE", text="Rough Grinding Stone", recipeName="Rough Grinding Stone", item=3470, reagents={[2835]=2}, tools={5956}},
        {min=65, max=75, type="RECIPE", text="Coarse Sharpening Stone", recipeName="Coarse Sharpening Stone", item=2863, reagents={[2836]=1}, tools={5956}},
        {min=75, max=100, type="RECIPE", text="Coarse Grinding Stone", recipeName="Coarse Grinding Stone", item=3478, reagents={[2836]=2}, tools={5956}},
        {min=100, max=125, type="RECIPE", text="Runed Copper Belt", recipeName="Runed Copper Belt", item=2854, reagents={[2840]=10}, tools={5956}, station="Anvil"},
        {min=125, max=150, type="RECIPE", text="Heavy Grinding Stone", recipeName="Heavy Grinding Stone", item=3486, reagents={[2838]=3}, tools={5956}},
        {min=150, max=165, type="RECIPE", text="Gold Rod", recipeName="Golden Rod", item=11128, reagents={[3577]=1, [3478]=2}, tools={5956}, station="Anvil"},
        {min=165, max=190, type="RECIPE", text="Green Iron Bracers", recipeName="Green Iron Bracers", item=3840, reagents={[3575]=6, [2605]=1}, tools={5956}, station="Anvil"},
        {min=190, max=200, type="RECIPE", text="Golden Scale Bracers", recipeName="Golden Scale Bracers", item=6040, reagents={[3859]=5, [3577]=2}, tools={5956}, station="Anvil"},
        {min=200, max=210, type="RECIPE", text="Solid Grinding Stone", recipeName="Solid Grinding Stone", item=7966, reagents={[7912]=4}, tools={5956}},
        {min=210, max=225, type="RECIPE", text="Heavy Mithril Gauntlet", recipeName="Heavy Mithril Gauntlet", item=7928, reagents={[3860]=6, [4338]=2}, tools={5956}, station="Anvil"},
        {min=225, max=235, type="RECIPE", text="Mithril Scale Bracers", recipeName="Mithril Scale Bracers", item=7921, reagents={[3860]=8}, tools={5956}, station="Anvil"},
        {min=235, max=250, type="RECIPE", text="Mithril Coif", recipeName="Mithril Coif", item=7931, reagents={[3860]=10, [4338]=6}, tools={5956}, station="Anvil"},
        {min=250, max=260, type="RECIPE", text="Dense Sharpening Stone", recipeName="Dense Sharpening Stone", item=12643, reagents={[12365]=1}, tools={5956}},
        {min=260, max=270, type="RECIPE", text="Thorium Belt", recipeName="Thorium Belt", item=12405, reagents={[12359]=12, [7910]=4}, tools={5956}, station="Anvil"},
        {min=270, max=295, type="RECIPE", text="Imperial Plate Bracers", recipeName="Imperial Plate Bracers", item=12422, reagents={[12359]=12, [7910]=1}, tools={5956}, station="Anvil"},
        {min=295, max=300, type="RECIPE", text="Imperial Plate Boots", recipeName="Imperial Plate Boots", item=12424, reagents={[12359]=18, [7909]=1}, tools={5956}, station="Anvil"},
    },
    ["Cooking"] = {
        {min=1, max=50, type="RECIPE", text="Roasted Boar Meat", recipeName="Roasted Boar Meat", item=2679, reagents={[769]=1}, station="Fire", tools={4471}},
        {min=50, max=90, type="RECIPE", text="Smoked Bear Meat", recipeName="Smoked Bear Meat", item=37253, reagents={[3173]=1}, station="Fire", tools={4471}},
        {min=90, max=130, type="RECIPE", text="Boiled Clams", recipeName="Boiled Clams", item=5525, reagents={[5503]=1, [159]=1}, station="Fire", tools={4471}},
        {min=130, max=175, type="RECIPE", text="Curiously Tasty Omelet", recipeName="Curiously Tasty Omelet", item=3662, reagents={[3685]=1, [2692]=1}, station="Fire", tools={4471}},
        {min=175, max=225, type="RECIPE", text="Roast Raptor", recipeName="Roast Raptor", item=12209, reagents={[12184]=1, [2692]=1}, station="Fire", tools={4471}},
        {min=225, max=275, type="RECIPE", text="Monster Omelet", recipeName="Monster Omelet", item=12218, reagents={[12207]=1, [3713]=2}, station="Fire", tools={4471}},
        {min=275, max=300, type="RECIPE", text="Poached Sunscale Salmon", recipeName="Poached Sunscale Salmon", item=13927, reagents={[13760]=1}, station="Fire", tools={4471}},
    },
    ["Engineering"] = {
        {min=1, max=30, type="RECIPE", text="Rough Blasting Powder", recipeName="Rough Blasting Powder", item=4357, reagents={[2835]=1}, tools={5956}},
        {min=30, max=50, type="RECIPE", text="Handful of Copper Bolts", recipeName="Handful of Copper Bolts", item=4359, reagents={[2840]=1}, tools={5956}, station="Anvil"},
        {min=50, max=75, type="RECIPE", text="Rough Copper Bomb", recipeName="Rough Copper Bomb", item=4360, reagents={[4359]=1, [2840]=1, [4357]=2, [2589]=1}, tools={5956}, station="Anvil"},
        {min=75, max=90, type="RECIPE", text="Coarse Blasting Powder", recipeName="Coarse Blasting Powder", item=4364, reagents={[2836]=1}, tools={5956}},
        {min=90, max=100, type="RECIPE", text="Coarse Dynamite", recipeName="Coarse Dynamite", item=4365, reagents={[4364]=3, [2589]=1}, tools={5956}},
        {min=100, max=125, type="RECIPE", text="Flying Tiger Goggles", recipeName="Flying Tiger Goggles", item=4373, reagents={[2841]=6, [4361]=2}, tools={5956}},
        {min=125, max=150, type="RECIPE", text="Heavy Blasting Powder", recipeName="Heavy Blasting Powder", item=4377, reagents={[2838]=1}, tools={5956}},
        {min=150, max=175, type="RECIPE", text="Bronze Framework", recipeName="Bronze Framework", item=4382, reagents={[2841]=2, [2592]=1, [2319]=1}, tools={5956}, station="Anvil"},
        {min=175, max=195, type="RECIPE", text="Solid Blasting Powder", recipeName="Solid Blasting Powder", item=10505, reagents={[7912]=2}, tools={5956}},
        {min=195, max=215, type="RECIPE", text="Mithril Tube", recipeName="Mithril Tube", item=10559, reagents={[3860]=3}, tools={5956}, station="Anvil"},
        {min=215, max=235, type="RECIPE", text="Mithril Casing", recipeName="Mithril Casing", item=10561, reagents={[3860]=3}, tools={5956}, station="Anvil"},
        {min=235, max=250, type="RECIPE", text="Hi-Explosive Bomb", recipeName="Hi-Explosive Bomb", item=10562, reagents={[10561]=2, [10505]=2, [10560]=1}, tools={5956}, station="Anvil"},
        {min=250, max=260, type="RECIPE", text="Dense Blasting Powder", recipeName="Dense Blasting Powder", item=10509, reagents={[12365]=2}, tools={5956}},
        {min=260, max=285, type="RECIPE", text="Thorium Widget", recipeName="Thorium Widget", item=10576, reagents={[12359]=3, [14047]=1}, tools={5956}, station="Anvil"},
        {min=285, max=300, type="RECIPE", text="Thorium Tube", recipeName="Thorium Tube", item=10577, reagents={[12359]=6}, tools={5956}, station="Anvil"},
    },
    ["First Aid"] = {
        {min=1, max=40, type="RECIPE", text="Linen Bandage", recipeName="Linen Bandage", item=1251, reagents={[2589]=1}},
        {min=40, max=80, type="RECIPE", text="Heavy Linen Bandage", recipeName="Heavy Linen Bandage", item=2581, reagents={[2589]=2}},
        {min=80, max=115, type="RECIPE", text="Wool Bandage", recipeName="Wool Bandage", item=3530, reagents={[2592]=1}},
        {min=115, max=150, type="RECIPE", text="Heavy Wool Bandage", recipeName="Heavy Wool Bandage", item=3531, reagents={[2592]=2}},
        {min=150, max=180, type="RECIPE", text="Silk Bandage", recipeName="Silk Bandage", item=6450, reagents={[4306]=1}},
        {min=180, max=210, type="RECIPE", text="Heavy Silk Bandage", recipeName="Heavy Silk Bandage", item=6451, reagents={[4306]=2}},
        {min=210, max=240, type="RECIPE", text="Mageweave Bandage", recipeName="Mageweave Bandage", item=8544, reagents={[4338]=1}},
        {min=240, max=260, type="RECIPE", text="Heavy Mageweave Bandage", recipeName="Heavy Mageweave Bandage", item=8545, reagents={[4338]=2}},
        {min=260, max=290, type="RECIPE", text="Runecloth Bandage", recipeName="Runecloth Bandage", item=14529, reagents={[14047]=1}},
        {min=290, max=300, type="RECIPE", text="Heavy Runecloth Bandage", recipeName="Heavy Runecloth Bandage", item=14530, reagents={[14047]=2}},
    },
    ["Fishing"] = {
        {min=1, max=75, type="GATHER", text="Fish in Starter Zones", tools={6256}},
        {min=75, max=150, type="GATHER", text="Fish in Barrens/Westfall", tools={6256}},
        {min=150, max=225, type="GATHER", text="Fish in Wetlands/Ashenvale", tools={6256}},
        {min=225, max=300, type="GATHER", text="Fish in Feralas/Tanaris", tools={6256}},
    },
    ["Alchemy"] = {
        {min=1, max=60, type="RECIPE", text="Minor Healing Potion", recipeName="Minor Healing Potion", item=118, reagents={[765]=1, [2447]=1, [3371]=1}},
        {min=60, max=110, type="RECIPE", text="Lesser Healing Potion", recipeName="Lesser Healing Potion", item=858, reagents={[118]=1, [2450]=1}},
        {min=110, max=140, type="RECIPE", text="Healing Potion", recipeName="Healing Potion", item=929, reagents={[2453]=1, [2450]=1, [3372]=1}},
        {min=140, max=155, type="RECIPE", text="Lesser Mana Potion", recipeName="Lesser Mana Potion", item=3385, reagents={[785]=1, [3820]=1, [3371]=1}},
        {min=155, max=185, type="RECIPE", text="Greater Healing Potion", recipeName="Greater Healing Potion", item=1710, reagents={[3357]=1, [3356]=1, [3372]=1}},
        {min=185, max=210, type="RECIPE", text="Elixir of Agility", recipeName="Elixir of Agility", item=8949, reagents={[3820]=1, [3821]=1, [3372]=1}},
        {min=210, max=250, type="RECIPE", text="Elixir of Greater Defense", recipeName="Elixir of Greater Defense", item=3826, reagents={[3355]=1, [3821]=1, [3372]=1}},
        {min=250, max=285, type="RECIPE", text="Elixir of Detect Undead", recipeName="Elixir of Detect Undead", item=9154, reagents={[8836]=1, [8925]=1}},
        {min=285, max=300, type="RECIPE", text="Major Healing Potion", recipeName="Major Healing Potion", item=13446, reagents={[13464]=2, [13465]=1, [8925]=1}},
    },
    ["Skinning"] = {
        {min=1, max=75, type="GATHER", text="Skin Boars/Wolves", item=2318, tools={7005}},
        {min=75, max=150, type="GATHER", text="Skin Barrens/Westfall", item=2319, tools={7005}},
        {min=150, max=205, type="GATHER", text="Skin Stranglethorn", item=4234, tools={7005}},
        {min=205, max=265, type="GATHER", text="Skin Tanaris/Feralas", item=4304, tools={7005}},
        {min=265, max=300, type="GATHER", text="Skin Un'Goro/Winterspring", item=8170, tools={7005}},
    },
    ["Leatherworking"] = {
        {min=1, max=45, type="RECIPE", text="Light Armor Kit", recipeName="Light Armor Kit", item=2304, reagents={[2318]=1}},
        {min=45, max=55, type="RECIPE", text="Handstitched Leather Cloak", recipeName="Handstitched Leather Cloak", item=2302, reagents={[2318]=2, [2320]=1}},
        {min=55, max=100, type="RECIPE", text="Embossed Leather Gloves", recipeName="Embossed Leather Gloves", item=4239, reagents={[2318]=3, [2320]=2}},
        {min=100, max=120, type="RECIPE", text="Fine Leather Belt", recipeName="Fine Leather Belt", item=4249, reagents={[2318]=6, [2320]=2}},
        {min=120, max=135, type="RECIPE", text="Dark Leather Boots", recipeName="Dark Leather Boots", item=2310, reagents={[2319]=4, [2321]=2, [4340]=1}},
        {min=135, max=150, type="RECIPE", text="Dark Leather Pants", recipeName="Dark Leather Pants", item=7359, reagents={[2319]=12, [2321]=1, [4340]=1}},
    }
}

-- Tuesday, December 2, 2025 at 12:51:32 PM GMT
-- Helpers.lua