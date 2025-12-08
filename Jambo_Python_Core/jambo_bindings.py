from pathlib import Path

# Slot 1-120 mappings
ACTION_SLOT_OFFSETS = {
    "ACTIONBUTTON": 0, "MULTIACTIONBAR3BUTTON": 24, "MULTIACTIONBAR4BUTTON": 36,
    "MULTIACTIONBAR2BUTTON": 48, "MULTIACTIONBAR1BUTTON": 60,
}

# Default Keybinds (WoW Standard)
DEFAULT_BINDINGS = {
    # Targeting
    "TARGETSELF": "F1",
    "TARGETPARTYMEMBER1": "F2", "TARGETPARTYMEMBER2": "F3",
    "TARGETPARTYMEMBER3": "F4", "TARGETPARTYMEMBER4": "F5",
    "TARGETNEARESTENEMY": "TAB",
    
    # Movement
    "MOVEFORWARD": "W",
    "MOVEBACKWARD": "S",
    "TURNLEFT": "A",
    "TURNRIGHT": "D",
    "STRAFELEFT": "Q",
    "STRAFERIGHT": "E",
    "JUMP": "SPACE",
    
    # Interaction (No defaults usually, but good to track)
    "INTERACTTARGET": None,
    "INTERACTMOUSEOVER": None,
    "FOLLOWTARGET": None
}

def get_accounts(root_dir):
    path = Path(root_dir) / "WTF" / "Account"
    if not path.exists(): return []
    return [d.name for d in path.iterdir() if d.is_dir() and d.name != "SavedVariables"]

def get_characters(root_dir, account):
    path = Path(root_dir) / "WTF" / "Account" / account
    chars = []
    if path.exists():
        for realm in path.iterdir():
            if realm.is_dir() and realm.name != "SavedVariables":
                for char in realm.iterdir():
                    if char.is_dir():
                        chars.append(f"{realm.name}/{char.name}")
    return chars

def _action_to_slot(action):
    action = action.upper()
    for prefix, offset in ACTION_SLOT_OFFSETS.items():
        if action.startswith(prefix):
            try: return offset + int(action.replace(prefix, ""))
            except: continue
    return None

def load_bindings(root_dir, account, character=""):
    files = []
    base = Path(root_dir) / "WTF" / "Account" / account
    
    # Priority: Character > Account
    if character and "/" in character:
        realm, char_name = character.split("/")
        files.append(base / realm / char_name / "bindings-cache.wtf")
        
    files.append(base / "bindings-cache.wtf")
    
    slot_map = {}   # SlotID (int) -> Key (str)
    
    # Initialize Action Map with Defaults
    # We filter out None values (actions with no default)
    action_map = {k: v for k, v in DEFAULT_BINDINGS.items() if v is not None}
    
    # Process account first, then character to overwrite
    for f in reversed(files):
        if f.exists():
            try:
                for line in f.read_text(encoding="utf-8", errors="ignore").splitlines():
                    parts = line.strip().split(None, 2)
                    if len(parts) >= 3 and parts[0].upper() == "BIND":
                        key = parts[1].upper()
                        action = parts[2].strip('"').upper()
                        
                        if action == "NONE":
                            # User explicitly unbound this key.
                            # If this key was assigned to an action in our map (e.g. W -> MOVEFORWARD), remove it.
                            # We have to search values because action_map is Action->Key
                            actions_to_clear = [k for k, v in action_map.items() if v == key]
                            for k in actions_to_clear:
                                del action_map[k]
                        else:
                            # Update Action Map
                            action_map[action] = key
                            
                            # Update Slot Map (if applicable)
                            slot = _action_to_slot(action)
                            if slot: 
                                slot_map[slot] = key
            except: pass
            
    return slot_map, action_map