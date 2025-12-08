local ADDON, NS = ...

NS.Constants = {}
local C = NS.Constants

-- Media & Visuals
C.MEDIA = {
    bar = "Interface\\Buttons\\WHITE8x8",
    font = "Fonts\\FRIZQT__.TTF",
    bg = {0, 0, 0, 0}, -- Transparent background
    border = {0, 0, 0, 1},
    headerColor = {0.2, 0.6, 1, 1},
    groupColor = {0.4, 0.4, 0.4, 1}
}

-- Dimensions (Half Width)
C.ROW_HEIGHT = 28
C.MAX_ROWS = 16
C.FRAME_WIDTH = 300 
C.SCROLLBAR_WIDTH = 30

-- Sort Modes
C.SORT_HP_ASC = 1
C.SORT_HP_DESC = 2
C.SORT_THREAT_ASC = 3
C.SORT_THREAT_DESC = 4

-- Database Defaults
C.DEFAULTS = {
    options = {
        targetDeficitPercent = 20,
        targetDeficitHP = 0,
        targetHealSpellId = nil, -- Default to None
        targetHarmSpellId = nil,
        targetFrameOffset = { x = -700, y = 125 },
        showConfig = false, 
        showAllGroups = false, -- Default Off
        debugMapID = false,
        enemySortMode = C.SORT_HP_ASC, 
    },
    data = {},
}

C.DB_NAME = "JamboTargetDB"