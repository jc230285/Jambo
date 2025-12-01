# Jambo Target V3

A modular, priority-based unit frame addon for World of Warcraft.

## API Integration
Other addons can get the mapped UnitID based on the sort order index using the global `JamboTarget` table.

A modular, priority-based unit frame addon for World of Warcraft (Classic/Era/Retail).

## Features
- **Smart Grouping**: Automatically sorts units into Priority Heals (based on HP Deficit), Harm (Enemies in range), Friendly, and Dead.
- **Configurable Thresholds**: Use sliders to set HP Deficit % or Raw HP numbers to determine who enters the "Priority" group.
- **Spell Integration**: Select a Heal spell and Harm spell to filter units by range (e.g., only show Priority Heals if they are in range of "Flash Heal").
- **Clean UI**: Flat textures, pixel-perfect borders, and simple status bars.

## Installation
1. Extract the `Jambo_Target` folder to your `Interface/AddOns/` directory.
2. In-game, type `/jambo` to toggle the window.

Index,UnitID
0,target
1,player
2-6,party1 - party5
10,mouseover
11,focus
12,pet
21-60,raid1 - raid40
71-75,arena1 - arena5
81-85,boss1 - boss5
200+,nameplates

Features
Smart Groups:

Enemies: Sorted by Lowest Raw HP.

Friendlies: Sorted by Highest Deficit.

Display: Shows persistent Order Index [x] on unit names.

Config: Sliders for HP thresholds and Spell Range filters.