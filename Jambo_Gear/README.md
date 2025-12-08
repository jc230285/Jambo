# Jambo Gear

A World of Warcraft Classic Era addon for managing gear sets across multiple classes and specs.

## Features

- **Multi-Class Gear Management**: Create and manage gear sets for different classes and specs
- **Spec-Specific Scoring**: Automatic scoring of gear based on spec weights for optimal gear selection
- **Bag Overlays**: Visual indicators on bag items showing the best spec (DPS/Tank/Healer icons)
- **Tooltip Enhancements**: Shows spec scores and BIS (Best in Slot) information in item tooltips
- **Auto-Equip on Role Change**: Automatically equip appropriate sets when your role changes
- **Baganator Support**: Compatible with Baganator addon for enhanced bag management
- **Customizable Weights**: Adjust stat weights for each spec to fine-tune scoring
- **Ring Selection**: Supports best/second-best ring selection for optimal setups

## Installation

1. Download the addon files
2. Extract to `World of Warcraft\_classic_era_\Interface\AddOns\Jambo_Gear\`
3. Restart World of Warcraft or reload UI with `/reload`
4. Use `/jambo` or `/jg` to open the configuration interface

## Usage

### Basic Setup
1. Open the addon interface with `/jambo`
2. Go to the "Spec Config" tab to set up spec priorities and weights
3. Create gear sets in the "Gear Sets" tab
4. Equip sets manually or enable auto-equip features

### Bag Overlays
- Icons on bag items indicate the best spec for that item
- DPS: Red sword icon
- Tank: Blue shield icon
- Healer: Green cross icon

### Tooltips
- Shows scores for each spec
- Displays BIS information for items that are optimal for specific specs

### Auto-Equip
- Enable "Equip on Role Change" in Options to automatically switch sets when your role changes
- Enable "Auto-swap gear when leaving combat" for automatic gear swaps after combat

## Compatibility

- Compatible with Baganator addon
- Works with default WoW bag frames
- Supports all WoW Classic Era classes and specs

## Commands

- `/jambo` or `/jg` - Open configuration interface
- `/jambo equip <setname>` - Equip a specific set
- `/jambo scan` - Rescan gear and update overlays

## Troubleshooting

- If overlays don't appear, check that "Show best-spec overlays in bags" is enabled in Options
- For Baganator compatibility, ensure Baganator is loaded before Jambo Gear
- Reload UI with `/reload` if issues persist

## Credits

Created with assistance from GitHub Copilot



Add an event-based guard to re-hook when ADDON_LOADED detects the shopping tooltip frames created by other addons.
Add a small unit-check or fallback to find the shopping tooltips if they're named differently by other addons.