local ADDON, NS = ...

NS.Constants = {}
local C = NS.Constants

-- Media & Visuals
C.MEDIA = {
    bar = "Interface\\Buttons\\WHITE8x8",
    font = "Fonts\\FRIZQT__.TTF",
    bg = {0.1, 0.1, 0.1, 0.95},
    border = {0, 0, 0, 1},
    headerColor = {0.2, 0.6, 1, 1},
    groupColor = {0.4, 0.4, 0.4, 1}
}

-- Dimensions (Half Width)
C.ROW_HEIGHT = 28
C.MAX_ROWS = 16
C.FRAME_WIDTH = 300 -- Narrower
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
        targetHealSpellId = nil,
        targetHarmSpellId = nil,
        targetFrameOffset = { x = 0, y = 0 },
        showConfig = true, -- Toggle state
        enemySortMode = C.SORT_HP_ASC, -- Default sort
    },
    data = {},
}

C.DB_NAME = "JamboTargetDB"