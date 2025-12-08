local addonName, ns = ...

-- Vendor Items (Tools, Flux, Dye, Thread, Vials)
ns.vendorItems = {
    [3371]=true, [3372]=true, [8925]=true, [2320]=true, [2321]=true, [4291]=true, 
    [8343]=true, [2605]=true, [2604]=true, [6260]=true, [4340]=true, [2880]=true, 
    [3466]=true, [3857]=true, [4470]=true, [4471]=true, [2901]=true, [5956]=true,
    [6219]=true, [7005]=true, [6256]=true, [5060]=true, [20815]=true, [20824]=true
}

-- Openables Map: Item Needed -> Container ID
ns.ContainerMap = {
    [5503] = 5523, -- Clam Meat -> Small Barnacled Clam
    [5504] = 5524, -- Tangy Clam Meat -> Thick-shelled Clam
    [7974] = 7973, -- Zesty Clam Meat -> Big-mouth Clam
    [4604] = 4608, -- Raw Black Truffle -> Small Pumpkin (Example)
}

-- Simple Name Cache
ns.Items = {
    [2447]="Peacebloom", [765]="Silverleaf", [2450]="Briarthorn", [2835]="Rough Stone", 
    [2840]="Copper Bar", [2589]="Linen Cloth", [2592]="Wool Cloth", [2318]="Light Leather"
}